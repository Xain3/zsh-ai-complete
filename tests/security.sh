#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/home"
export PATH="$tmp/bin:$PATH" HOME="$tmp/home" TEST_TMP="$tmp"

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
printf '%s' "${FZF_RESULT-}"
exit "${FZF_STATUS-0}"
EOF
chmod +x "$tmp/bin/curl" "$tmp/bin/fzf"

marker="$tmp/executed"
query=$'quotes " backslash \\ and\nnewline'
jq -n --arg marker "$marker" '{ollama:{url:"http://localhost:11434/api/chat",model:("$(touch " + $marker + ")"),system_message:"quoted \" text",token:"secret-token",output_path:".message.content"}}' > "$tmp/config"
printf ollama > "$tmp/selection"
result=$(bash "$root/request.sh" "$tmp/config" "$tmp/selection" "$query")
[[ $result == 'echo safe' && ! -e $marker ]]
jq -e --arg q "$query" '.messages[1].content == $q' "$tmp/payload" >/dev/null
! grep -q secret-token "$tmp/args"
grep -q secret-token "$tmp/curl-config"

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
result = subprocess.run(['bash', str(root / 'request.sh'), str(temp / 'http-config'),
    str(temp / 'selection'), 'a "quoted" query'], capture_output=True, text=True, timeout=10, check=True)
thread.join(timeout=5)
server.server_close()
assert result.stdout.strip() == 'echo local', result.stderr
assert received['authorization'] == 'Bearer test-token'
assert received['payload']['messages'][1]['content'] == 'a "quoted" query'
PY
echo 'security tests passed'
