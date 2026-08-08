{ ... }:

{
  # Compatibility marker — see `home-manager` release notes before bumping.
  home.stateVersion = "25.05";

  # Deploy the repo's .zshrc as ~/.zshrc. Edit ../.zshrc in this repo, run
  # `./darwin.sh switch`, and the symlink is repointed at the new store path.
  #
  # Note: ~/.zshrc becomes a read-only symlink into /nix/store. Tools that
  # append to it (installers doing `echo ... >> ~/.zshrc`) will fail — put
  # those lines in the repo copy instead.
  home.file.".zshrc".source = ../.zshrc;
}
