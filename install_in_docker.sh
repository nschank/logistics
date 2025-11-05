#!/bin/bash
# Installs scripts, dotfiles, and other conveniences automatically. This script
# must be run from this directory or behavior is undefined.
#
# This script is intended to be run inside a Docker container to set up a simple
# environment, and must run non-interactively.

set -x
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

apt-get update

# Install any tools so we can use them below if needed.
for tool in $(cat tools); do
  echo "Installing $tool..."
  apt-get install -y --no-install-recommends "$tool"
done

for tool in $(cat tools_to_update); do
  echo "Updating $tool..."
  apt-get upgrade -y "$tool"
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
for file in $(ls dotfiles); do
  set_dotfile ~/."$file" "$SCRIPT_PATH/dotfiles/$file"
done
set_dotfile ~/.scripts "$SCRIPT_PATH/scripts"

# Install JJ
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
$HOME/.cargo/bin/cargo install --locked --bin jj jj-cli
$HOME/.cargo/bin/jj config set --user user.name "Nick Schank"
$HOME/.cargo/bin/jj config set --user user.email "nicolas.schank@google.com"
source <($HOME/.cargo/bin/jj util completion bash)