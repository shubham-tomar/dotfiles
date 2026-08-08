{
  description = "Shubham's nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, home-manager }:
  let
    # Adding a new Mac is one line in darwinConfigurations below — all hosts
    # share the same modules.
    mkDarwin =
      { hostname
      , username ? "tomar"
      , system ? "aarch64-darwin"
      }:
      nix-darwin.lib.darwinSystem {
        specialArgs = { inherit self hostname username system; };
        modules = [
          ./darwin/configuration.nix
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            # Existing dotfiles are moved aside as <name>.hm-bak rather than
            # causing activation to abort.
            home-manager.backupFileExtension = "hm-bak";
            home-manager.extraSpecialArgs = { inherit username; };
            home-manager.users.${username} = import ./darwin/home.nix;
          }
        ];
      };
  in
  {
    # Validate without activating:  ./darwin.sh build
    # Apply:                        ./darwin.sh switch
    darwinConfigurations = {
      "Shubhams-MacBook-Pro-2" = mkDarwin {
        hostname = "Shubhams-MacBook-Pro-2";
      };

      # A second machine would be:
      #   "Shubhams-MacBook-Air" = mkDarwin {
      #     hostname = "Shubhams-MacBook-Air";
      #   };
      #
      # Intel Mac:  system = "x86_64-darwin";
      # Other user: username = "someone";
    };
  };
}
