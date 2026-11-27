# Completion benchmark

This opt-in benchmark runs 100 synthetic prompts through the plugin's actual
`request.sh` helper. It saves each prompt, the returned suggestions, request
duration, errors, and a summary. It **never executes suggestions**. Counts of
five-line responses measure formatting, not command correctness or safety.

The default backend is local Ollama. Set `ZSH_AI_BENCH_OPENAI=1` to use
`gpt-6-luna` through OpenAI instead; this sends the benchmark prompts to OpenAI
and may incur API charges. No automatic cloud fallback occurs. This switch only
affects this benchmark and does not change the plugin's provider configuration.

Requirements: Python 3, Bash, jq, curl, and either Ollama with `qwen2.5-coder:7b`
or a valid `OPENAI_API_KEY` in the environment. Run from a Unix-like shell:

```sh
ZSH_AI_BENCH_OPENAI=1 python3 benchmarks/run.py --output /path/to/results.jsonl
```

Omit the environment switch for the Ollama baseline. The companion summary is
written next to the JSONL file with `.summary.json` appended. Results contain
prompts and model output; store them privately. Existing result files are never
overwritten. Use the same prompt dataset and record model versions when comparing
runs. The tool does not measure token usage and does not claim semantic accuracy.

Optionally check the syntax of saved suggestions without executing them:

```sh
python3 benchmarks/analyze.py /path/to/results.jsonl --output /path/to/syntax.json
```

This uses `zsh -f -n` for parsing only. Valid shell syntax does not establish
that a suggestion is correct, safe, or suitable for your system.
