#!/bin/bash
# Installs scripts, dotfiles, and other conveniences automatically. This script
# must be run from this directory or behavior is undefined.
#
# This script is safe to run multiple times, and successful runs should be
# idempotent.

set -o errexit   # abort on nonzero exitstatus
set -o nounset   # abort on unbound variable
set -o pipefail  # don't hide errors within pipes

# Prints an error (all arguments) to stderr.
error () {
  echo -e "\e[32m$@\e[0m" >&2
}

SCRIPT_PATH="$(dirname "$(realpath "$0")")"
if [[ $SCRIPT_PATH != $(pwd) ]] ; then
  error "Run install.sh from the directory where it is located ($SCRIPT_PATH)."
  exit 1
fi

# Install any tools so we can use them below if needed.
for tool in $(cat tools); do
  echo "Installing $tool..."
  sudo apt-get install "$tool"
done

for tool in $(cat tools_to_update); do
  echo "Updating $tool..."
  sudo apt-get upgrade "$tool"
done

curl -fsSL https://pyenv.run | bash

# Safely installs a dotfile.
#  $1 - Where to register the dotfile (e.g. "~/.bashrc").
#  $2 - The location of the dotfile to use (e.g. 
#       "$SCRIPT_PATH/dotfiles/bashrc").
set_dotfile () {
  if [[ -L $1 ]] ; then
    if [[ $2 == $(realpath "$1") ]] ; then
      echo "$1 already installed correctly."
      return 0
    fi
    echo "Removing previous symbolic link at $1 (which pointed to $2)..."
    rm --force $1
  fi
  echo "Installing $1..."
  ln --symbolic --backup=numbered "$2" "$1"
}
for file in $(ls dotfiles); do
  set_dotfile ~/."$file" "$SCRIPT_PATH/dotfiles/$file"
done
set_dotfile ~/.scripts "$SCRIPT_PATH/scripts"
mkdir -p ~/.config/jj
set_dotfile ~/.config/jj/config.toml "$SCRIPT_PATH/configs/jj.toml"

# Install tmux plugins (tpm + the plugins declared in dotfiles/tmux.conf) and
# wire up a systemd user service so the tmux server auto-starts on boot. This
# lets tmux-continuum restore session layouts and working dirs across reboots.
TPM_DIR="$HOME/.tmux/plugins/tpm"
if [[ ! -d $TPM_DIR ]] ; then
  echo "Cloning tpm (tmux plugin manager)..."
  git clone --depth 1 https://github.com/tmux-plugins/tpm "$TPM_DIR"
fi
# Headless plugin install. install_plugins reads the plugin list from
# tmux.conf and the install path from the tmux server env, so seed the env var
# first (works even if a server is already running without tpm sourced). This
# is idempotent: already-installed plugins are skipped.
tmux start-server \; set-environment -g TMUX_PLUGIN_MANAGER_PATH "$HOME/.tmux/plugins/"
"$TPM_DIR/bin/install_plugins"

# systemd user service so the tmux server starts on boot (needed for
# continuum-restore to fire). Guarded so machines without a systemd user
# instance (e.g. containers) don't abort the install.
mkdir -p ~/.config/systemd/user
set_dotfile ~/.config/systemd/user/tmux.service "$SCRIPT_PATH/configs/tmux.service"
if command -v systemctl >/dev/null && systemctl --user show-environment >/dev/null 2>&1 ; then
  systemctl --user daemon-reload
  systemctl --user enable tmux.service
  # Start the server at boot, not just at login.
  loginctl enable-linger "$USER" || true
else
  echo "No systemd user instance detected; skipping tmux.service enable."
fi

# Install JJ
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
$HOME/.cargo/bin/cargo install --locked --bin jj jj-cli
alias jj="$HOME/.cargo/bin/jj"
source <(jj util completion bash)

# Install pants
curl --proto '=https' --tlsv1.2 -fsSL https://static.pantsbuild.org/setup/get-pants.sh | bash