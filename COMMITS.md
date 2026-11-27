# Commit Message Conventions

This project uses **Conventional Commits** for commit messages, pull request
titles, and squash commit titles. Emoji are optional.

We follow a structure inspired by [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) and [Gitmoji](https://gitmoji.dev/).

---

## 🔠 Format

```bash
<type>[optional scope][!]: short description
```

**Example:**

```bash
feat(widget): ✨ add shortcut to dynamically switch AI provider
fix: preserve the command line when completion is canceled
```

## Pull requests and squash merges

- Give every pull request a Conventional Commit title **before merging**.
- When using squash merge, check that the final squash commit title also follows
  the convention and accurately describes the combined change. The pull request
  title may be used as the starting point; edit the squash title if needed.
- Use `!` before the colon or a `BREAKING CHANGE:` footer for incompatible
  changes. See [Versioning and releases](RELEASE_PROCESS.md) when choosing the
  corresponding SemVer bump.

For example, a pull request titled `feat(widget): add a configurable shortcut`
can use the same title for its squash commit. A trailing pull request reference
such as `(#12)` is fine.

---

## 📚 Type Reference

| Type      | Purpose                                          | Emoji   | Example Commit                                          |
|-----------|--------------------------------------------------|---------|---------------------------------------------------------|
| `feat`    | Add new feature                                  | ✨      | `feat(run): ✨ add support for Grok API`               |
| `fix`     | Bug fix                                          | 🐛      | `fix(fzf): 🐛 escape issue in preview command`         |
| `docs`    | Documentation update                             | 📝      | `docs(README): 📝 update install instructions`         |
| `style`   | Code formatting, no logic change                 | 🎨      | `style(run): 🎨 reindent block for clarity`            |
| `refactor`| Code refactor without adding feature or fixing   | ♻️      | `refactor(prompt): ♻️ simplify message generation`     |
| `perf`    | Performance improvements                         | ⚡      | `perf(json): ⚡ optimize jq parsing of response`       |
| `test`    | Add or update tests                              | ✅      | `test(widget): ✅ add basic test for escape keys`      |
| `build`   | Build system or dependency updates               | 📦      | `build(deps): 📦 update jq version`                    |
| `ci`      | CI configuration or pipeline changes             | 👷      | `ci(github): 👷 add preinstall step for FZF`           |
| `chore`   | Maintenance tasks, configs, gitignore, etc.      | 🔧      | `chore(config): 🔧 rename selection file`              |
| `revert`  | Revert a previous commit                         | ⏪      | `revert(run): ⏪ undo widget binding patch`            |

---

## 🧭 Scope Reference

Scopes help clarify which part of the codebase is affected by the change.

| Scope        | Description                                                       |
|--------------|-------------------------------------------------------------------|
| `README`     | Main project readme                                               |
| `shortcuts`  | Keyboard shortcut documentation                                   |
| `examples`   | Usage examples under `project-docs/examples.md`                   |
| `plugin`     | Plugin entry file `zsh-ai-complete.plugin.zsh`                    |
| `run`        | Main script logic in `run.sh`                                     |
| `install`    | Installation script and related automation logic                  |
| `config`     | Configuration system (e.g., `ai-providers.json`, example config)  |
| `widget`     | ZLE widget binding logic or interactions                          |
| `docs`       | Markdown files under `project-docs/`                              |
| `deps`       | Dependencies or Makefile/Install related logic                    |
| `ci`         | GitHub Actions, CI setup                                          |
| `assets`     | Project assets like logo or media files                           |

Use scopes that reflect the intent of the commit for better organization and filtering.

---

## 🚨 Breaking Changes

If a change introduces a breaking change:

```bash
feat(core): 💥 drop support for legacy OpenWebUI

BREAKING CHANGE: This removes compatibility with older versions of the plugin.
```

Use `!` in the header or `BREAKING CHANGE:` in the footer to mark an
incompatible change; use a **major release bump** for an already released API.

---

## ✅ Tips

- Use present tense (`add` not `added`, `fix` not `fixed`)
- Keep messages under 100 characters when possible
- Emoji are optional and belong in the description, after the colon

---

## 🔗 Resources

- [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)
- [Gitmoji Reference](https://gitmoji.dev/)
- [Commitlint](https://github.com/conventional-changelog/commitlint)
- [Emoji Cheat Sheet](https://www.webfx.com/tools/emoji-cheat-sheet/)

---

Happy committing! 🚀
