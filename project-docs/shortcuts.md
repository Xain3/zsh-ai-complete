# Keyboard Shortcuts for zsh-ai-complete

This document lists and explains the default keyboard shortcuts available in the `zsh-ai-complete` plugin.

## 🧠 Main Shortcut

### `Ctrl+U`

- **Action:** Triggers the AI assistant widget.
- **Behavior:** Opens an interactive FZF interface where you can type a partial command or a question.

#### Modes of Use (typed inside FZF, not in terminal)

##### 1. Command Completion

- Inside the FZF prompt, type part of a terminal command.
- The assistant will suggest one or more possible completions based on what you typed.

##### 2. Natural Language to Command

- Type a full question or instruction in plain language.
- Example: `how do I see the logs of a running docker container`
- The assistant will interpret it and suggest relevant terminal commands.

> 💡 If your selected AI provider supports multiple languages, you can ask your question in your native language as well (e.g., Portuguese, Spanish, etc.).

This dual behavior allows both experienced and new users to get productive suggestions based on either syntax or intent.

---

## 🔁 Dynamic Selection Shortcuts (inside FZF)

Once the AI assistant is triggered and the FZF interface is visible:

### `Ctrl+E`

- **Action:** Change the active AI provider.
- **Effect:** Opens a selection menu listing all providers defined in `ai-providers.json`.

### `ESC` or `Ctrl+C`

- **Action:** Cancel the current suggestion session.
- **Effect:** Aborts the assistant without modifying your command buffer.

---

## 📝 Notes

- Run `zsh-ai-complete config shortcut` in Zsh and press a control or escape
  key combination to change the activation shortcut. Press `Ctrl+G` to cancel.
- The setting is stored in `~/.config/zsh-ai-complete/settings.json` and takes
  effect in a new Zsh session. Delete the settings file to restore `Ctrl+U`.
- The selected key may already be assigned by Zsh or another plugin. The
  `Ctrl+E` and `ESC` shortcuts inside FZF are not changed by this setting.
- The picker checks the current Zsh `main` keymap and warns about selected
  commonly used shortcuts. It asks before saving a possible conflict.
- This is not a complete system-wide conflict detector. Terminals, desktop
  environments, and multiplexers can intercept or remap keys before Zsh sees
  them, and some combinations are indistinguishable in terminal input. A key
  intercepted before capture cannot trigger a warning. Later shell setup may
  also change the binding.

The common-default warnings are informed by the maintained upstream
[Zsh keymap documentation](https://zsh.sourceforge.io/Doc/Release/Zsh-Line-Editor.html),
[tmux FAQ](https://github.com/tmux/tmux/wiki/FAQ), and
[GNU Screen manual](https://www.gnu.org/software/screen/manual/screen.html).

---

_Last updated: 2025-04-13_
