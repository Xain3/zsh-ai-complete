#!/usr/bin/env python3
"""Run synthetic prompts through the actual completion request helper."""
import argparse
import concurrent.futures
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import statistics
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
DATASET = ROOT / 'benchmarks' / 'prompts.json'


def utc_now():
    return dt.datetime.now(dt.timezone.utc).isoformat()


def load_cases():
    raw = DATASET.read_bytes()
    groups = json.loads(raw)
    cases = [{'id': f'{group["category"]}-{index:02d}', 'category': group['category'],
              'prompt': prompt}
             for group in groups for index, prompt in enumerate(group['prompts'], 1)]
    if len(cases) != 130 or len({case['id'] for case in cases}) != 130:
        raise ValueError('The benchmark dataset must contain exactly 130 unique cases.')
    return raw, cases


def choose_backend():
    switch = os.environ.get('ZSH_AI_BENCH_OPENAI', '0')
    if switch not in ('0', '1'):
        raise ValueError('ZSH_AI_BENCH_OPENAI must be 0 or 1.')
    if switch == '1':
        token = os.environ.get('OPENAI_API_KEY', '').strip()
        if not token:
            raise ValueError('OPENAI_API_KEY is required when ZSH_AI_BENCH_OPENAI=1.')
        return 'openai', 'gpt-6-luna', token
    return 'ollama', 'qwen2.5-coder:7b', ''


def run_case(case, config, selection):
    env = os.environ.copy()
    env.pop('OPENAI_API_KEY', None)
    env['FZF_QUERY'] = case['prompt']
    started = time.perf_counter()
    try:
        result = subprocess.run(['bash', str(ROOT / 'request.sh'), str(config), str(selection)],
            env=env, capture_output=True, text=True, timeout=40, check=False)
        elapsed = round((time.perf_counter() - started) * 1000, 1)
        suggestions = result.stdout.splitlines()
        status = 'ok' if result.returncode == 0 and suggestions else 'error'
        # Curl errors contain status information, not authorization headers.
        error = result.stderr.strip()[:500] if status == 'error' else ''
        if status == 'error' and not error:
            error = 'The request returned no suggestions.'
        return {**case, 'status': status, 'suggestions': suggestions,
                'suggestion_count': len(suggestions), 'duration_ms': elapsed, 'error': error}
    except (OSError, subprocess.TimeoutExpired) as exc:
        return {**case, 'status': 'error', 'suggestions': [], 'suggestion_count': 0,
                'duration_ms': round((time.perf_counter() - started) * 1000, 1),
                'error': type(exc).__name__}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path, help='New JSONL results file')
    parser.add_argument('--workers', type=int, default=4, choices=range(1, 9))
    parser.add_argument('--category', action='append', help='Only run the specified category; repeat to select several')
    args = parser.parse_args()
    dataset, cases = load_cases()
    if args.category:
        known = {case['category'] for case in cases}
        if set(args.category) - known:
            raise ValueError('Unknown benchmark category.')
        cases = [case for case in cases if case['category'] in args.category]
    backend, model, token = choose_backend()
    provider = json.loads((ROOT / 'example.ai-providers.json').read_text(encoding='utf-8'))[backend]
    provider.update(model=model, token=token)
    output = args.output.resolve()
    summary_path = Path(str(output) + '.summary.json')
    if not output.parent.is_dir():
        raise ValueError('The output directory must already exist.')

    # Exclusive, private files prevent accidental overwrite or broad readability.
    result_fd = os.open(output, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        summary_fd = os.open(summary_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    except BaseException:
        os.close(result_fd)
        output.unlink()
        raise

    records = []
    start = utc_now()
    with os.fdopen(result_fd, 'w', encoding='utf-8') as results, \
         os.fdopen(summary_fd, 'w', encoding='utf-8') as summary_file, \
         tempfile.TemporaryDirectory(prefix='zsh-ai-benchmark-') as temp:
        temp_dir = Path(temp)
        config = temp_dir / 'providers.json'
        selection = temp_dir / 'selected-provider.txt'
        config_fd = os.open(config, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(config_fd, 'w', encoding='utf-8') as config_file:
            json.dump({backend: provider}, config_file)
        selection.write_text(backend, encoding='utf-8')

        def save(record):
            records.append(record)
            results.write(json.dumps(record, ensure_ascii=False) + '\n')
            results.flush()
            if len(records) % 10 == 0 or record['status'] != 'ok':
                print(f"Completed {len(records)}/{len(cases)} ({sum(r['status'] == 'ok' for r in records)} successful)", flush=True)

        # Fail early if authentication, model access, or the local server fails.
        first = run_case(cases[0], config, selection)
        save(first)
        if first['status'] == 'ok':
            with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as executor:
                futures = [executor.submit(run_case, case, config, selection) for case in cases[1:]]
                for future in concurrent.futures.as_completed(futures):
                    save(future.result())

        successful = [item for item in records if item['status'] == 'ok']
        times = [item['duration_ms'] for item in successful]
        counts = {category: {'total': sum(x['category'] == category for x in records),
                            'successful': sum(x['category'] == category for x in successful),
                            'five_lines': sum(x['category'] == category and x['suggestion_count'] == 5 for x in successful)}
                  for category in sorted({case['category'] for case in cases})}
        summary = {'schema_version': 1, 'started_at_utc': start, 'finished_at_utc': utc_now(),
            'backend': backend, 'requested_model': model, 'request_path': 'request.sh',
            'workers': args.workers,
            'request_helper_sha256': hashlib.sha256((ROOT / 'request.sh').read_bytes()).hexdigest(),
            'benchmark_script_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
            'dataset_sha256': hashlib.sha256(dataset).hexdigest(),
            'system_message_sha256': hashlib.sha256(provider['system_message'].encode()).hexdigest(),
            'expected_prompts': len(cases), 'attempted_prompts': len(records),
            'successful_prompts': len(successful), 'failed_prompts': len(records) - len(successful),
            'five_line_responses': sum(x['suggestion_count'] == 5 for x in successful),
            'median_duration_ms': round(statistics.median(times), 1) if times else None,
            'categories': counts, 'semantic_correctness_evaluated': False,
            'suggestions_executed': False}
        json.dump(summary, summary_file, indent=2, ensure_ascii=False)
        summary_file.write('\n')
        summary_file.flush()
    print(f'Results saved to {output}\nSummary saved to {summary_path}')
    return 0 if len(records) == len(cases) and len(successful) == len(cases) else 1


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (ValueError, OSError, json.JSONDecodeError) as exc:
        print(f'Benchmark error: {exc}', file=sys.stderr)
        sys.exit(2)
