# dotfiles

macOS setup as code — [nix-darwin](https://github.com/nix-darwin/nix-darwin) for
system config, [home-manager](https://github.com/nix-community/home-manager) for
user dotfiles, and Homebrew (declaratively) for GUI apps.

One command applies everything:

```bash
./darwin.sh switch
```

## Layout

```
flake.nix                 inputs + one entry per machine
flake.lock                pinned versions of everything
darwin/configuration.nix  system config: packages, casks, macOS settings
darwin/home.nix           user config: which dotfiles get deployed
darwin.sh                 the only command you need
new-mac.setup             one-time bootstrap for a fresh Mac
.zshrc                    deployed to ~/.zshrc by home-manager
```

## Daily use

```bash
./darwin.sh build     # validate the config, don't apply it (no sudo)
./darwin.sh switch    # build, then apply
./darwin.sh update    # bump flake inputs, verify it still builds
./darwin.sh rollback  # list generations to roll back to
```

Typical loop:

```bash
vim darwin/configuration.nix
./darwin.sh switch
git commit -am "add dbeaver"
```

`darwin.sh` stages files automatically before building. That matters: **a flake
only sees git-tracked files**, so an unstaged new file is invisible to Nix and
fails with a confusing "no such file" error.

## Adding software

Pick by type:

| What | Where | Example |
|---|---|---|
| GUI app | `homebrew.casks` | `"visual-studio-code"` |
| App Store exclusive | `homebrew.masApps` | `"Amphetamine" = 937984704;` |
| CLI tool | `environment.systemPackages` | `pkgs.ripgrep` |
| Nix itself | nowhere — Determinate owns it | `sudo determinate-nixd upgrade` |

All of these live in `darwin/configuration.nix`.

GUI apps go through Homebrew because cask installs integrate with macOS
properly (code signing, `/Applications`, self-updates). CLI tools go through
Nix because they're then pinned by `flake.lock`.

Finding names:

```bash
nix search nixpkgs ripgrep
brew search --cask dbeaver
```

Don't list the same tool in both.

### App Store apps

Some apps (Amphetamine, Notability) have no Homebrew cask and are Mac App Store
exclusives. Those go in `masApps`, keyed by App Store ID:

```bash
curl -s "https://itunes.apple.com/search?term=amphetamine&entity=macSoftware" \
  | python3 -m json.tool | grep -E 'trackId|trackName'
```

Requirements: the `mas` brew (already in the list), and being **signed in to the
App Store**. `mas` can't authenticate for you, and a paid app must be purchased
once through the GUI before it can install it.

### Unfree packages

`nixpkgs.config.allowUnfree = true` is set, because `claude-code` and most
proprietary tooling ship under non-free licences. Narrow it to a per-package
predicate if you'd rather opt in explicitly — see the comment in
`darwin/configuration.nix`.

## macOS system settings

`darwin/configuration.nix` has a commented-out `system.defaults` block — dock
behaviour, key repeat rate, Finder options. Uncomment what you want instead of
clicking through System Settings on every new machine.

Full list of options: <https://nix-darwin.github.io/nix-darwin/manual/>

## Adding a new Mac

1. Run the bootstrap (installs Xcode CLT, Determinate Nix, Homebrew — the three
   things the flake can't install itself):

   ```bash
   git clone https://github.com/shubham-tomar/dotfiles.git ~/projects/dotfiles
   ~/projects/dotfiles/new-mac.setup
   ```

2. Add the machine to `flake.nix`:

   ```nix
   "Shubhams-MacBook-Air" = mkDarwin {
     hostname = "Shubhams-MacBook-Air";
     # system = "x86_64-darwin";   # Intel
     # username = "someone";       # non-default user
   };
   ```

   The name must match `scutil --get LocalHostName`. To apply before editing the
   flake, reuse an existing host with `DARWIN_HOST=<name> ./darwin.sh switch`.

3. `./darwin.sh switch`

## Things worth knowing

**`~/.zshrc` becomes a read-only symlink** into `/nix/store`. Installers that
append to it (`echo ... >> ~/.zshrc`) will fail — put those lines in this
repo's `.zshrc` and re-switch. Your pre-existing file is preserved as
`~/.zshrc.hm-bak` on first activation.

**Homebrew never uninstalls anything** by default here —
`onActivation.cleanup = "none"`. To make the cask/brew lists authoritative
(i.e. removing an entry uninstalls it), set it to `"uninstall"`. Check
`brew leaves` and `brew list --cask` against the lists first.

**`claude-code` is installed but shadowed.** There's already a self-updating
native install at `~/.local/bin/claude`, and `.zshrc` force-prepends that
directory to `PATH`, so it wins over the Nix one. Check with `which -a claude`.
To actually use the Nix build, remove the native install and drop that PATH
line:

```bash
rm -rf ~/.local/bin/claude ~/.local/share/claude
```

Trade-off: the Nix build is pinned by `flake.lock` and only moves when you run
`./darwin.sh update`, whereas the native install updates itself.

**Nix is managed by Determinate, not nix-darwin.** That's what
`nix.enable = false` means. Consequences: Nix settings go in
`/etc/nix/nix.custom.conf` (not `nix.settings.*` in this repo), upgrades are
`sudo determinate-nixd upgrade`, and `nix.linux-builder` is unavailable.

**Rolling back.** Every switch creates a generation:

```bash
darwin-rebuild --list-generations
sudo darwin-rebuild switch --switch-generation 42
```

Config mistakes are also just git history — `git revert` and re-switch.
