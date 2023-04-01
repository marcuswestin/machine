TODO:
    [ ] Albert App
    [ ] Rectangle App

Setup new MacOS machine
=======================

### BREW
```bash
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	(echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> /Users/marcuswestin/.zprofile
	eval "$(/opt/homebrew/bin/brew shellenv)"
```

### bin
```bash
    sudo mkdir -p /usr/local/bin
    sudo chown -R $(whoami) /usr/local/bin
```

### git & Mackup
```bash
    git config --global user.name "Marcus Westin"
    git config --global user.email "marcus.westin@gmail.com"
    git config --global core.excludesfile ~/.gitignore
    git config --global push.default simple

	# Create new token and enter when prompted:
	open https://github.com/settings/tokens
    git clone --recurse-submodules https://github.com/marcuswestin/marcuswestin.git ~/code/marcuswestin
```


### APPS
```bash
	brew install spotify notion firefox slack visual-studio-code iterm2
	cd /Applications && open "Dropbox.app" "Notion.app" "Slack.app" "Firefox.app" "Spotify.app" "Visual Studio Code.app" "iTerm.app"
```

- iTerm Settings > General > Window > Native full screen window: Uncheck

### Setup
```bash
	code ~/code/marcuswestin
    # Then open `Setup-New-Machine.md`
```

### Dotfiles etc
```bash
    brew install node
    cd ~/code/marcuswestin/dotfiles && make
    cd ~/code/marcuswestin/git-star && make
```

- Downloads
	(Xcode?)



- MEANWHILE: Settings
    - Dock
        - [ ] Remove ALL items (except Downloads next to Trash)
            - defaults write com.apple.dock persistent-apps -array
        - [ ] Position: Left
        - [ ] Check: Automatically hide and show the Dock
    - "iCloud Drive"
        - iCloud Drive > Turn Off
	- "Trackpad"
        - Tracking Speed: Fastest
        - Click: Light
        - Tap to click: Toggle on
    - "Mouse & Trackpad"
        - Scrolling Speed: Fastest
    - "Trackpad Options"
        - Enable Dragging: Three finger drag
    - "Language preference"
        - Add Swedish
    - "Keyboard layouts"
        - Show Input menu in menu bar > Toggle On
	- "Keyboard sensitivity"
        - Key Repeat: Fast
        - Delay Until Repeat: Short
        - Turn keyboard backlight off after inactivity: 5 seconds
    - "Keyboard Navigation"
        - Keyboard navigation: Toggle on
    - "Customize Modifier keys"
        - Map: Caps Key -> Control
    - "Keyboard Shortcuts"
        - App Shortcuts > "+" > All Applications > Name:"Zoom" > Cmd+Shift+M
        - Spotligt > Show Finder Source: Toggle off
	- "Hot Corner Shortcuts"
		- Top: Desktop, Desktop
		- Bottom: Sleep, Sleep
	- "Require Password"
        - Start Screen Saver when Inactive: Never
        - Turn Display off on Battery when inactive: 10 min
        - Turn Display off on Power Adaptor when inactive: 20 min
		- Require password: 5 Seconds
	- "Expose"
		- Disable Keyboard shortcuts for all (Mission Control, Application windows, Show Desktop)


- [ ] Install dotfiles
    mkdir -p ~/code && cd ~/code && git clone https://github.com/marcuswestin/dotfiles.git
    cd ~/code/dotfiles
    make

- [ ] Install git-star
    mkdir -p ~/code && cd ~/code && git clone https://github.com/marcuswestin/git-star.git
    cd ~/code/git-star
    sudo chown -R $(whoami) /usr/local/bin
    ./install_local.sh

- Create native web apps
    brew install node
    npm install -g nativefier
    cd /tmp
    export NAME='Gmail' && nativefier --name "${NAME}" gmail.com && mv "${NAME}-darwin-arm64/${NAME}.app" /Applications
    export NAME='Aldyn Gcal' && nativefier --name "${NAME}" https://calendar.google.com/a/aldyn.com && mv "${NAME}-darwin-arm64/${NAME}.app" /Applications
    export NAME='Aldyn Gmail' && nativefier --name "${NAME}" https://mail.google.com/a/aldyn.com && mv "${NAME}-darwin-arm64/${NAME}.app" /Applications

- Setup Dropbox





