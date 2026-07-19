# fast-terminal

One idempotent command that sets up a fast, pretty terminal environment on
macOS: a snappy zsh, a fully configured tmux, and a Snazzy-themed terminal
emulator (iTerm2 or Ghostty, auto-detected).

```sh
./setup_fast_terminal.sh
```

Safe to re-run at any time: files are only rewritten when their content
changes, include lines are appended exactly once, and `[SUCCESS]` is only
printed for actual changes. A fully configured machine produces `[INFO]`-only
output.

## What it sets up

**zsh** (based on [Life is too short for a slow terminal](https://mijndertstuij.nl/posts/life-is-too-short-for-a-slow-terminal/))

- [Pure](https://github.com/sindresorhus/pure) async prompt with cached completions
- [fzf](https://github.com/junegunn/fzf) with keybindings (Ctrl-R history, Ctrl-T files)
- [fzf-tab](https://github.com/Aloxaf/fzf-tab), [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions), [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting)
- Lazy-loaded nvm and kubectl completion

**tmux** (based on the [Dreams of Code tmux setup](https://github.com/dreamsofcode-io/tmux))

- `Ctrl+Space` prefix, mouse support, vi copy-mode, windows/panes numbered from 1
- Alt-arrows to switch panes, Shift-arrows to switch windows, splits keep the current directory
- [tpm](https://github.com/tmux-plugins/tpm)-managed plugins (installed automatically): tmux-sensible, vim-tmux-navigator, tmux-yank
- Snazzy theme on a `#1b1b1b` (Vine Black) background instead of catppuccin

**Terminal emulator** — detected from the terminal the script is run in (it
sees through tmux to the outer terminal):

- **iTerm2**: a "Fast Terminal" dynamic profile (Snazzy palette downloaded
  from [iterm2-snazzy](https://github.com/sindresorhus/iterm2-snazzy) at run
  time, `#1b1b1b` background, Menlo 12, vertical cursor), set as the default
  profile. Restart iTerm2 (Cmd+Q) to apply. If the download fails, the iTerm2
  step is skipped with a warning and everything else still applies.
- **Ghostty**: the same look via `~/.config/ghostty/`, using Ghostty's bundled
  Snazzy theme. Reload the config (Cmd+Shift+,) to apply.

Run the script once from each terminal app you use.

## Files it touches

| File | How |
|---|---|
| `~/.zsh/fast_terminal.zsh` | generated (owned by the script) |
| `~/.zshrc` | one `source` line appended once |
| `~/.zsh/{fzf-tab,zsh-autosuggestions,zsh-syntax-highlighting,pure}`, `~/.fzf` | cloned |
| `~/.config/tmux/fast-terminal.conf` | generated (owned by the script) |
| `~/.tmux.conf` (or existing `~/.config/tmux/tmux.conf`) | one `source-file` line appended once |
| `~/.tmux/plugins/` | tpm and its plugins, cloned |
| `~/.config/ghostty/fast-terminal.conf` | generated (owned by the script) |
| `~/.config/ghostty/config` | one `config-file` line appended once |
| `~/Library/Application Support/iTerm2/DynamicProfiles/FastTerminal.json` | generated (owned by the script) |
| iTerm2 preferences | `Default Bookmark Guid` set to the Fast Terminal profile |

"Owned by the script" files are fully regenerated on change — don't edit them
by hand; put personal overrides after the include line in your own config.

If a tmux server is running, config changes are loaded into it immediately.

## Requirements

- macOS with git and zsh
- tmux ≥ 3.0 (optional — the tmux step is skipped when tmux isn't installed)
- iTerm2 and/or Ghostty for the emulator styling (other terminals: shell and
  tmux setup still apply)

## Uninstall

Remove the include lines added to `~/.zshrc`, `~/.tmux.conf`, and
`~/.config/ghostty/config`, then delete the generated/cloned paths from the
table above, and in iTerm2 pick a different default profile.
