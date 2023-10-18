New Machine Setup
=================

# XCode

Install xcode from app store

# Brew

```bash
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	(echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> ~/.zprofile
	eval "$(/opt/homebrew/bin/brew shellenv)"
```

# Settings

- Messages
        - Settings > iMessage
            - Enable Messages in iCloud
            - Send read receipts

- iTerm
    - Settings > General > Window >
      - Uncheck "Native full screen window"

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
    - "Night Shift"
        - Schedule: Sunset to Sunrise
        - Color temperature: Warmest
    - "Stage Manager"
      - Stage Manager: Toggle On
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


# Install apps

```bash
	brew install dropbox spotify notion firefox slack visual-studio-code iterm2
	cd /Applications
    open "Dropbox.app" "Notion.app" "Slack.app" "Firefox.app" "Spotify.app" "Visual Studio Code.app" "iTerm.app"
```

# Create WebApps

- Once on macOS Sonomona:
    - Create webapps for:
        - gmail
        - google calendar


# Git

```bash
    brew install git git-credential-manager
    git config --global credential.helper manager
    git config --global color.ui true
```


# Install commands & my own libs
```bash
    brew install node just
    git clone --recurse-submodules https://github.com/marcuswestin/marcuswestin.git ~/code/marcuswestin
    cd ~/code/marcuswestin/dotfiles && make
    cd ~/code/marcuswestin/git-star && make
```

# TODOs?

- Add these to my machine setup?
  - Albert App
  - Rectangle App

--------

# Old. Are these needed?

```
    # IS THIS NEEDED?
    git config --global user.name "Marcus Westin"
    git config --global user.email "marcus.westin@gmail.com"
    git config --global core.excludesfile ~/.gitignore
    git config --global push.default simple
```
