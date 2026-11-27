#!/usr/bin/env python3
"""Check saved suggestions for Zsh syntax without executing them."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess


def syntax_ok(command):
    result = subprocess.run(['zsh', '-f', '-n'], input=command + '\n', text=True,
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                            timeout=5, check=False)
    return result.returncode == 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('results', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if not shutil.which('zsh'):
        parser.error('zsh is required for syntax checks')
    records = [json.loads(line) for line in args.results.read_text(encoding='utf-8').splitlines()]
    details = []
    for record in records:
        if record['status'] != 'ok':
            continue
        commands = record['suggestions']
        checks = [syntax_ok(command) for command in commands]
        details.append({'id': record['id'], 'category': record['category'],
                        'syntax_valid': checks, 'duplicate_suggestions': len(commands) - len(set(commands))})
    report = {'results_file': args.results.name, 'method': 'zsh -f -n; parse only, no commands executed',
              'semantic_correctness_evaluated': False, 'security_evaluated': False,
              'successful_prompts_checked': len(details),
              'suggestions_checked': sum(len(item['syntax_valid']) for item in details),
              'syntax_valid_suggestions': sum(sum(item['syntax_valid']) for item in details),
              'prompts_with_all_suggestions_syntactically_valid': sum(all(item['syntax_valid']) for item in details),
              'duplicate_suggestions': sum(item['duplicate_suggestions'] for item in details),
              'details': details}
    fd = os.open(args.output, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, 'w', encoding='utf-8') as output:
        json.dump(report, output, indent=2)
        output.write('\n')
    print(f'Syntax analysis saved to {args.output}')


if __name__ == '__main__':
    main()
