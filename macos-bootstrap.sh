#!/bin/bash
set -e

# Download: curl -LO https://bit.ly/macos-bootstrap

# Symlink dotfiles
# TODO: path below should use path of this file?
# TODO: remove . from source files and prefix to target file
# TODO: add sublime packages/user files
# TODO: make a git repo for all this, including dot/config files
FILES=./macosx/.*
for f in $FILES; do
  if [[ $f =~ .DS_Store$ ]]; then
    continue
  fi
  if [[ -f $f ]]; then
    echo "Linking $f to ~"
    ln -sf $f ~
  fi
done

source ~/.bash_profile

# Copy .ssh/config
mkdir -p ~/.ssh
chmod 700 ~/.ssh
cp -n dotfiles/macosx/.ssh/config ~/.ssh/config

# Install Xcode Command Line Tools
xcode-select --install

# Install Homebrew
ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
# Add Homebrew Cask
brew tap caskroom/cask

# Install Mac apps

brew cask install \
  alfred \
  colloquy \
  firefox \
  glimmerblocker \
  google-chrome \
  google-cloud-sdk \
  omnidisksweeper \
  rowanj-gitx \
  sizeup \
  sketch \
  sketch-toolbox \
  slack \
  toggldesktop \
  spotify \
  sublime-text \
  vagrant \
  vienna \
  virtualbox \
  vlc \
  yujitach-menumeters \

# Install command line apps

brew install \
  ack \
  ansible \
  bash-completion \
  docker \
  docker-machine \
  docker-compose \
  docker-swarm \
  go \
  git \
  imagemagick #--disable-openmp --build-from-source \
  node \
  proctools \
  qt@5.5 \
  rbenv \
  ruby-build \
  tmux \
  wget \

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

# Setup dnsmasq for .dev
printf "\naddress=/dev/127.0.0.1" >> /usr/local/etc/dnsmasq.conf
sudo mkdir -p /etc/resolver
sudo printf "nameserver 127.0.0.1" > /etc/resolver/dev

# Link Sublime command line
ln -s "/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl" /usr/local/bin/subl

echo "========================================"
echo "           Install via App Store        "
echo "========================================"
echo "1Password"
echo "Airmail"
echo "Numbers, Pages, Keynote"
echo "Caffeine"
echo "Dash"
echo "Wifi Explorer"
echo "Wifi Signal"
echo "The Unarchiver"
echo "Twitter"
echo "Pixelmator"
echo "ForkLift"
echo "Mac OS X Server"
