{
  config,
  inputs,
  lib,
  pkgs,
  user,
  ...
}:

let
  brew = config.nix-homebrew;
  prefix = config.homebrew.prefix;
  owner = lib.escapeShellArg "${brew.user}:${brew.group}";
  brewAsOwner = ''
    /usr/bin/sudo --user=${lib.escapeShellArg brew.user} --set-home \
      env HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_FROM_API=1 HOMEBREW_NO_AUTOREMOVE=1 \
      ${lib.escapeShellArg "${prefix}/bin/brew"}
  '';
  # A fully qualified package name has the form owner/tap/package.
  tapPackages =
    packages:
    builtins.filter (name: builtins.match "[^/]+/[^/]+/[^/]+" name != null) (
      map (package: package.name) packages
    );
in
{
  nix-homebrew = {
    enable = true;
    autoMigrate = true;
    enableRosetta = false;
    taps = {
      "homebrew/homebrew-cask" = inputs.homebrew-cask;
      "machine/homebrew-local" = pkgs.runCommandLocal "homebrew-local" { } ''
        mkdir -p "$out"
        cp -R ${../homebrew/local}/. "$out"
      '';
      # nix-homebrew keys are on-disk directory names, including homebrew-.
      "anomalyco/homebrew-tap" = inputs.homebrew-anomalyco-tap;
      "mobile-dev-inc/homebrew-tap" = inputs.homebrew-mobile-dev-inc-tap;
      "nikitabobko/homebrew-tap" = inputs.homebrew-nikitabobko-tap;
      "steipete/homebrew-tap" = inputs.homebrew-steipete-tap;
    };
    user = user;

    # Applied as the Homebrew owner before Bundle loads any package definitions.
    # Trust only declared items, including local casks, never entire taps.
    trust = {
      formulae = tapPackages config.homebrew.brews;
      casks = tapPackages config.homebrew.casks;
    };
  };

  homebrew = {
    enable = true;
    user = brew.user;

    # Keep Homebrew's tap/API metadata fresh enough for cask installs.
    # This does not upgrade installed packages; `onActivation.upgrade` controls
    # that separately below.
    global.autoUpdate = true;

    onActivation = {
      autoUpdate = true;
      cleanup = "none";
      extraEnv = {
        HOMEBREW_NO_ANALYTICS = "1";
        HOMEBREW_NO_ENV_HINTS = "1";
        # Homebrew 5.1.7 can crash while converting cask API JSON
        # dependencies (`undefined method 'to_sym' for nil`) during
        # `brew fetch`. Use tapped cask definitions during activation.
        HOMEBREW_NO_INSTALL_FROM_API = "1";
      };
      upgrade = false;
    };
  };

  # The pinned nix-homebrew initializes directories only once, leaves the prefix
  # root-owned, and rsyncs mutable tap copies as root on every activation. Set
  # ownership after that setup and before Bundle. Do not recursively chown the
  # prefix: its Homebrew code and package symlinks can point into the Nix store.
  system.activationScripts.setup-homebrew.text = lib.mkAfter ''
    echo "setting Homebrew directory ownership for ${brew.user}..."
    for dir in "" bin etc include lib sbin share opt var Cellar Caskroom Frameworks \
      etc/bash_completion.d lib/cmake lib/cps lib/pkgconfig \
      share/aclocal share/doc share/info share/locale share/man \
      share/man/man1 share/man/man2 share/man/man3 share/man/man4 \
      share/man/man5 share/man/man6 share/man/man7 share/man/man8 \
      share/cps share/fish share/fish/vendor_completions.d \
      share/zsh share/zsh/site-functions share/pwsh share/pwsh/completions \
      var/log var/homebrew var/homebrew/linked var/homebrew/locks \
      Library Library/Taps completions; do
      # 0755: owner can write; group/others can read and traverse. In particular,
      # zsh's completion directories must not be group- or world-writable.
      /usr/bin/install -d -o ${lib.escapeShellArg brew.user} -g ${lib.escapeShellArg brew.group} \
        -m 0755 "${prefix}/$dir"
    done
    # Migrated installations also have nested link destinations owned by the old
    # account (CMake/fish in particular). Own real directories only; never follow
    # package symlinks or recursively change installed file permissions.
    for dir in bin etc include lib sbin share opt var Cellar Caskroom Frameworks completions; do
      /usr/bin/find -P "${prefix}/$dir" -type d \
        -exec /usr/sbin/chown ${owner} {} + \
        -exec /bin/chmod u+rwx {} +
    done
    ${lib.optionalString brew.mutableTaps ''
      # Include Homebrew's own mutable core checkout. Wrong ownership makes Git
      # hide its existing origin as "dubious ownership"; no safe.directory bypass
      # or replacement checkout is needed. Store-backed legacy taps stay untouched.
      /usr/bin/find -P "${prefix}/Library/Taps" \
        \( -type d -o -type f \) \
        -exec /usr/sbin/chown ${owner} {} + \
        -exec /bin/chmod u+rwX {} +
    ''}

    # compaudit checks the owner of completion file targets, not just their
    # directories or symlinks. Migrated files may still belong to the old user,
    # including completions inside Docker.app. Resolve only completion entries;
    # immutable Nix-store targets must never have ownership or modes changed.
    while IFS= read -r -d "" completion; do
      target="$(${pkgs.coreutils}/bin/realpath -e "$completion")"
      case "$target" in
        /nix/store/*) continue ;;
      esac
      /usr/sbin/chown ${owner} "$target"
      /bin/chmod go-w "$target"
    done < <(/usr/bin/find -P "${prefix}/share/zsh" \( -type f -o -type l \) -print0)

    # Explicit package replacements only, before Bundle resolves conflicts.
    # Fetch first; uninstall without --zap so Claude's settings/auth survive.
    installed_casks="$(${lib.trim brewAsOwner} list --cask)"
    while IFS= read -r cask; do
      if [ "$cask" = claude-code ]; then
        ${lib.trim brewAsOwner} fetch --cask claude-code@latest
        ${lib.trim brewAsOwner} uninstall --cask claude-code
      fi
      if [ "$cask" = codex ]; then
        codex_version="$(${lib.trim brewAsOwner} info --json=v2 --cask codex \
          | ${lib.getExe pkgs.jq} -r '.casks[0].installed')"
        # macOS rejects the old 0.130.0 CLI's signature after an OS upgrade.
        # Replace that release with the pinned cask, preserving ~/.codex.
        # Other installed versions keep the usual no-upgrade apply behavior.
        if [ "$codex_version" = 0.130.0 ]; then
          ${lib.trim brewAsOwner} upgrade --cask codex
        fi
      fi
    done <<< "$installed_casks"
    installed_formulae="$(${lib.trim brewAsOwner} list --formula)"
    while IFS= read -r formula; do
      if [ "$formula" = codexbar ]; then
        # The app cask supplies the same CLI; the accidentally installed formula
        # otherwise occupies /opt/homebrew/bin/codexbar and blocks the cask.
        ${lib.trim brewAsOwner} fetch --cask steipete/tap/codexbar
        ${lib.trim brewAsOwner} uninstall --formula codexbar
      fi
    done <<< "$installed_formulae"
  '';

  system.activationScripts.homebrew.text = lib.mkAfter ''
    # Bundle repairs links for direct entries, but not already-installed
    # dependencies left unlinked by an earlier interrupted/permission-failed run.
    # Only consider dependencies of our declared formulae; keep keg-only JDK 17
    # isolated and never overwrite another package's links.
    declared_formulae=(${lib.escapeShellArgs (map (package: package.name) config.homebrew.brews)})
    dependencies="$(${lib.trim brewAsOwner} deps --formula --union --installed "''${declared_formulae[@]}")"
    dependency_names=()
    while IFS= read -r dependency; do
      [ -z "$dependency" ] || dependency_names+=("$dependency")
    done <<< "$dependencies"
    if [ "''${#dependency_names[@]}" -gt 0 ]; then
      dependency_info="$(${lib.trim brewAsOwner} info --json=v2 --formula "''${dependency_names[@]}")"
      unlinked="$(printf '%s' "$dependency_info" | ${lib.getExe pkgs.jq} -r '
        .formulae[] | select(.keg_only == false and (.installed | length) > 0)
        | select(.linked_keg == null or .linked_keg == "") | .full_name
      ')"
      while IFS= read -r formula; do
        [ -z "$formula" ] || ${lib.trim brewAsOwner} link "$formula"
      done <<< "$unlinked"
    fi

    # Register the declared JDK with /usr/libexec/java_home. Do not force-link
    # keg-only Java 17 over Maestro's newer openjdk dependency or edit shell PATH.
    /usr/bin/install -d -o root -g wheel -m 0755 /Library/Java/JavaVirtualMachines
    # -T treats the destination as the exact link name, even if another machine
    # has a manually installed directory there; it must never nest a link inside it.
    ${pkgs.coreutils}/bin/ln -sfnT "${prefix}/opt/openjdk@17/libexec/openjdk.jdk" \
      /Library/Java/JavaVirtualMachines/openjdk-17.jdk
  '';

  # nix-homebrew sets HOMEBREW_REPOSITORY to a marker under Library/, so brew's
  # own shell completions never land at $HOMEBREW_PREFIX/completions where the
  # share/zsh/site-functions/_brew symlink points. Relink from the brew package
  # after each activation so zsh compinit does not hit a dangling symlink.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    brew_lib="$(readlink /opt/homebrew/Library/Homebrew 2>/dev/null || true)"
    if [ -n "$brew_lib" ]; then
      brew_completions="$(cd "$(dirname "$brew_lib")/../completions" && pwd)"
      if [ -d "$brew_completions" ]; then
        echo "linking Homebrew shell completions from $brew_completions"
        mkdir -p /opt/homebrew/completions
        for shell in bash fish zsh; do
          if [ -d "$brew_completions/$shell" ]; then
            ln -sfn "$brew_completions/$shell" "/opt/homebrew/completions/$shell"
          fi
        done
      fi
    fi
  '';
}
