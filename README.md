# Machine setup

SETUP NEW MAC
=============

SETUP NEW MAC
=============

Last Updated for M1X MBP 11/11/2021

- Start long downloads:
    - [ ] Xcode (App Store)
    - [ ] Git (run "git" in terminal)

- Install Programs
    - [ ] VSCode: https://code.visualstudio.com
    - [ ] iTerm 3: https://iterm2.com
    - [ ] Brew (from https://brew.sh):
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> /Users/marcuswestin/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    - [ ] Firefox: https://www.mozilla.org/en-US/firefox/new/
    - [ ] Slack: https://slack.com/downloads/mac
    - [ ] Notion: https://www.notion.so/desktop
    - [ ] Spotify: https://www.spotify.com/us/download/mac/
    - [ ] Dropbox: https://www.dropbox.com/install
    

- Create native web apps
    brew install node
    npm install -g nativefier
    cd /tmp
    export NAME='Gmail' && nativefier --name "${NAME}" gmail.com && mv "${NAME}-darwin-arm64/${NAME}.app" /Applications
    export NAME='Aldyn Gcal' && nativefier --name "${NAME}" https://calendar.google.com/a/aldyn.com && mv "${NAME}-darwin-arm64/${NAME}.app" /Applications
    export NAME='Aldyn Gmail' && nativefier --name "${NAME}" https://mail.google.com/a/aldyn.com && mv "${NAME}-darwin-arm64/${NAME}.app" /Applications

- Messages:
    Open Messages app
    then Settings > iMessage tab > check Enable Messages in iCloud

- Settings: iCloud
	- [ ] iCloud > iCloud Drive > Options… >
  	  	- [ ] Desktop & Documents Folders > Turn Off
	  	- [ ] iCloud Mail > Turn Off

- Settings: Trackpad
	- [ ] Tap to Click ON
	- [ ] Click LIGHT
	- [ ] Tracking speed FAST
	- [ ] More Gestures, OFF: Mission Control & Launchpad

- Settings: Keyboard
	- [ ] Key Repeat: FAST, SHORT
	- [ ] Modifier Keys button -> Caps: ^Control
	- [ ] tab: Shortcuts > CHECK “Use keyboard navigation to move focus between controls"
	- [ ] tab: Input Sources -> Add Swedish
	- [ ] tab: Input Sources -> Add "Cmd+Option+Space" for "Select Next source in Input menu" (should warn of conflict)
	- [ ] tab: Spotlight -> Uncheck "Show Finder search window" (the conflicting keyboard shortcut)


- Settings: Exposé shortcuts
	- [ ] Disable Keyboard shortcuts for ctrl+up/down
    - [ ] Hot corners: TL: Desktop, TR: Desktop, BR: Quick notes, BL: Sleep

- Settings: Security settings
	- [ ] Require password > [5 seconds] after sleep

- Settings: Dock & Menu Bar
	- [ ] Remove ALL items (except Downloads next to Trash)
    - [ ] Position: Left
    - [ ] Check: Automatically hide and show the Dock

- App fixes:
	- [ ] iTerm: Fix full screen mode: Preferences > General > Window > "Native full screen window" > Uncheck
	- [ ] VSCode: Install code command: cmd+shift+p > “shell command”
	- [ ] Fakespot: https://www.fakespot.com
	
- Code installs:
	- [ ] Github SSH keys:
		mkdir -p ~/.ssh && cd ~/.ssh
		# (no password, just: enter, enter, enter)
		ssh-keygen -t rsa -C "marcus.westin@gmail.com"
		ssh-add id_rsa

	- [ ] Save github token
		- open https://github.com/settings/tokens
		- click “generate new token”
		- description, e.g: “Marcus Westin MBP M1 April 2021”
		- check "repo"
		- click “Generate token” and use as it once:
			mkdir -p ~/code && cd ~/code
			git clone https://github.com/marcuswestin/docs.git
			# username: marcuswestin
			# password: token from github

	- [ ] Install dotfiles
		mkdir -p ~/code && cd ~/code && git clone https://github.com/marcuswestin/dotfiles.git
		cd ~/code/dotfiles
		make

	- [ ] Install git-star
		mkdir -p ~/code && cd ~/code && git clone https://github.com/marcuswestin/git-star.git
		cd ~/code/git-star
        sudo chown -R $(whoami) /usr/local/bin
		./install_local.sh
