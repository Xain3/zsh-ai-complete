#!/usr/bin/env python3
import contextlib
import http.server
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('benchmark', Path(__file__).with_name('run.py'))
benchmark = importlib.util.module_from_spec(spec)
spec.loader.exec_module(benchmark)
syntax_spec = importlib.util.spec_from_file_location('syntax_analysis', Path(__file__).with_name('analyze.py'))
syntax_analysis = importlib.util.module_from_spec(syntax_spec)
syntax_spec.loader.exec_module(syntax_analysis)


class BenchmarkTests(unittest.TestCase):
    def test_dataset_contains_one_hundred_unique_cases(self):
        _, cases = benchmark.load_cases()
        self.assertEqual(len(cases), 100)
        self.assertEqual(len({case['prompt'] for case in cases}), 100)

    def test_cloud_is_explicit_and_requires_a_key(self):
        with patch.dict(os.environ, {}, clear=True):
            self.assertEqual(benchmark.choose_backend()[:2], ('ollama', 'qwen2.5-coder:7b'))
        with patch.dict(os.environ, {'ZSH_AI_BENCH_OPENAI': '1'}, clear=True):
            with self.assertRaises(ValueError):
                benchmark.choose_backend()
        with patch.dict(os.environ, {'ZSH_AI_BENCH_OPENAI': '1', 'OPENAI_API_KEY': 'test'}, clear=True):
            self.assertEqual(benchmark.choose_backend()[:2], ('openai', 'gpt-6-luna'))
        with patch.dict(os.environ, {'ZSH_AI_BENCH_OPENAI': 'yes'}, clear=True):
            with self.assertRaises(ValueError):
                benchmark.choose_backend()

    def test_query_is_not_in_arguments_and_api_key_is_removed_from_child_environment(self):
        case = {'id': 'test-01', 'category': 'test', 'prompt': 'test query'}
        fake = subprocess.CompletedProcess([], 0, stdout='echo ok\n', stderr='')
        with patch.dict(os.environ, {'OPENAI_API_KEY': 'test-secret'}), \
             patch.object(benchmark.subprocess, 'run', return_value=fake) as run:
            result = benchmark.run_case(case, Path('/config'), Path('/selection'))
        self.assertEqual(result['suggestions'], ['echo ok'])
        self.assertNotIn('test query', run.call_args.args[0])
        self.assertNotIn('OPENAI_API_KEY', run.call_args.kwargs['env'])
        self.assertEqual(run.call_args.kwargs['env']['FZF_QUERY'], 'test query')

    def test_actual_request_helper_against_local_server(self):
        received = []
        class Handler(http.server.BaseHTTPRequestHandler):
            def do_POST(self):
                received.append(json.loads(self.rfile.read(int(self.headers['Content-Length']))))
                self.send_response(200)
                self.end_headers()
                self.wfile.write(json.dumps({'message': {'content': '\n'.join(['echo ok'] * 5)}}).encode())
            def log_message(self, *args):
                pass
        server = http.server.HTTPServer(('127.0.0.1', 0), Handler)
        thread = threading.Thread(target=server.handle_request, daemon=True)
        thread.start()
        with server, tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            config, selection = root / 'config.json', root / 'selection'
            config.write_text(json.dumps({'ollama': {'url': f'http://127.0.0.1:{server.server_port}/api/chat',
                'token': '', 'model': 'local', 'system_message': 'test', 'output_path': '.message.content'}}))
            selection.write_text('ollama')
            case = {'id': 'test-01', 'category': 'test', 'prompt': 'quoted "query"'}
            result = benchmark.run_case(case, config, selection)
            thread.join(timeout=5)
            self.assertEqual(result['status'], 'ok')
            self.assertEqual(result['suggestion_count'], 5)
            self.assertEqual(received[0]['messages'][1]['content'], case['prompt'])

    def test_syntax_check_parses_without_executing_commands(self):
        with tempfile.TemporaryDirectory() as directory:
            marker = Path(directory) / 'must-not-exist'
            self.assertTrue(syntax_analysis.syntax_ok(f'touch {marker}'))
            self.assertFalse(syntax_analysis.syntax_ok('if then'))
            self.assertFalse(marker.exists())

    def test_complete_run_writes_results_and_refuses_overwrite(self):
        def fake_case(case, config, selection):
            return {**case, 'status': 'ok', 'suggestions': ['echo ok'] * 5,
                    'suggestion_count': 5, 'duration_ms': 1, 'error': ''}
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'results.jsonl'
            with open(os.devnull, 'w') as sink, \
                 patch.dict(os.environ, {}, clear=True), \
                 patch.object(sys, 'argv', ['run.py', '--output', str(output)]), \
                 patch.object(benchmark, 'run_case', side_effect=fake_case), \
                 contextlib.redirect_stdout(sink):
                self.assertEqual(benchmark.main(), 0)
                with self.assertRaises(FileExistsError):
                    benchmark.main()
            records = [json.loads(line) for line in output.read_text().splitlines()]
            summary = json.loads(Path(str(output) + '.summary.json').read_text())
            self.assertEqual(len(records), 100)
            self.assertEqual(summary['successful_prompts'], 100)
            self.assertEqual(summary['backend'], 'ollama')


if __name__ == '__main__':
    unittest.main()
