#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/home"
export PATH="$tmp/bin:$PATH" HOME="$tmp/home" TEST_TMP="$tmp"
export REAL_JQ=$(command -v jq)

cat > "$tmp/bin/curl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$TEST_TMP/args"
while (($#)); do
  if [[ $1 == --config ]]; then cat "$2" > "$TEST_TMP/curl-config"; shift; fi
  shift
done
cat > "$TEST_TMP/payload"
printf '%s\n' '{"message":{"content":"echo safe"}}'
EOF
cat > "$tmp/bin/fzf" <<'EOF'
#!/usr/bin/env bash
if [[ ${1-} == --version ]]; then printf '%s\n' "${FZF_VERSION-0.60.3}"; exit 0; fi
printf '%s' "${FZF_RESULT-}"
exit "${FZF_STATUS-0}"
EOF
cat > "$tmp/bin/jq" <<'EOF'
#!/usr/bin/env bash
if [[ ${FZF_QUERY+x} ]]; then echo 'FZF_QUERY was not cleared' >&2; exit 1; fi
printf '%s\n' "$@" >> "$TEST_TMP/jq-args"
exec "$REAL_JQ" "$@"
EOF
chmod +x "$tmp/bin/curl" "$tmp/bin/fzf" "$tmp/bin/jq"

marker="$tmp/executed"
query=$'SENSITIVE_QUERY_MARKER quotes " backslash \\ and\nnewline\n'
jq -n --arg marker "$marker" '{ollama:{url:"http://localhost:11434/api/chat",model:("$(touch " + $marker + ")"),system_message:"quoted \" text",token:"secret-token",output_path:".message.content"}}' > "$tmp/config"
printf ollama > "$tmp/selection"
result=$(FZF_QUERY="$query" bash "$root/request.sh" "$tmp/config" "$tmp/selection")
[[ $result == 'echo safe' && ! -e $marker ]]
jq -e --arg q "$query" '.messages[1].content == $q' "$tmp/payload" >/dev/null
! grep -q secret-token "$tmp/args"
! grep -q SENSITIVE_QUERY_MARKER "$tmp/jq-args"
grep -q secret-token "$tmp/curl-config"

# Reject cleartext remote credentials, including hostnames that only resemble
# loopback. The fake curl leaves a marker if a request was attempted.
for url in 'http://example.com/api' 'http://localhost.example.com/api' 'http://localhost@evil.example/api'; do
  jq --arg url "$url" '.ollama.url = $url' "$tmp/config" > "$tmp/remote-config"
  rm -f "$tmp/args"
  if FZF_QUERY=query bash "$root/request.sh" "$tmp/remote-config" "$tmp/selection" 2>/dev/null; then
    echo "Accepted insecure authenticated URL: $url" >&2
    exit 1
  fi
  [[ ! -e "$tmp/args" ]]
done
jq '.ollama.url = "https://example.com/api"' "$tmp/config" > "$tmp/remote-config"
FZF_QUERY=query bash "$root/request.sh" "$tmp/remote-config" "$tmp/selection" >/dev/null
[[ -e "$tmp/args" ]]
for url in 'http://localhost:11434/api/chat' 'http://127.0.0.1/api' 'http://[::1]:11434/api'; do
  jq --arg url "$url" '.ollama.url = $url' "$tmp/config" > "$tmp/remote-config"
  FZF_QUERY=query bash "$root/request.sh" "$tmp/remote-config" "$tmp/selection" >/dev/null
done
jq '.ollama.url = "http://example.com/api" | .ollama.token = ""' "$tmp/config" > "$tmp/remote-config"
FZF_QUERY=query bash "$root/request.sh" "$tmp/remote-config" "$tmp/selection" >/dev/null

# An absent fzf query must fail closed instead of accepting a query argument.
if env -u FZF_QUERY bash "$root/request.sh" "$tmp/config" "$tmp/selection" 'should-not-be-used' 2>/dev/null; then
  echo 'Accepted a missing fzf query' >&2
  exit 1
fi

# A permissive caller umask must not make newly installed configuration public.
install_home="$tmp/install home"
mkdir -p "$install_home"
(umask 022; cd "$root"; make install HOME="$install_home" >/dev/null)
[[ $(stat -c %a "$install_home/.config/zsh-ai-complete") == 700 ]]
[[ $(stat -c %a "$install_home/.config/zsh-ai-complete/ai-providers.json") == 600 ]]
printf 'existing configuration' > "$install_home/.config/zsh-ai-complete/ai-providers.json"
(umask 022; cd "$root"; make install HOME="$install_home" >/dev/null)
[[ $(cat "$install_home/.config/zsh-ai-complete/ai-providers.json") == 'existing configuration' ]]

# The ZLE widget only inserts a selected suggestion; cancel leaves input intact.
export PLUGIN_TEST_ROOT="$root"
zsh -c '
  PLUGIN_DIR=$PLUGIN_TEST_ROOT
  source "$PLUGIN_DIR/run.sh"
  ensure_config_file || exit 1
  [[ $(<"$SELECTION_FILE") == ollama ]] || exit 2
  LBUFFER="prefix "
  export FZF_RESULT=$'"'"'\necho safe'"'"'
  search_ia_widget || exit 3
  [[ "$LBUFFER" == "prefix echo safe" ]] || exit 4
  export FZF_STATUS=130 FZF_RESULT=""
  search_ia_widget || exit 5
  [[ "$LBUFFER" == "prefix echo safe" ]] || exit 6
  picker_calls=0
  show_providers() { (( picker_calls++ )); return 0; }
  export FZF_RESULT=ctrl-e FZF_STATUS=1
  search_ia_widget; [[ $? -eq 42 && $picker_calls -eq 1 ]] || exit 7
  [[ "$LBUFFER" == "prefix echo safe" ]] || exit 8
  export FZF_STATUS=0
  search_ia_widget; [[ $? -eq 42 && $picker_calls -eq 2 ]] || exit 9
  for FZF_STATUS in 2 130; do
    export FZF_STATUS
    search_ia_widget || exit 10
    [[ $picker_calls -eq 2 && "$LBUFFER" == "prefix echo safe" ]] || exit 11
  done
  export FZF_STATUS=1 FZF_RESULT=""
  search_ia_widget || exit 12
  [[ $picker_calls -eq 2 && "$LBUFFER" == "prefix echo safe" ]] || exit 13
  search_ia_widget() { return 0; }
  export FZF_VERSION=0.46.0
  if ai_complete_widget 2>/dev/null; then exit 14; fi
  export FZF_VERSION=0.47.0
  ai_complete_widget || exit 15
'
rm "$tmp/bin/curl"
python3 - "$root" "$tmp" <<'PY'
import http.server, json, pathlib, subprocess, sys, threading
root, temp = map(pathlib.Path, sys.argv[1:])
received = {}
class Handler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        received['authorization'] = self.headers.get('Authorization')
        received['payload'] = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b'{"message":{"content":"echo local"}}')
    def log_message(self, *args):
        pass
server = http.server.HTTPServer(('127.0.0.1', 0), Handler)
thread = threading.Thread(target=server.handle_request, daemon=True)
thread.start()
config = {'ollama': {'url': f'http://127.0.0.1:{server.server_port}/api/chat',
    'model': 'local', 'system_message': 'test', 'token': 'test-token',
    'output_path': '.message.content'}}
(temp / 'http-config').write_text(json.dumps(config))
env = {**__import__('os').environ, 'FZF_QUERY': 'a "quoted" query'}
result = subprocess.run(['bash', str(root / 'request.sh'), str(temp / 'http-config'),
    str(temp / 'selection')], env=env, capture_output=True, text=True, timeout=10, check=True)
thread.join(timeout=5)
server.server_close()
assert result.stdout.strip() == 'echo local', result.stderr
assert received['authorization'] == 'Bearer test-token'
assert received['payload']['messages'][1]['content'] == 'a "quoted" query'
PY
echo 'security tests passed'
