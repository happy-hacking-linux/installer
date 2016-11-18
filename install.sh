install () {
    pacman -S base-devel \
           curl \
           wget \
           git \
           tmux \
           zsh \
           checkinstall \
           firefox \
           xmonad \
           xmobar \
           feh \
           scrot \
           moc \
           newsbeuter \
           dmenu \
           rxvt-unicode \
           emacs \
           vim

    installNode
    installZSH
    installFonts
    installSpacemacs
    installAwesomeVim
}

installNode () {
    curl https://raw.github.com/creationix/nvm/master/install.sh | bash
	  source ~/.nvm/nvm.sh
    nvm install 7.1.0
	  nvm use 7.1.0
	  nvm alias default 0.10
}

installZSH () {
	  curl -L https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh | sh
	  echo "source ~/dotfiles/.zshrc \nsource ~/dotfiles/.nvm \nsource ~/localbin/bashmarks/bashmarks.sh\nsource ~/.nvm/nvm.sh" > ~/.zshrc
	  chsh -s $(which zsh)
}

installFonts () {
    pacman -S ttf-inconsolata ttf-symbola ttf-ancient-fonts ttf-bitstream-vera
    installMonacoFont
    installEmojiFont
}

installMonacoFont () {
    ../install-font http://jorrel.googlepages.com/Monaco_Linux.ttf
}

installEmojiFont () {
    wget https://github.com/eosrei/emojione-color-font/releases/download/v1.3/EmojiOneColor-SVGinOT-Linux-1.3.tar.gz -O /tmp/emojione-font.tar.gz
    cd /tmp
    tar zxf emojione-font.tar.gz
    cd Emoji* && ./install.sh
}

installSpacemacs () {
    git clone https://github.com/syl20bnr/spacemacs ~/.emacs.d
}

installAwesomeVim () {
    git clone git://github.com/amix/vimrc.git ~/.vim_runtime
    sh ~/.vim_runtime/install_awesome_vimrc.sh
}
