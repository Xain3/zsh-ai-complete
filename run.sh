#!/bin/zsh

CONFIG_DIR="$HOME/.config/zsh-ai-complete"
CONFIG_FILE="$CONFIG_DIR/ai-providers.json"
SELECTION_FILE="$CONFIG_DIR/selected-provider.txt"

ensure_config_file() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    (umask 077; mkdir -p "$CONFIG_DIR" && cp "$PLUGIN_DIR/example.ai-providers.json" "$CONFIG_FILE") || return 1
  fi
  if [[ ! -s "$SELECTION_FILE" ]]; then
    (umask 077; print -r -- ollama > "$SELECTION_FILE") || return 1
  fi
}

search_ia_widget() {
  local selected_provider selected key choice fzf_status reload_command
  selected_provider=$(<"$SELECTION_FILE")
  jq -e --arg provider "$selected_provider" '.[$provider] | objects' "$CONFIG_FILE" >/dev/null || return 1

  # Quote paths for fzf's shell; provider settings are read as data by the helper.
  reload_command="sleep 0.5; bash ${(q)PLUGIN_DIR}/request.sh ${(q)CONFIG_FILE} ${(q)SELECTION_FILE}"
  selected=$(fzf --height=100% --layout=reverse --expect=esc,ctrl-c,ctrl-e \
    --bind "change:reload:$reload_command" \
    --prompt="Search for content in ($selected_provider): " \
    --phony --disabled < /dev/null)
  fzf_status=$?
  key=${selected%%$'\n'*}
  if [[ "$key" == ctrl-e && ( $fzf_status -eq 0 || $fzf_status -eq 1 ) ]]; then
    show_providers
    return 42
  fi
  [[ $fzf_status -eq 0 ]] || return 0
  [[ "$key" == esc || "$key" == ctrl-c ]] && return 0
  [[ "$selected" == *$'\n'* ]] || return 0
  choice=${selected#*$'\n'}
  [[ -n "$choice" ]] && LBUFFER+="$choice"
  return 0
}

show_providers() {
  local providers selected key choice fzf_status
  providers=$(jq -r 'keys[]' "$CONFIG_FILE") || return 0
  selected=$(print -r -- "$providers" | fzf --expect=esc,ctrl-c --prompt="Choose an AI provider: ")
  fzf_status=$?
  [[ $fzf_status -eq 0 && "$selected" == *$'\n'* ]] || return 0
  key=${selected%%$'\n'*}
  choice=${selected#*$'\n'}
  [[ "$key" == esc || "$key" == ctrl-c || -z "$choice" ]] && return 0
  (umask 077; print -r -- "$choice" > "$SELECTION_FILE") || return 0
  return 42
}

ai_complete_widget() {
  local result fzf_version
  fzf_version=$(fzf --version 2>/dev/null) || {
    print -u2 '[zsh-ai-complete] fzf 0.47.0 or newer is required.'
    return 1
  }
  fzf_version=${fzf_version%% *}
  autoload -Uz is-at-least
  if [[ "$fzf_version" != <->.<->.<->* ]] || ! is-at-least 0.47.0 "$fzf_version"; then
    print -u2 '[zsh-ai-complete] fzf 0.47.0 or newer is required to protect query privacy.'
    return 1
  fi
  ensure_config_file || return 1
  while true; do
    search_ia_widget
    result=$?
    if [[ $result -eq 1 ]]; then
      show_providers
      result=$?
    fi
    [[ $result -eq 42 ]] || break
  done
}
