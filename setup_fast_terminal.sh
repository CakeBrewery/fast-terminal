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

# Config file sources live in config/ next to this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

    write_managed_file "$fast_zsh" < "$SCRIPT_DIR/config/fast_terminal.zsh"

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

    # vim half of vim-tmux-navigator: tmux forwards C-h/j/k/l to a focused vim,
    # and vim needs this plugin to move across its own splits and tmux panes
    if command -v vim &> /dev/null; then
        clone_plugin "https://github.com/christoomey/vim-tmux-navigator" \
            "$HOME/.vim/pack/fast-terminal/start/vim-tmux-navigator"
    fi

    write_managed_file "$fast_conf" < "$SCRIPT_DIR/config/tmux.conf"
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
    if ! profile_json="$(/usr/bin/python3 "$SCRIPT_DIR/config/iterm_profile.py")"; then
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

    write_managed_file "$fast_conf" < "$SCRIPT_DIR/config/ghostty.conf"
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
