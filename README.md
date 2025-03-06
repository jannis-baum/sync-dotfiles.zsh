# sync-dotfiles.zsh

sync-dotfiles or `sdf` is a package manager for your dotfiles that takes care of
your own configuration files as well as all of your plugins/dependencies and
helps you automatically reload configs.

![`sdf`-showcase](../assets/sdf-showcase.gif)

## Features

- Manage your dotfiles repo with a mirrored directory structure according to
  your preferred mapping
- Automatically detect changes in these files and be prompted to install them to
  the corresponding location in your home directory
- Configure actions to run when installing files such as automatically sourcing
  your `.zshrc` so all your configs are always loaded and up to date
- Treat git submodules as single dotfiles so they are synced/installed as a
  whole - this is useful for dependencies such as vim or zsh plugins
- Run `sdf` with `--upgrade` or `-u` to pull your dotfiles repo and all
  submodules before syncing

## Install

`sdf` uses `git`, [`fd`](https://github.com/sharkdp/fd) and [ripgrep
(`rg`)](https://github.com/BurntSushi/ripgrep), so make sure you have these
tools installed!

Then, simply source `sdf.zsh` in your `.zshrc`. This works best if you keep this
repository as a submodule in your dotfiles repo so `sdf` can manage itself! You
can see how I do this myself in [my
dotfiles](https://github.com/jannis-baum/dotfiles/blob/main/.zsh/.zshrc).

## Configuration

To use `sdf`, you need an `sdfrc` (zsh script) file. This file will be sourced
by `sdf`, and should be located at `$XDG_CONFIG_HOME/sdfrc` (or
`~/.config/sdfrc` if `$XDG_CONFIG_HOME` is not set). You can also set
`$SDFRC_PATH` if you prefer to keep it somewhere else.

A minimal `sdfrc` should set the variable `dotfiles_dir` to the directory of
your dotfiles repository, and the associative array `mapping` that defines where
to install what parts of the repository. The `mapping` could look as follows

```zsh
mapping=( \
    [home]=~ \
    [config]=~/.config \
)
```

If you keep a `home/` and a `config/` directory in the root of your dotfiles
repository, whose contents are installed to `~/` and `~/.config` respectively.
Make sure you use absolute paths don't add any `/` to the end of them.

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
`actions` in your `sdfrc`. This array's keys are regex patterns and its values
are commands to run whenever a file matching the pattern key is synced.

To source your `zshrc` whenever anything from the `.zsh` directory in your
dotfiles is synced, you can add the following to your `sdfrc`.

```zsh
actions=( \
    ['^\.zsh/']="source $HOME/.zsh/.zshrc" \
)
```

You can find more examples for actions in [my
`sdfrc`](https://github.com/jannis-baum/dotfiles/blob/main/config/sdfrc).

## Running `sdf`

`sdf` has the following options.

- `-y`, `--yes`: install all changed dotfiles without prompting
- `-A`, `--no-actions`: don't run configured install actions
- `-u`, `--upgrade`: pull dotfiles repo and all submodules before syncing
- `-h`, `--help`: show the help message and exit
