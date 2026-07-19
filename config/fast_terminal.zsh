# Fast terminal configuration from: https://mijndertstuij.nl/posts/life-is-too-short-for-a-slow-terminal/
# (installed by setup_fast_terminal.sh; edit config/fast_terminal.zsh in the repo, not this copy)

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
