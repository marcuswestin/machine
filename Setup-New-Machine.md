# New Machine Setup

- TODO:
    - [ ] Albert App
    - [ ] Rectangle App
    - [ ] Xcode?
    - [ ] Setup Dropbox?
    - [ ] Create native web apps?
        ```
        brew install node
        npm install -g nativefier
        cd /tmp
        export NAME='Gmail' && nativefier --name "${NAME}" gmail.com && mv "${NAME}-darwin-arm64/${NAME}.app" /Applications
        export NAME='Aldyn Gcal' && nativefier --name "${NAME}" https://calendar.google.com/a/aldyn.com && mv "${NAME}-darwin-arm64/${NAME}.app" /Applications
        export NAME='Aldyn Gmail' && nativefier --name "${NAME}" https://mail.google.com/a/aldyn.com && mv "${NAME}-darwin-arm64/${NAME}.app" /Applications
	    ```

Setup new MacOS machine
=======================

### XCode

Install xcode from app store

### BREW
```bash
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	(echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> ~/.zprofile
	eval "$(/opt/homebrew/bin/brew shellenv)"
```

### Settings

- Messages
        - Settings > iMessage
            - Enable Messages in iCloud
            - Send read receipts

- System Settings (Use spotlight on these search terms)
    - "Trackpad"
        - Tracking Speed: Fastest
        - Click: Light
        - Tap to click: Toggle on
    - "Trackpad Options"
        - Scrolling Speed: Fastest
    - "Language preference"
        - Add Swedish
        - Input Sources > Edit > + (Add Swedish)
    - "Keyboard layouts"
        - Show Input menu in menu bar > Toggle On
    - "Keyboard sensitivity"
        - Key Repeat: Fast (To the right)
        - Delay Until Repeat: Short (To the right)
        - Turn keyboard backlight off after inactivity: 5 seconds
        - Keyboard navigation: Toggle on
    - "Customize Modifier keys"
        - Map: Caps Key -> Control
    - "Keyboard Shortcuts"
        - App Shortcuts > "+" > All Applications > Name:"Zoom" > Cmd+Ctrl+M
        - Spotligt > Show Finder search window: Toggle off
    - "Hot Corner Shortcuts"
        - Top: Desktop, Desktop
        - Bottom: Sleep, Sleep
    - "Require Password to wake computer"
        - Start Screen Saver when Inactive: Never
        - Turn Display off on Battery when inactive: 10 min
        - Turn Display off on Power Adaptor when inactive: 20 min
	- Require password: 5 Seconds
    - "Expose"
        - Disable Keyboard shortcuts for all (Mission Control, Application windows, Show Desktop)
    - "Desktop & Dock"
	- Remove all items: `defaults write com.apple.dock persistent-apps -array && killall Dock`
	- Position on screen: Left
	- Automatically hide and show the Dock: On
	- Show recent applications in Dock: Off
	- Menu Bar > Automatically hide and show the menu bar > "Never"  
  

### APPS
```bash
	brew install dropbox spotify notion firefox slack visual-studio-code iterm2
	cd /Applications && open "Dropbox.app" "Notion.app" "Slack.app" "Firefox.app" "Spotify.app" "Visual Studio Code.app" "iTerm.app"

    npm install -g nativefier
    cd /tmp
    export NAME='Gmail' && nativefier --name "${NAME}" --honest https://mail.google.com && mv "${NAME}-darwin-arm64/${NAME}.app" /Applications && open /Applications/${NAME}.app
    export NAME='Gcal' && nativefier --name "${NAME}" --honest https://calendar.google.com/ && mv "${NAME}-darwin-arm64/${NAME}.app" /Applications && open /Applications/${NAME}.app
```


### bin
```bash
	# IS THIS NEEDED?
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
    brew install gh && gh auth login
	open https://github.com/settings/tokens
    git clone --recurse-submodules https://github.com/marcuswestin/marcuswestin.git ~/code/marcuswestin
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








