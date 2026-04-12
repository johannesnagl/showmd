# Homebrew Cask for showmd

## Setup (one-time)

Create a tap repository on GitHub:

```bash
gh repo create johannesnagl/homebrew-tap --public --description "Homebrew tap for showmd"
git clone git@github.com:johannesnagl/homebrew-tap.git
mkdir -p homebrew-tap/Casks
cp homebrew/showmd.rb homebrew-tap/Casks/showmd.rb
cd homebrew-tap && git add . && git commit -m "Add showmd cask" && git push
```

## Usage

```bash
brew tap johannesnagl/tap
brew install --cask showmd
```

## Updating after a release

After each release, update the `version` and `sha256` in the cask formula:

```bash
# SHA-256 is printed by the release script and attached to the GitHub release
# Update Casks/showmd.rb in the homebrew-tap repo with the new values
```

The GitHub Actions release workflow outputs the SHA-256 — use it to update the cask.
