# fast-terminal

One command sets up a fast, pretty terminal on macOS: a fast zsh, a 
configured tmux, and a Snazzy-themed emulator (iTerm2 or Ghostty,
auto-detected).

```sh
./setup_fast_terminal.sh
```

Run it once from each terminal app you use.

## What it sets up

**zsh** — from [Life is too short for a slow terminal](https://mijndertstuij.nl/posts/life-is-too-short-for-a-slow-terminal/):

- [Pure](https://github.com/sindresorhus/pure) async prompt with cached completions
- [fzf](https://github.com/junegunn/fzf) keybindings (Ctrl-R history, Ctrl-T files)
- [fzf-tab](https://github.com/Aloxaf/fzf-tab), [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions), [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting)
- Lazy-loaded nvm and kubectl completion

**tmux** — from the [Dreams of Code tmux setup](https://github.com/dreamsofcode-io/tmux):

- `Ctrl+Space` prefix, mouse support, vi copy-mode, windows and panes numbered from 1
- Alt-arrows switch panes, Shift-arrows switch windows, splits keep the current directory
- [vim-tmux-navigator](https://github.com/christoomey/vim-tmux-navigator) on both
  sides, so `Ctrl+h/j/k/l` moves seamlessly across vim splits and tmux panes
- Extended keys and passthrough, so apps like Claude Code keep Shift+Enter and
  drag-and-drop file attachments inside tmux
- [tpm](https://github.com/tmux-plugins/tpm)-managed plugins, installed
  automatically: tmux-sensible, vim-tmux-navigator, tmux-yank
- Snazzy status bar with a block-style window list, drawn from the terminal's
  own palette

**Terminal emulator** — detected from the terminal the script runs in:

- **iTerm2**: a "Fast Terminal" dynamic profile — Snazzy palette downloaded from
  [iterm2-snazzy](https://github.com/sindresorhus/iterm2-snazzy), `#1b1b1b`
  (Vine Black) background, Menlo 12, vertical cursor — set as the default
  profile. Restart iTerm2 (Cmd+Q) to apply.
- **Ghostty**: the same look via Ghostty's bundled Snazzy theme. Reload the
  config (Cmd+Shift+,) to apply.

## Files it touches

| File | How |
|---|---|
| `~/.zsh/fast_terminal.zsh` | generated (owned by the script) |
| `~/.zshrc` | one `source` line appended once |
| `~/.zsh/{fzf-tab,zsh-autosuggestions,zsh-syntax-highlighting,pure}`, `~/.fzf` | cloned |
| `~/.config/tmux/fast-terminal.conf` | generated (owned by the script) |
| `~/.tmux.conf` (or existing `~/.config/tmux/tmux.conf`) | one `source-file` line appended once |
| `~/.tmux/plugins/` | tpm and its plugins, cloned |
| `~/.vim/pack/fast-terminal/start/vim-tmux-navigator` | cloned |
| `~/.config/ghostty/fast-terminal.conf` | generated (owned by the script) |
| `~/.config/ghostty/config` | one `config-file` line appended once |
| `~/Library/Application Support/iTerm2/DynamicProfiles/FastTerminal.json` | generated (owned by the script) |
| iTerm2 preferences | `Default Bookmark Guid` set to the Fast Terminal profile |

The script fully regenerates "owned" files on change — put personal overrides
after the include line in your own config, not inside them.

If a tmux server is running, the script loads config changes into it
immediately.

## Requirements

macOS with git and zsh; tmux ≥ 3.2 and vim optional.

## Uninstall

Remove the include lines from `~/.zshrc`, `~/.tmux.conf`, and
`~/.config/ghostty/config`, delete the generated and cloned paths from the
table above, and pick a different default profile in iTerm2.
