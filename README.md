# sync-dotfiles.zsh

sync-dotfiles or `sdf` is a package manager for your dotfiles.

## Features

- Manage your dotfiles repo with all files exactly where they should be in your
  home directory
- Automatically detect changes in these files and be prompted to install them to
  the corresponding location in your home directory
- Configure actions to run when installing files such as automatically sourcing
  your `.zshrc` so all your configs are always loaded and up to date
- Treat git submodules as single dotfiles so they are synced/installed as a
  whole - this is useful for dependencies such as vim or zsh plugins

## Install

Simply source `sdf.zsh` in your `.zshrc`. This works best if you keep this
repository as a submodule in your dotfiles repo! You can see how I do this
myself in [my dotfiles](https://github.com/jannis-baum/dotfiles).

## Configuration

The minimal configuration is to set the environment variable `DOTFILES_DIR` to
let `sdf` know where to find your dotfiles repo.

For all additional configuration or if you don't want this environment variable,
you can create an `sdfrc` file. This file should be located at `~/.sdfrc`, but
you can set `SDFRC_PATH` if you prefer to keep it somewhere else.

Using the `sdfrc`, you can set `dotfiles_dir` instead to set your repository's
location.

See [my `sdfrc`](https://github.com/jannis-baum/dotfiles/blob/main/.sdfrc) for
an example of what this file can look like.

### Ignoring patterns from being synced

In your `sdfrc` you can set the zsh array `ignore_patterns` to ignore any
matching paths when looking for what to sync. To ignore any paths with `foo` or
`bar`, add the following to your `sdfrc`

```zsh
ignore_patterns=('*foo*' '*bar*')
```

### Syncing actions
