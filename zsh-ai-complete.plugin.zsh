# Detect plugin directory
PLUGIN_DIR="${0:A:h}"

# Load the main AI assistant logic
source "$PLUGIN_DIR/run.sh"

# Register ZLE widget
zle -N ai_complete_widget

# Shortcut settings are JSON data, never sourced as shell code.
_zsh_ai_settings="$HOME/.config/zsh-ai-complete/settings.json"
_zsh_ai_shortcut=$'\C-u'
if [[ -f "$_zsh_ai_settings" ]]; then
  if (( $+commands[jq] )); then
    _zsh_ai_saved_shortcut=$(jq -er '.shortcut | select(type == "string" and length > 0)' "$_zsh_ai_settings" 2>/dev/null)
    if [[ -n "$_zsh_ai_saved_shortcut" ]]; then
      _zsh_ai_shortcut="$_zsh_ai_saved_shortcut"
    else
      print -u2 '[zsh-ai-complete] Invalid shortcut settings; using Ctrl+U.'
    fi
  else
    print -u2 '[zsh-ai-complete] jq is required to load shortcut settings; using Ctrl+U.'
  fi
fi
bindkey "$_zsh_ai_shortcut" ai_complete_widget
unset _zsh_ai_saved_shortcut _zsh_ai_shortcut

# Run in the current shell: zsh-ai-complete config shortcut
zsh-ai-complete() {
  if [[ "$1" != config || "$2" != shortcut || $# -ne 2 ]]; then
    print -u2 'Usage: zsh-ai-complete config shortcut'
    return 2
  fi
  if ! (( $+commands[jq] )); then
    print -u2 '[zsh-ai-complete] jq is required to change the shortcut.'
    return 1
  fi
  if [[ ! -t 0 ]]; then
    print -u2 '[zsh-ai-complete] Shortcut capture requires an interactive terminal.'
    return 1
  fi

  local key part tmp settings_dir="${_zsh_ai_settings:h}"
  print -u2 -n 'Press the shortcut to use (Ctrl+G cancels): '
  if ! IFS= read -rs -k 1 key; then
    print -u2 '\n[zsh-ai-complete] Could not read a key.'
    return 1
  fi
  # Read the rest of escape sequences (for example, Alt or arrow keys).
  while IFS= read -rs -t 0.2 -k 1 part; do
    key+="$part"
  done
  print -u2
  if [[ "$key" == $'\C-g' ]]; then
    print -u2 'Cancelled.'
    return 1
  fi
  # Printable characters and lone Escape would disrupt ordinary editing.
  if [[ "$key" == [[:print:]] || "$key" == $'\e' || "$key" == *$'\n'* || "$key" == *$'\r'* || -z "$key" ]]; then
    print -u2 '[zsh-ai-complete] Choose a control or escape key combination.'
    return 1
  fi
  if [[ -f "$_zsh_ai_settings" ]] && ! jq -e 'type == "object"' "$_zsh_ai_settings" >/dev/null 2>&1; then
    print -u2 '[zsh-ai-complete] Settings are not a JSON object; fix the file before updating it.'
    return 1
  fi
  ( umask 077; mkdir -p -- "$settings_dir" ) || return 1
  tmp=$(mktemp "$settings_dir/.settings.XXXXXXXX") || return 1
  if [[ -f "$_zsh_ai_settings" ]]; then
    jq --arg shortcut "$key" '.shortcut = $shortcut' "$_zsh_ai_settings" > "$tmp"
  else
    jq -n --arg shortcut "$key" '{shortcut: $shortcut}' > "$tmp"
  fi
  if [[ $? -ne 0 ]] || ! mv -f -- "$tmp" "$_zsh_ai_settings"; then
    rm -f -- "$tmp"
    print -u2 '[zsh-ai-complete] Could not save shortcut settings.'
    return 1
  fi
  print 'Shortcut saved. Start a new Zsh session to apply it.'
}
