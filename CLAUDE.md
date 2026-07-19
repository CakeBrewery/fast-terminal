# fast-terminal — design rules

This repo is one script, `setup_fast_terminal.sh`, that converges a Mac to a
fast, pretty terminal. Every change must keep these conventions:

- **Self-contained.** One installation script and the resulting configuration
is self-contained in fast-terminal owned files with minimal changes and references
from general configuration files (ie. .zshrc). Config sources live in `config/`;
`setup_fast_terminal.sh` holds only the logic that installs them.

- **Convergent.** Re-running always lands in the same state. Generated files
  are rewritten only when content differs (`write_managed_file`), include
  lines are appended exactly once (`ensure_include`), and tmux appends
  (`set -ga`/`-as`) sit inside `%if` guards so re-sourcing never accumulates.
  `[SUCCESS]` prints only for an actual change; a converged machine prints
  `[INFO]` only. 

- **Owned vs. touched.** The script owns its generated files
  (`fast_terminal.zsh`, `fast-terminal.conf`, `FastTerminal.json`) and touches
  user files (`~/.zshrc`, `~/.tmux.conf`, Ghostty `config`) with minimally. 
  Uninstall is: delete the owned files, remove the include lines.

- **Fast.** Think twice before introducing potentially slowing changes that may
affect responsiveness of the terminal. Make sure the effects are well understood.

## Conventions

- Commit messages carry no Claude attribution (no `Co-Authored-By` trailers).
- The README stays short and in active voice: say what the script does, not
  what it doesn't.
