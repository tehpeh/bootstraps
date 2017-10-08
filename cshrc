set path = ($home/bin $path)
setenv QMAKE /usr/local/bin/qmake
source $HOME/.aliases.csh
eval `rbenvWrap init -`
setenv NVM_DIR $HOME/.nvm
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
