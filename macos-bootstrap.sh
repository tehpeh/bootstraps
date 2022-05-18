#!/bin/bash
set -e

# Download: curl -LO https://bit.ly/macos-bootstrap

# Symlink dotfiles
# TODO: redo/rethink this section, can pull these files from backup
# IDEA: remove . from source files and prefix to target file
# IDEA: add sublime packages/user files
# IDEA: make a separate git repo or folder for all this, including dot/config files
# FILES=./macosx/.*
# for f in $FILES; do
#   if [[ $f =~ .DS_Store$ ]]; then
#     continue
#   fi
#   if [[ -f $f ]]; then
#     echo "Linking $f to ~"
#     ln -sf $f ~
#   fi
# done

# Copy .ssh/config
# mkdir -p ~/.ssh
# chmod 700 ~/.ssh
# cp -n dotfiles/macosx/.ssh/config ~/.ssh/config

# Install Xcode Command Line Tools
xcode-select --install

# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Mac apps
brew install --cask \
  alfred \
  arq \
  caffeine \
  dash \
  firefox \
  google-chrome \
  iterm2 \
  keybase \
  menumeters \
  omnidisksweeper \
  plexamp \
  resilio-sync \
  sizeup \
  slack \
  sublime-text \
  virtualbox \
  vlc \
  zerotier-one \

# Optional: install old/unused/broken apps
# brew install --cask \
#   1password \
#   hyperswitch \
#   sketch \
#   sketch-toolbox \
#   rowanj-gitx \
#   vagrant \
#   vienna \

# Install command line apps
brew install \
  ack \
  direnv \
  fish \
  gnupg \
  go \
  git \
  htop \
  imagemagick \
  node \
  nvim \
  pass \
  pass-otp \
  pinentry-mac \
  proctools \
  rbenv \
  ruby-build \
  tig \
  tmux \
  wget \
  yarn \

# NOTE: imagemagick may need flags: --disable-openmp --build-from-source

# Install Heroku CLI
brew tap heroku/brew
brew install heroku

# Install browserpass native client
brew tap amar1729/formulae
brew install browserpass
PREFIX='/usr/local/opt/browserpass' make hosts-chrome-user -f '/usr/local/opt/browserpass/lib/browserpass/Makefile'
PREFIX='/usr/local/opt/browserpass' make hosts-firefox-user -f '/usr/local/opt/browserpass/lib/browserpass/Makefile'

# Optional: install old/unused command line apps
# brew install \
#   docker \
#   docker-machine \
#   docker-compose \
#   qt@5.5 \

echo "========================================"
echo "             setup required!            "
echo "========================================"
brew install \
  elasticsearch \
  dnsmasq \
  memcached \
  nginx \
  postgres \
  redis \

# Setup dnsmasq for .localhost domains
printf "\naddress=/.localhost/127.0.0.1" >> /usr/local/etc/dnsmasq.conf
sudo mkdir -p /etc/resolver
sudo printf "nameserver 127.0.0.1" > /etc/resolver/localhost

# Fixes issue with nginx not working properly under root
chmod o+x /usr/local/var

# Link Sublime command line
ln -s "/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl" /usr/local/bin/subl

echo "========================================"
echo "           Install via App Store        "
echo "========================================"
echo "1Password"
echo "Airmail"
echo "Numbers, Pages, Keynote"
echo "Wifi Explorer"
echo "Wifi Signal"
echo "The Unarchiver"
echo "Pixelmator"
echo "ForkLift"

echo "Download 1password 7 from https://app-updates.agilebits.com/download/OPM7"
echo "Restore from Arq backup before launching apps"
echo "Check placeholders exist in selective sync folders before launching Resilio Sync, otherwise files will be deleted"
