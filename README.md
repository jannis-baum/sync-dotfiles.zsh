# sync-dotfiles.zsh

sync-dotfiles or `sdf` is a package manager for your dotfiles.

![`sdf`-showcase](../assets/sdf-showcase.gif)

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
repository as a submodule in your dotfiles repo so `sdf` can manage itself! You
can see how I do this myself in [my
dotfiles](https://github.com/jannis-baum/dotfiles/blob/main/.zsh/.zshrc).

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

To always keep your tools up to date with the most recent changes to their
config, `sdf` allows you to define commands to run whenever it syncs a file
matching a pattern. This is configured with the associative zsh array
`dotfiles_actions` in your `sdfrc`. This array's keys are regex patterns and its
values are commands to run whenever a file matching the pattern key is synced.

To source your `zshrc` whenever anything from the `.zsh` directory in your
dotfiles is synced, you can add the following to your `sdfrc`.

```zsh
dotfiles_actions=( \
    ['^\.zsh/']="source $HOME/.zsh/.zshrc" \
)
```

You can find more examples for actions in [my
`sdfrc`](https://github.com/jannis-baum/dotfiles/blob/main/.sdfrc).
