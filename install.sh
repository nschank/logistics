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
for tool in "$(cat tools)"; do
  echo "Installing $tool..."
  sudo apt-get install "$tool"
done

for tool in "$(cat tools_to_upgrade)"; do
  echo "Updating $tool..."
  sudo apt-get upgrade "$tool"
done

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

set_dotfile ~/.bash_aliases "$SCRIPT_PATH/dotfiles/bash_aliases"
set_dotfile ~/.bash_prompt "$SCRIPT_PATH/dotfiles/bash_prompt"
set_dotfile ~/.bashrc "$SCRIPT_PATH/dotfiles/bashrc"
set_dotfile ~/.git_prompt.sh "$SCRIPT_PATH/dotfiles/git_prompt.sh"
set_dotfile ~/.tmux.conf "$SCRIPT_PATH/dotfiles/tmux.conf"
set_dotfile ~/.vimrc "$SCRIPT_PATH/dotfiles/vimrc"
set_dotfile ~/.scripts "$SCRIPT_PATH/scripts"