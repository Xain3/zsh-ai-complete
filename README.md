# zsh-ai-complete

<p align="center">
  <img src="assets/logo.png" alt="zsh-ai-complete Logo" width="200" />
</p>

<p align="center">
  <strong>Complete Zsh commands using real-time AI ✨</strong><br>
  Supports OpenAI, Ollama, Gemini, and other configurable models.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/contributions-welcome-brightgreen.svg" alt="Contributions Welcome" />
  <img src="https://img.shields.io/badge/changelog-active-blue.svg" alt="Changelog Available" />
</p>

---

## 🔍 About

**zsh-ai-complete** is a Zsh plugin that brings artificial intelligence to your terminal.
It suggests and completes Zsh commands in real time using natural language or partial input.

This is [Xain3's fork](https://github.com/Xain3/zsh-ai-complete) of the
[original zsh-ai-complete project](https://github.com/lgdevlop/zsh-ai-complete),
created by [Leonardo Gomes](https://github.com/lgdevlop). The fork adds security
and privacy improvements and a configurable activation shortcut.

- 🤖 Works with OpenAI, Ollama, Gemini, and more
- ⚡ Instant AI-powered command suggestions
- 🔄 Switch providers live with `Ctrl+E`
- 🔐 Local config file with API tokens and preferences

---

## ⚙️ Requirements

Make sure the following tools are installed on your system:

| Tool  | Purpose                                 | Link |
|-------|-----------------------------------------|------|
| [`fzf`](https://github.com/junegunn/fzf) 0.47.0 or newer | Interactive search UI | [Link](https://github.com/junegunn/fzf) |
| [`curl`](https://curl.se/)                | API requests                         | [Link](https://curl.se/) |
| [`jq`](https://stedolan.github.io/jq/)    | JSON parsing                         | [Link](https://stedolan.github.io/jq/) |
| [`bat`](https://github.com/sharkdp/bat)   | Syntax-highlighted command preview   | [Link](https://github.com/sharkdp/bat) |
| [`fd`](https://github.com/sharkdp/fd)     | Optional, for file previews          | [Link](https://github.com/sharkdp/fd) |

---

## 🚀 Installation

### Manual

```bash
git clone https://github.com/Xain3/zsh-ai-complete.git ~/.zsh-ai-complete
echo "source ~/.zsh-ai-complete/zsh-ai-complete.plugin.zsh" >> ~/.zshrc
source ~/.zshrc
```

### Zinit

```zsh
zinit light Xain3/zsh-ai-complete
```

### Antigen

```zsh
antigen bundle Xain3/zsh-ai-complete
```

### Oh My Zsh (manual plugin)

```bash
git clone https://github.com/Xain3/zsh-ai-complete.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-ai-complete
```

Then add to your `.zshrc`:

```zsh
plugins=(git zsh-ai-complete)
```

Reload with:

```zsh
omz reload   # if using Oh My Zsh
# or
source ~/.zshrc
```

---

## 🛠 Configuration

On first use, the plugin creates:

```bash
~/.config/zsh-ai-complete/ai-providers.json
```

The default provider on first use is Ollama at `http://localhost:11434/api/chat`.
Choose another configured provider with Ctrl+E. Existing provider selections are
preserved. The Ollama example does not require an API token.

Queries are sent to the selected provider as you type after a short pause. With
the default endpoint they go to the local Ollama service; check the configured
URL before entering sensitive text. Suggestions are inserted into your command
line and run only when you execute them. Review them first. New configuration
files are created with restrictive permissions; check permissions on any files
that already existed.

`fzf` 0.47.0 or newer is required so queries can be passed through the child
process environment rather than command-line arguments. The plugin refuses to
start with older versions. Environment visibility depends on the host's process
access controls; a local process with sufficient privileges may still read it.

Provider tokens require HTTPS for non-loopback endpoints. Plain HTTP with a
token is permitted only for `localhost`, `127.0.0.1`, or `[::1]`. Requests
without a token may still use HTTP, so use HTTPS for remote services to protect
query contents in transit.

Based on the example:

```bash
example.ai-providers.json
```

Customize it with your tokens and preferences:

```json
{
  "openai": {
    "url": "https://api.openai.com/v1/chat/completions",
    "token": "your_api_key",
    "model": "gpt-4",
    "system_message": "You must output exactly five complete zsh commands. No explanations, no comments, no code blocks, no numbering, no blank lines. Output only the commands, one per line.",
    "output_path": ".choices[0].message.content"
  }
}
```

---

## 💡 Usage

1. Press `Ctrl+U` to launch the assistant (via `fzf`)
2. Type a command fragment _or_ a natural question (multi-language supported)
3. Select one of the AI-suggested commands

> Example: `how do I list docker containers by name?`

See [`project-docs/examples.md`](./project-docs/examples.md) for full walkthroughs.

---

## ⌨️ Shortcuts

The activation shortcut defaults to `Ctrl+U`. To choose another shortcut,
run this command in an interactive Zsh session after loading the plugin:

```zsh
zsh-ai-complete config shortcut
```

Press the desired control or escape key combination when prompted; `Ctrl+G`
cancels. The shortcut is stored as JSON in
`~/.config/zsh-ai-complete/settings.json`. Start a new Zsh session to apply
the change. This may override an existing Zsh or plugin binding, so choose an
unused shortcut. The picker checks the current Zsh `main` keymap and warns
about some common terminal, tmux, and GNU Screen shortcuts; it asks for
confirmation before saving a potential conflict. Delete the settings file to
restore the default.

This check is advisory: shortcuts vary by terminal, operating system, keymap,
and user configuration. Some shortcuts are intercepted before Zsh receives
them, and some key combinations produce the same terminal byte sequence. If a
key does not reach the prompt, cancel with `Ctrl+G` and try another shortcut.
Bindings installed after this plugin loads can override it.

On WSL, the picker also points out common Windows and Windows Terminal
shortcuts before capture. It warns when a captured byte sequence could be a
Windows Terminal shortcut, but cannot determine whether Shift was pressed
when the terminal sends the same bytes. It does not inspect your actual
Windows or Windows Terminal settings.

| Key       | Action                                |
|-----------|----------------------------------------|
| `Ctrl+U`  | Launch the AI command assistant (default, configurable) |
| `Ctrl+E`  | Switch between configured providers    |
| `ESC`     | Cancel without applying a suggestion   |

More details in [`project-docs/shortcuts.md`](./project-docs/shortcuts.md)

---

## 🛣️ Roadmap

- [x] Support for multiple AI backends
- [x] Dynamic provider switching (Ctrl+E)
- [x] Example and shortcut documentation
- [ ] Output theming and advanced previews
- [ ] Cached suggestions

---

## 🤝 Contributing

Contributions are welcome! Feel free to open issues or pull requests.

See [`CODE_OF_CONDUCT.md`](./CODE_OF_CONDUCT.md).

---

## 📄 License

MIT — See [`LICENSE`](./LICENSE).

---

## 👤 Credits

Originally created by [Leonardo Gomes](https://github.com/lgdevlop).
This fork is maintained by [Xain3](https://github.com/Xain3).

---

<p align="center">
  <strong>✨ zsh-ai-complete — Make your terminal smarter with the power of AI!</strong>
</p>
