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
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Mac apps

brew cask install \
  alfred \
  caffeine \
  dash \
  firefox \
  google-chrome \
  hyperswitch \
  omnidisksweeper \
  rowanj-gitx \
  sizeup \
  sketch \
  sketch-toolbox \
  slack \
  sublime-text \
  vagrant \
  vienna \
  virtualbox \
  vlc \
  menumeters \

# Install command line apps

brew install \
  ack \
  direnv \
  docker \
  docker-machine \
  docker-compose \
  fish \
  go \
  git \
  imagemagick #--disable-openmp --build-from-source \
  node \
  nvim \
  pass \
  pass-otp \
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
