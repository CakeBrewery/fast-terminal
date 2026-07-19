#!/usr/bin/env bash

# setup_fast_terminal.sh — converge this machine to the "fast terminal" setup:
#   - zsh: Pure prompt, cached completions, fzf, plugins, lazy-loaded nvm/kubectl
#   - tmux: Dreams of Code keybindings + tpm-managed plugins, Snazzy theme
#   - terminal emulator: iTerm2 or Ghostty (auto-detected), Snazzy theme
#
# Idempotent: safe to re-run at any time. Generated files are rewritten only
# when their content changes, include lines are appended only once, and
# [SUCCESS] is printed only for actual changes.

set -e

# --- Output helpers ----------------------------------------------------------

info() { echo -e "\033[1;34m[INFO]\033[0m $1"; }
success() { echo -e "\033[1;32m[SUCCESS]\033[0m $1"; }
warning() { echo -e "\033[1;33m[WARNING]\033[0m $1"; }

# --- File helpers ------------------------------------------------------------

# Clone a git repository unless it is already present.
clone_plugin() {
    local repo_url=$1
    local target_dir=$2

    if [ -d "$target_dir/.git" ]; then
        info "Plugin $(basename "$target_dir") already exists. Skipping clone."
    else
        info "Cloning $(basename "$target_dir")..."
        git clone -q "$repo_url" "$target_dir"
        success "Cloned $(basename "$target_dir")."
    fi
}

# Write stdin to a file only if the content differs, so re-runs report
# accurately. Sets MANAGED_FILE_CHANGED=1 if created/updated, 0 if untouched.
write_managed_file() {
    local dest=$1
    local tmp
    tmp="$(mktemp)"
    cat > "$tmp"
    if cmp -s "$tmp" "$dest" 2>/dev/null; then
        rm -f "$tmp"
        info "$dest is already up to date."
        MANAGED_FILE_CHANGED=0
    else
        mv "$tmp" "$dest"
        chmod 644 "$dest"
        success "Generated $dest."
        MANAGED_FILE_CHANGED=1
    fi
}

# Append $line (preceded by "# $comment") to $dest unless an active,
# uncommented line already matches the extended regex $pattern. Sets
# INCLUDE_LINE_CHANGED=1 if the line was appended, 0 if already present.
ensure_include() {
    local dest=$1 pattern=$2 comment=$3 line=$4

    touch "$dest"
    if grep -qE "$pattern" "$dest"; then
        info "$dest already loads the fast terminal configuration."
        INCLUDE_LINE_CHANGED=0
    else
        info "Adding include line to $dest..."
        printf '\n# %s\n%s\n' "$comment" "$line" >> "$dest"
        success "Appended to $dest."
        INCLUDE_LINE_CHANGED=1
    fi
}

# --- zsh ----------------------------------------------------------------------

configure_zsh() {
    local zsh_dir="$HOME/.zsh"
    local fast_zsh="$zsh_dir/fast_terminal.zsh"

    info "Setting up the fast terminal shell environment in $zsh_dir..."
    mkdir -p "$zsh_dir"

    # fzf binary (history search, file finding, used by fzf-tab)
    if ! command -v fzf &> /dev/null; then
        info "Installing fzf binary..."
        if [ ! -d "$HOME/.fzf" ]; then
            git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
        fi
        "$HOME/.fzf/install" --all --no-bash --no-fish --no-update-rc
        success "Installed fzf."
    else
        info "fzf binary is already installed."
    fi

    info "Installing ZSH plugins and Pure prompt..."
    clone_plugin "https://github.com/Aloxaf/fzf-tab" "$zsh_dir/fzf-tab"
    clone_plugin "https://github.com/zsh-users/zsh-autosuggestions" "$zsh_dir/zsh-autosuggestions"
    clone_plugin "https://github.com/zsh-users/zsh-syntax-highlighting" "$zsh_dir/zsh-syntax-highlighting"
    clone_plugin "https://github.com/sindresorhus/pure" "$zsh_dir/pure"

    write_managed_file "$fast_zsh" << 'EOF'
# Fast terminal configuration from: https://mijndertstuij.nl/posts/life-is-too-short-for-a-slow-terminal/

# Enable extended_glob for compinit cache check
setopt extended_glob

# 1. Pure Prompt (Async prompt)
fpath=(~/.zsh/pure $fpath)

# 2. Caching completions
autoload -Uz compinit
if [[ -n ~/.zcompdump(#qNmh-24) ]]; then
  compinit -C
else
  compinit
fi

# Initialize Pure prompt
autoload -U promptinit; promptinit
prompt pure

# 3. fzf keybindings and completion (git install, else brew/other installs)
if [ -f ~/.fzf.zsh ]; then
  source ~/.fzf.zsh
elif command -v fzf &> /dev/null; then
  source <(fzf --zsh)
fi

# 4. Plugins
# It is recommended to load syntax highlighting last
source ~/.zsh/fzf-tab/fzf-tab.plugin.zsh
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# 5. Lazy-loading nvm
export NVM_DIR="$HOME/.nvm"
nvm() {
  unset -f nvm
  [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh" --no-use
  [ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"
  nvm "$@"
}

# 6. Lazy-loading kubectl
kubectl() {
    command kubectl "$@"
    local ret=$?
    if [[ -z $KUBECTL_COMPLETE ]]; then
        source <(command kubectl completion zsh)
        KUBECTL_COMPLETE=1
    fi
    return $ret
}
EOF

    ensure_include "$HOME/.zshrc" \
        '^[[:space:]]*source[[:space:]]+~/\.zsh/fast_terminal\.zsh' \
        "Load fast terminal configuration" \
        "source ~/.zsh/fast_terminal.zsh"
}

# --- tmux ---------------------------------------------------------------------

# tmux draws its own status bar, borders, and messages, and manages its own
# keybindings and plugins, so it gets a full configuration of its own.
configure_tmux() {
    local tmux_dir="${XDG_CONFIG_HOME:-$HOME/.config}/tmux"
    local fast_conf="$tmux_dir/fast-terminal.conf"
    local tmux_conf="$HOME/.tmux.conf"
    # Prefer an existing XDG-style tmux.conf if that is what the user uses
    if [ ! -f "$tmux_conf" ] && [ -f "$tmux_dir/tmux.conf" ]; then
        tmux_conf="$tmux_dir/tmux.conf"
    fi

    info "Configuring tmux..."
    mkdir -p "$tmux_dir"

    # tpm must exist before the config's `run tpm` line is ever sourced
    clone_plugin "https://github.com/tmux-plugins/tpm" "$HOME/.tmux/plugins/tpm"

    write_managed_file "$fast_conf" << 'EOF'
# Fast terminal tmux configuration (generated by setup_fast_terminal.sh)
# Based on the Dreams of Code tmux setup (github.com/dreamsofcode-io/tmux),
# with the Snazzy / #1b1b1b (Vine Black) theme instead of catppuccin

# True color support so the terminal theme renders correctly inside tmux
set -g default-terminal "tmux-256color"
# Guarded append so re-sourcing this file never accumulates duplicate entries
%if #{==:#{m:*RGB*,#{terminal-overrides}},0}
set -ga terminal-overrides ",*:RGB"
%endif

set -g mouse on

# C-Space as the prefix key
unbind C-b
set -g prefix C-Space
bind C-Space send-prefix

# Vim style pane selection
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# Start windows and panes at 1, not 0
set -g base-index 1
set -g pane-base-index 1
set-window-option -g pane-base-index 1
set-option -g renumber-windows on

# Use Alt-arrow keys without prefix key to switch panes
bind -n M-Left select-pane -L
bind -n M-Right select-pane -R
bind -n M-Up select-pane -U
bind -n M-Down select-pane -D

# Shift arrow to switch windows
bind -n S-Left  previous-window
bind -n S-Right next-window

# Shift Alt vim keys to switch windows
bind -n M-H previous-window
bind -n M-L next-window

# set vi-mode
set-window-option -g mode-keys vi
# keybindings
bind-key -T copy-mode-vi v send-keys -X begin-selection
bind-key -T copy-mode-vi C-v send-keys -X rectangle-toggle
bind-key -T copy-mode-vi y send-keys -X copy-selection-and-cancel

# Open new splits in the current pane's directory
bind '"' split-window -v -c "#{pane_current_path}"
bind % split-window -h -c "#{pane_current_path}"

# Plugins (managed by tpm; installed by this script, or with prefix + I)
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'christoomey/vim-tmux-navigator'
set -g @plugin 'tmux-plugins/tmux-yank'

run '~/.tmux/plugins/tpm/tpm'

# Theme: Snazzy palette on the #1b1b1b (Vine Black) custom background,
# loaded after the plugins so it always wins

# Status bar
set -g status-style "bg=#1b1b1b,fg=#eff0eb"
set -g status-left "#[fg=#5af78e,bold] #S "
set -g status-right "#[fg=#57c7ff] %H:%M "
setw -g window-status-style "fg=#a5a5a9"
setw -g window-status-current-style "fg=#ff6ac1,bold"
setw -g window-status-activity-style "fg=#f3f99d"

# Pane borders
set -g pane-border-style "fg=#34353e"
set -g pane-active-border-style "fg=#57c7ff"

# Messages and command prompt
set -g message-style "bg=#1b1b1b,fg=#f3f99d"
set -g message-command-style "bg=#1b1b1b,fg=#f3f99d"

# Copy mode selection
setw -g mode-style "bg=#3e404e,fg=#eff0eb"
EOF
    local conf_changed=$MANAGED_FILE_CHANGED

    ensure_include "$tmux_conf" \
        '^[[:space:]]*source(-file)?[[:space:]].*fast-terminal\.conf' \
        "Load fast terminal configuration" \
        "source-file $fast_conf"

    # Apply immediately if anything changed and a tmux server is running
    if { [ "$conf_changed" = 1 ] || [ "$INCLUDE_LINE_CHANGED" = 1 ]; } \
        && tmux list-sessions &> /dev/null; then
        tmux source-file "$fast_conf"
        info "Reloaded config in the running tmux server."
    fi

    # Install the tpm-managed plugins (idempotent; same as pressing prefix + I)
    local tpm_output
    if tpm_output="$("$HOME/.tmux/plugins/tpm/bin/install_plugins" 2>&1)"; then
        if echo "$tpm_output" | grep -q "download success"; then
            success "Installed tmux plugins via tpm."
            # Load the freshly installed plugins into a running server
            if tmux list-sessions &> /dev/null; then
                tmux source-file "$fast_conf"
            fi
        else
            info "tmux plugins are already installed."
        fi
    else
        warning "tpm plugin installation failed: $tpm_output"
    fi
}

# --- Terminal emulators -------------------------------------------------------

# The Snazzy palette is downloaded from sindresorhus/iterm2-snazzy at run time,
# with the background overridden to #1b1b1b (Vine Black).
configure_iterm() {
    info "Configuring iTerm2 profile..."
    local dest_dir="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
    local profile_json
    if ! profile_json="$(/usr/bin/python3 -c '
import plistlib
import json
import urllib.request
import sys

url = "https://raw.githubusercontent.com/sindresorhus/iterm2-snazzy/main/Snazzy.itermcolors"
try:
    req = urllib.request.urlopen(url)
    colors = plistlib.loads(req.read())
except Exception as e:
    print(f"Failed to download Snazzy theme: {e}", file=sys.stderr)
    sys.exit(1)

# Set custom background color to #1b1b1b (Vine Black)
colors["Background Color"] = {
    "Alpha Component": 1.0,
    "Red Component": 27/255.0,
    "Green Component": 27/255.0,
    "Blue Component": 27/255.0,
    "Color Space": "sRGB"
}

profile = {
    "Name": "Fast Terminal",
    "Guid": "Fast-Terminal-Profile",
    "Cursor Type": 1,  # Vertical bar
    "Normal Font": "Menlo-Regular 12",
    "Use Separate Colors for Light and Dark Mode": False,
}
# Merge colors into profile
profile.update(colors)

print(json.dumps({"Profiles": [profile]}, indent=2))
')"; then
        warning "Could not build the iTerm2 profile (Snazzy theme download failed); skipping iTerm2 styling."
        return 0
    fi

    mkdir -p "$dest_dir"
    write_managed_file "$dest_dir/FastTerminal.json" <<< "$profile_json"
    local profile_changed=$MANAGED_FILE_CHANGED

    local default_changed=0
    if [ "$(defaults read com.googlecode.iterm2 "Default Bookmark Guid" 2>/dev/null)" = "Fast-Terminal-Profile" ]; then
        info "'Fast Terminal' is already the default iTerm2 profile."
    else
        info "Setting 'Fast Terminal' as the default iTerm2 profile..."
        defaults write com.googlecode.iterm2 "Default Bookmark Guid" "Fast-Terminal-Profile"
        default_changed=1
    fi

    if [ "$profile_changed" = 1 ] || [ "$default_changed" = 1 ]; then
        success "Configured iTerm2 profile 'Fast Terminal' (Snazzy theme, Menlo font, vertical cursor). Completely restart iTerm2 (Cmd+Q) to apply."
    else
        info "iTerm2 is already fully configured; nothing to change."
    fi
}

configure_ghostty() {
    local ghostty_dir="${XDG_CONFIG_HOME:-$HOME/.config}/ghostty"
    local ghostty_conf="$ghostty_dir/config"
    local fast_conf="$ghostty_dir/fast-terminal.conf"

    info "Configuring Ghostty..."
    mkdir -p "$ghostty_dir"

    write_managed_file "$fast_conf" << 'EOF'
# Fast terminal configuration (generated by setup_fast_terminal.sh)
# Snazzy is bundled with Ghostty; explicit colors below override the theme
theme = Snazzy
# Custom background #1b1b1b (Vine Black)
background = 1b1b1b
font-family = Menlo
font-size = 12
cursor-style = bar
EOF
    local conf_changed=$MANAGED_FILE_CHANGED

    ensure_include "$ghostty_conf" \
        '^[[:space:]]*config-file[[:space:]]*=[[:space:]]*"?fast-terminal\.conf' \
        "Load fast terminal configuration" \
        "config-file = fast-terminal.conf"

    if [ "$conf_changed" = 1 ] || [ "$INCLUDE_LINE_CHANGED" = 1 ]; then
        success "Configured Ghostty (Snazzy theme, Menlo font, vertical cursor). Reload its config (Cmd+Shift+,) or restart Ghostty to apply."
    else
        info "Ghostty is already fully configured; nothing to change."
    fi
}

# --- Main ---------------------------------------------------------------------

configure_zsh

if command -v tmux &> /dev/null; then
    configure_tmux
fi

# tmux masks TERM_PROGRAM; the tmux server still has the environment of the
# terminal it was started from, so ask it for the original value
TERMINAL_APP="$TERM_PROGRAM"
if [ -n "$TMUX" ] || [ "$TERMINAL_APP" = "tmux" ]; then
    TERMINAL_APP="$(tmux show-environment -g TERM_PROGRAM 2>/dev/null | cut -d= -f2-)"
fi

case "$TERMINAL_APP" in
    iTerm.app) configure_iterm ;;
    ghostty)   configure_ghostty ;;
    *) info "No supported terminal detected (TERM_PROGRAM='${TERM_PROGRAM:-unset}'); skipped iTerm2/Ghostty styling." ;;
esac
