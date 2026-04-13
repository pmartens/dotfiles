# Awesome Dotfiles

A curated list of dotfiles resources. Inspired by the [awesome][3] list thing. Note that some articles or tools may look
old or old-fashioned, but this usually means they're battle-tested and mature (like dotfiles themselves). Feel free to
propose new articles, projects or tools!

## Instruction

The `bootstrap.sh` script automates how your dotfiles are linked into your `$HOME` using [GNU stow](https://www.gnu.org/software/stow/).

The script:

- Ensures stow is installed (via Homebrew if needed).
- Ensures `~/.config` exists.
- Calls stow per selected package: `stow --dir="${SCRIPT_DIR}" --target="${HOME}" <package>`


## Usage

Run the script from the repository root:

```bash
./bootstrap.sh [options]
```

All apps + dotfiles + zsh‑extras:
```bash
./bootstrap.sh --all
```

Only dotfiles (stow)
```bash
./bootstrap.sh --dotfiles
```

Only selected dotfiles
```bash
# See DEFAULT_PACKAGES in boostrap.conf
./bootstrap.sh --dotfiles-packages zsh,git,nvim
```

All apps (Homebrew + scripts)
```bash
./bootstrap.sh --apps
```

All selected apps / plugins
```bash
./bootstrap.sh --apps-packages zsh,ohmyzsh,zsh-syntax-highlighting,zsh-autosuggestions
```

All zsh‑snippets per app (interactief, adds snippets to `.zshrc`)
```bash
./bootstrap.sh --zsh-extend
```

All zsh‑aliasblocks in `.zshrc`
```bash
./bootstrap.sh --zsh-aliases
```
