{
  pkgs,
  username,
  lib,
  ...
}:
# macOS system configuration
# Options: https://nix-darwin.github.io/nix-darwin/manual/index.html
# `defaults` reference: https://github.com/yannbertrand/macos-defaults
{
  # Required for user-scoped settings (dock, finder, homebrew, ...)
  system.primaryUser = username;

  system = {
    stateVersion = 5;

    defaults = {
      # show 24 hour clock
      menuExtraClock.Show24Hour = true;

      # customize dock
      dock = {
        autohide = true;
        show-recents = false; # disable recent apps

        # customize Hot Corners
        #wvous-tl-corner = 2;  # top-left - Mission Control
        #wvous-tr-corner = 13;  # top-right - Lock Screen
        #wvous-bl-corner = 3;  # bottom-left - Application Windows
        wvous-br-corner = 4; # bottom-right - Desktop

        persistent-apps = [
          "/Applications/Zen.app"
          "/Applications/Slack.app"
          "/Applications/Notion.app"
          "/Users/${username}/Applications/Home Manager Apps/VSCodium.app"
          "/System/Applications/System Settings.app"
        ];
        persistent-others = [
          "/Users/${username}/Downloads/"
        ];
      };

      # customize finder
      finder = {
        _FXShowPosixPathInTitle = true; # show full path in finder title
        AppleShowAllExtensions = true; # show all file extensions
        FXEnableExtensionChangeWarning = false; # disable warning when changing file extension
        FXPreferredViewStyle = "Nlsv"; # set default view style to list view
        NewWindowTarget = "Home"; # set default folder to home
        QuitMenuItem = true; # enable quit menu item
        ShowPathbar = true; # show path bar
        ShowStatusBar = true; # show status bar
      };

      # customize trackpad
      trackpad = {
        Clicking = false; # enable tap to click
        TrackpadRightClick = true; # enable two finger right click
        TrackpadThreeFingerDrag = true; # enable three finger drag
      };

      # customize settings that not supported by nix-darwin directly
      # Incomplete list of macOS `defaults` commands :
      #   https://github.com/yannbertrand/macos-defaults
      NSGlobalDomain = {
        # `defaults read NSGlobalDomain "xxx"`
        "com.apple.swipescrolldirection" = true; # enable natural scrolling(default to true)
        "com.apple.sound.beep.feedback" = 0; # disable beep sound when pressing volume up/down key
        AppleInterfaceStyle = "Dark"; # dark mode
        AppleKeyboardUIMode = 3; # Mode 3 enables full keyboard control.
        ApplePressAndHoldEnabled = true; # enable press and hold

        # If you press and hold certain keyboard keys when in a text area, the key’s character begins to repeat.
        # This is very useful for vim users, they use `hjkl` to move cursor.
        # sets how long it takes before it starts repeating.
        InitialKeyRepeat = 15; # normal minimum is 15 (225 ms), maximum is 120 (1800 ms)
        # sets how fast it repeats once it starts.
        KeyRepeat = 3; # normal minimum is 2 (30 ms), maximum is 120 (1800 ms)

        NSAutomaticCapitalizationEnabled = false; # disable auto capitalization
        NSAutomaticDashSubstitutionEnabled = false; # disable auto dash substitution
        NSAutomaticPeriodSubstitutionEnabled = false; # disable auto period substitution
        NSAutomaticQuoteSubstitutionEnabled = false; # disable auto quote substitution
        NSAutomaticSpellingCorrectionEnabled = false; # disable auto spelling correction
        NSNavPanelExpandedStateForSaveMode = true; # expand save panel by default
        NSNavPanelExpandedStateForSaveMode2 = true;
      };

      # Customize settings that not supported by nix-darwin directly
      # see the source code of this project to get more undocumented options:
      #    https://github.com/rgcr/m-cli
      #
      # All custom entries can be found by running `defaults read` command.
      # or `defaults read xxx` to read a specific domain.
      CustomUserPreferences = {
        ".GlobalPreferences" = {
          # automatically switch to a new space when switching to the application
          AppleSpacesSwitchOnActivate = true;
        };
        NSGlobalDomain = {
          # Add a context menu item for showing the Web Inspector in web views
          WebKitDeveloperExtras = true;
        };
        "com.apple.finder" = {
          ShowExternalHardDrivesOnDesktop = true;
          ShowHardDrivesOnDesktop = true;
          ShowMountedServersOnDesktop = true;
          ShowRemovableMediaOnDesktop = true;
          _FXSortFoldersFirst = true;
          # When performing a search, search the current folder by default
          FXDefaultSearchScope = "SCcf";
        };
        "com.apple.desktopservices" = {
          # Avoid creating .DS_Store files on network or USB volumes
          DSDontWriteNetworkStores = true;
          DSDontWriteUSBStores = true;
        };
        "com.apple.spaces" = {
          "spans-displays" = 0; # Display have seperate spaces
        };
        "com.apple.WindowManager" = {
          EnableStandardClickToShowDesktop = 0; # Click wallpaper to reveal desktop
          StandardHideDesktopIcons = 0; # Show items on desktop
          HideDesktop = 0; # Do not hide items on desktop & stage manager
          StageManagerHideWidgets = 0;
          StandardHideWidgets = 0;
        };
        "com.apple.screensaver" = {
          # Require password immediately after sleep or screen saver begins
          askForPassword = 1;
          askForPasswordDelay = 0;
        };
        "com.apple.screencapture" = {
          location = "~/Desktop";
          type = "png";
        };
        "com.apple.AdLib" = {
          allowApplePersonalizedAdvertising = false;
        };
        # Prevent Photos from opening automatically when devices are plugged in
        "com.apple.ImageCapture".disableHotPlug = true;
      };

      loginwindow = {
        GuestEnabled = false; # disable guest user
        LoginwindowText = "Unauthorized access will be sanctioned!";
      };
    };

    # keyboard settings is not very useful on macOS
    # the most important thing is to remap option key to alt key globally,
    # but it's not supported by macOS yet.
    keyboard = {
      enableKeyMapping = true; # enable key mapping so that we can use `option` as `control`

      # NOTE: do NOT support remap capslock to both control and escape at the same time
      remapCapsLockToControl = false; # remap caps lock to control, useful for emac users
      remapCapsLockToEscape = true; # remap caps lock to escape, useful for vim users

      # swap left command and left alt
      # so it matches common keyboard layout: `ctrl | command | alt`
      #
      # disabled, caused only problems!
      swapLeftCommandAndLeftAlt = false;
    };
  };

  # nix-darwin's `dock.persistent-others` only takes paths, and rewrites each
  # tile with default view options. Patch the Downloads stack afterwards so it
  # sorts by date added (newest first) and displays as a folder rather than a
  # stack.
  #
  # Three things here are load-bearing; each was a separate failed attempt:
  #
  # 1. Activation runs as root, so this hops into ${username}'s GUI session
  #    with `launchctl asuser ... sudo --user=`, matching how nix-darwin's own
  #    dock module invokes `defaults`. A bare `sudo -u` runs outside the user's
  #    Mach bootstrap namespace and reaches a different `cfprefsd` than the
  #    logged-in session, whose daemon then overwrites the file.
  #
  # 2. It reads and writes via `defaults export`/`import` rather than editing
  #    the plist directly. cfprefsd holds this domain in memory, so a direct
  #    file edit (e.g. PlistBuddy) gets clobbered when the daemon next flushes.
  #    Round-tripping the domain also preserves each tile's `book` bookmark
  #    blob, which the Dock needs to resolve the folder.
  #
  # 3. It retries. nix-darwin kills the Dock earlier in activation, and the
  #    relaunching Dock writes its own in-memory prefs back out, landing on top
  #    of a write made while it was still starting. The loop below re-reads and
  #    re-applies until the value sticks.
  system.activationScripts.postActivation.text = ''
    /bin/launchctl asuser "$(/usr/bin/id -u -- ${username})" \
      /usr/bin/sudo --user=${username} -- /usr/bin/python3 - <<'PYTHON'
    import plistlib, subprocess, time

    def defaults(*args, **kw):
        return subprocess.run(
            ["/usr/bin/defaults", *args], capture_output=True, check=True, **kw
        )

    def downloads_tile(domain):
        for tile in domain.get("persistent-others", []):
            data = tile.get("tile-data", {})
            url = data.get("file-data", {}).get("_CFURLString", "")
            if url.rstrip("/").endswith("/Downloads"):
                return data
        return None

    def read_state():
        domain = plistlib.loads(defaults("export", "com.apple.dock", "-").stdout)
        return domain, downloads_tile(domain)

    # nix-darwin kills the Dock earlier in activation, and the relaunching Dock
    # writes its own in-memory prefs back out -- which lands on top of anything
    # written while it is still starting up. Wait for it to settle, then write
    # and confirm, retrying if it gets clobbered anyway.
    WANTED = (2, 1)  # arrangement 2 = Date Added (newest first), displayas 1 = Folder

    for attempt in range(1, 6):
        time.sleep(2)

        domain, data = read_state()
        if data is None:
            print("dock-downloads: no Downloads tile in persistent-others")
            break

        if (data.get("arrangement"), data.get("displayas")) == WANTED:
            print(f"dock-downloads: correct after {attempt} attempt(s)")
            break

        data["arrangement"], data["displayas"] = WANTED
        defaults("import", "com.apple.dock", "-", input=plistlib.dumps(domain))
    else:
        print("dock-downloads: gave up after 5 attempts")

    # Restart once at the end so the Dock picks up the final on-disk state.
    subprocess.run(["/usr/bin/killall", "Dock"], capture_output=True)
    PYTHON
  '';

  # Add ability to used TouchID for sudo authentication (renamed in 25.05)
  security.pam.services.sudo_local.touchIdAuth = true;

  # Create /etc/zshrc that loads the nix-darwin environment.
  # this is required if you want to use darwin's default shell - zsh
  programs.zsh.enable = true;
  environment.shells = [
    pkgs.zsh
  ];

  # Set your time zone.
  time.timeZone = "Europe/Zurich";

  # Fonts
  fonts = {
    packages = with pkgs; [
      # icon fonts
      material-design-icons
      font-awesome

      # nerdfonts (new syntax as of nixpkgs 24.05+)
      nerd-fonts.fira-code
      nerd-fonts.jetbrains-mono
    ];
  };
}
