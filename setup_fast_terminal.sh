#!/usr/bin/env bash

# Exit on error
set -e

ZSH_DIR="$HOME/.zsh"
FAST_TERMINAL_ZSH="$ZSH_DIR/fast_terminal.zsh"
ZSHRC="$HOME/.zshrc"

# Print colored output
info() { echo -e "\033[1;34m[INFO]\033[0m $1"; }
success() { echo -e "\033[1;32m[SUCCESS]\033[0m $1"; }
warning() { echo -e "\033[1;33m[WARNING]\033[0m $1"; }

info "Setting up the fast terminal environment in $ZSH_DIR..."

# 1. Create the base directory
mkdir -p "$ZSH_DIR"

# Helper function to clone or update a git repository
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

# 2. Install fzf binary if missing
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

# 3. Clone plugins and prompt
info "Installing ZSH plugins and Pure prompt..."
clone_plugin "https://github.com/Aloxaf/fzf-tab" "$ZSH_DIR/fzf-tab"
clone_plugin "https://github.com/zsh-users/zsh-autosuggestions" "$ZSH_DIR/zsh-autosuggestions"
clone_plugin "https://github.com/zsh-users/zsh-syntax-highlighting" "$ZSH_DIR/zsh-syntax-highlighting"
clone_plugin "https://github.com/sindresorhus/pure" "$ZSH_DIR/pure"

# 4. Create the self-contained ZSH configuration file
info "Generating $FAST_TERMINAL_ZSH..."

cat << 'EOF' > "$FAST_TERMINAL_ZSH"
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

# 3. fzf binary configuration
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# 4. Plugins
# It is recommended to load syntax highlighting last
source ~/.zsh/fzf-tab/fzf-tab.plugin.zsh
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# 4. Lazy-loading nvm
export NVM_DIR="$HOME/.nvm"
nvm() {
  unset -f nvm
  [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh" --no-use
  [ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"
  nvm "$@"
}

# 5. Lazy-loading kubectl
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

success "Generated $FAST_TERMINAL_ZSH."

# 4. Source the configuration in ~/.zshrc
info "Checking $ZSHRC..."

touch "$ZSHRC"

if grep -q "source ~/.zsh/fast_terminal.zsh" "$ZSHRC"; then
    info "The fast terminal configuration is already sourced in $ZSHRC."
else
    info "Adding source directive to $ZSHRC..."
    echo "" >> "$ZSHRC"
    echo "# Load fast terminal configuration" >> "$ZSHRC"
    echo "source ~/.zsh/fast_terminal.zsh" >> "$ZSHRC"
    success "Appended to $ZSHRC."
fi

# 5. Configure iTerm2
info "Configuring iTerm2 profile..."
/usr/bin/python3 -c '
import plistlib
import json
import urllib.request
import os
import sys

url = "https://raw.githubusercontent.com/sindresorhus/iterm2-snazzy/main/Snazzy.itermcolors"
try:
    req = urllib.request.urlopen(url)
    colors = plistlib.loads(req.read())
except Exception as e:
    print(f"\033[1;33m[WARNING]\033[0m Failed to download Snazzy theme: {e}")
    sys.exit(0)

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

dynamic_profile = {
    "Profiles": [profile]
}

dest_dir = os.path.expanduser("~/Library/Application Support/iTerm2/DynamicProfiles")
os.makedirs(dest_dir, exist_ok=True)
dest_file = os.path.join(dest_dir, "FastTerminal.json")

with open(dest_file, "w") as f:
    json.dump(dynamic_profile, f, indent=2)
'
success "Created iTerm2 profile '\''Fast Terminal'\'' with Snazzy theme, Menlo font, and vertical cursor."

# 6. Make Fast Terminal the default profile
info "Setting '\''Fast Terminal'\'' as the default iTerm2 profile..."
defaults write com.googlecode.iterm2 "Default Bookmark Guid" "Fast-Terminal-Profile"

success "Fast terminal setup is complete! Please completely Restart iTerm2 (Cmd+Q) to ensure the default profile change applies."
