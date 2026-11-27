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

_zsh_ai_is_wsl() {
  [[ -n "$WSL_DISTRO_NAME" || -n "$WSL_INTEROP" ]] && return 0
  local release
  [[ -r /proc/sys/kernel/osrelease ]] || return 1
  release=$(</proc/sys/kernel/osrelease)
  [[ "${release:l}" == *microsoft* ]]
}

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

  local key part tmp binding common_warning windows_warning answer settings_dir="${_zsh_ai_settings:h}"
  local is_wsl=0
  if _zsh_ai_is_wsl; then
    is_wsl=1
    print -u2 'WSL: Windows Terminal may intercept Ctrl+Shift+C/V (copy/paste) or Ctrl+Shift+T (new tab).'
    print -u2 'Ctrl+Shift+W can close a Windows Terminal pane; do not press it to test the picker.'
    print -u2 'Windows may intercept Win+L, Win+D, and Alt+Tab. These keys may never reach this picker.'
    print -u2 'Shortcuts can be customized; check your terminal and Windows settings.'
  fi
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

  # The terminal may intercept keys before Zsh can observe them. These are
  # common defaults, not a claim about the user's terminal or multiplexer.
  case "$key" in
    $'\C-a') common_warning='Ctrl+A is commonly used for line start or as the GNU Screen prefix.' ;;
    $'\C-b') common_warning='Ctrl+B is commonly used for cursor movement or as the tmux prefix.' ;;
    $'\C-c') common_warning='Ctrl+C commonly interrupts the foreground process.' ;;
    $'\C-d') common_warning='Ctrl+D commonly sends EOF or deletes a character.' ;;
    $'\C-i') common_warning='Ctrl+I is usually indistinguishable from Tab (completion).' ;;
    $'\C-l') common_warning='Ctrl+L commonly clears the terminal display.' ;;
    $'\C-q'|$'\C-s') common_warning='Ctrl+Q/Ctrl+S may control terminal output flow.' ;;
    $'\C-r') common_warning='Ctrl+R commonly searches command history.' ;;
    $'\C-u') common_warning='Ctrl+U commonly clears text before the cursor.' ;;
    $'\C-w') common_warning='Ctrl+W commonly deletes the previous word.' ;;
    $'\C-z') common_warning='Ctrl+Z commonly suspends the foreground process.' ;;
  esac
  if (( is_wsl )); then
    # Traditional terminals may encode Ctrl+Shift+letter as Ctrl+letter.
    # This is a possible collision, not proof of the physical keys pressed.
    case "$key" in
      $'\C-c'|$'\C-v') windows_warning='This sequence may also represent Ctrl+Shift+C/V, commonly used for Windows Terminal copy/paste.' ;;
      $'\C-t') windows_warning='This sequence may also represent Ctrl+Shift+T, commonly used for a new Windows Terminal tab.' ;;
      $'\C-w') windows_warning='This sequence may also represent Ctrl+Shift+W, commonly used to close a Windows Terminal pane.' ;;
    esac
  fi
  binding=$(bindkey -M main "$key" 2>/dev/null)
  if [[ "$binding" == *' undefined-key' || "$binding" == *' ai_complete_widget' ]]; then
    binding=''
  fi
  if [[ -n "$common_warning" || -n "$windows_warning" || -n "$binding" ]]; then
    [[ -n "$common_warning" ]] && print -u2 -r -- "Warning: $common_warning"
    [[ -n "$windows_warning" ]] && print -u2 -r -- "Warning: $windows_warning"
    [[ -n "$binding" ]] && print -u2 -r -- "Warning: current Zsh main keymap binding: $binding"
    print -u2 -n 'Save this shortcut anyway? [y/N] '
    if ! IFS= read -r answer || [[ "$answer" != [yY] ]]; then
      print -u2 'Cancelled; shortcut not changed.'
      return 1
    fi
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
