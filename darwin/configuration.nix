{ pkgs, self, hostname, username, system, ... }:

{
  #### Identity ###############################################################

  networking.hostName = hostname;
  networking.localHostName = hostname;

  # System activation runs as root; user-scoped options (homebrew, etc.)
  # apply to this user instead.
  system.primaryUser = username;

  # home-manager needs to know where the user's home lives.
  users.users.${username} = {
    name = username;
    home = "/Users/${username}";
  };

  #### CLI tooling (nix) ######################################################

  # Command-line tools belong here — versioned via flake.lock and reproducible.
  # GUI apps belong in `homebrew.casks` below.
  # Search names with: nix search nixpkgs <name>
  environment.systemPackages = [
    pkgs.vim
    pkgs.git
    # NOTE: shadowed by the self-updating native install at ~/.local/bin/claude
    # (which .zshrc force-prepends to PATH). See README before relying on this.
    pkgs.claude-code
  ];

  #### GUI apps + brew formulae (homebrew) ####################################

  # This module drives an already-installed Homebrew (at /opt/homebrew) via
  # `brew bundle` — it does not install Homebrew itself. See new-mac.setup.
  homebrew = {
    enable = true;

    # Top-level formulae only (cf. `brew leaves --installed-on-request`);
    # dependencies are resolved by brew and don't belong here.
    # `git` intentionally lives in environment.systemPackages instead.
    brews = [
      "bun"
      "coreutils"
      "eza"
      "gh"
      "go"
      "mas" # drives masApps below
      "node"
      "uv"
    ];

    # GUI apps. Search names with: brew search --cask <name>
    casks = [
      "github"
      "visual-studio-code"
      "dbeaver-community"
      "microsoft-onenote"
      "brave-browser"
      "docker-desktop"
      "steam"
      "warp"
    ];

    # Mac App Store exclusives — no Homebrew cask exists for these. Requires
    # the `mas` brew above AND being signed in to the App Store; `mas` cannot
    # authenticate for you, and a first-time purchase must be done in the GUI.
    # IDs from: https://itunes.apple.com/search?term=<app>&entity=macSoftware
    masApps = {
      "Amphetamine" = 937984704;
      "Notability" = 360593530;
    };

    onActivation = {
      autoUpdate = false;
      upgrade = false;
      # "none" = never uninstall anything not listed above. Once you trust the
      # lists, switch to "uninstall" (removes unlisted formulae/casks) or "zap"
      # (also removes their leftover config). Both are destructive — check
      # `brew leaves` and `brew list --cask` against the lists first.
      cleanup = "none";
    };
  };

  #### macOS settings #########################################################

  # Declarative System Settings. Uncomment what you want; each takes effect on
  # the next `./darwin.sh switch`.
  #
  # system.defaults = {
  #   dock.autohide = true;
  #   dock.orientation = "left";
  #   dock.show-recents = false;
  #   finder.AppleShowAllExtensions = true;
  #   finder.FXPreferredViewStyle = "clmv";
  #   NSGlobalDomain.InitialKeyRepeat = 15;
  #   NSGlobalDomain.KeyRepeat = 2;
  #   NSGlobalDomain.AppleInterfaceStyle = "Dark";
  # };

  #### Nix ####################################################################

  # Determinate Nix manages the Nix installation itself, so nix-darwin must not
  # try to manage it. Nix settings go in /etc/nix/nix.custom.conf.
  nix.enable = false;

  #### Bookkeeping ############################################################

  # Set Git commit hash for darwin-version.
  system.configurationRevision = self.rev or self.dirtyRev or null;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 6;

  nixpkgs.hostPlatform = system;

  # claude-code (and most GUI/proprietary tooling) ships under a non-free
  # licence. Narrow this to a predicate if you'd rather opt in per package:
  #   nixpkgs.config.allowUnfreePredicate = pkg:
  #     builtins.elem (pkgs.lib.getName pkg) [ "claude-code" ];
  nixpkgs.config.allowUnfree = true;
}
