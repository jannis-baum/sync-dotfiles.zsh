function _sdf_dir_diff() {
    # - find all files in dotfiles subrepo
    # - get modified time for these and the corresponding files in $HOME
    # - compare times with >, i.e. 1 if dotfile is newer, 0 if install is newer
    # - return sum of these comparisons
    local files=$(fd --no-ignore --hidden . "$1")
    paste -sd '+' \
        <(paste -d '>' \
            <(xargs stat -f %m 2> /dev/null <<<"$files") \
            <(sed "s|^|$HOME/|" <<<"$files" | xargs stat -f %m 2> /dev/null) \
            | sed -e 's/^.*>$/1/' -e 's/^>.*$/1/' \
            | bc) \
        | bc
}

function sdf() {
    # load config, go to dotfiles_dir and setup ignore
    local dotfiles_actions dotfiles_dir ignore_patterns
    typeset -A dotfiles_actions

    [[ -z "$SDFRC_PATH" ]] && local SDFRC_PATH="$HOME/.sdfrc"
    test -f "$SDFRC_PATH" && source "$SDFRC_PATH"
    [[ -z "$dotfiles_dir" ]] && dotfiles_dir="$DOTFILES_DIR"

    if [[ -z "$dotfiles_dir" ]]; then
        echo 'Please set your dotfiles directory either in your .sdfrc or as the environment variable $DOTFILES_DIR'
        return
    fi

    dotfiles_dir=$(realpath $dotfiles_dir)
    local prev_dir=$(pwd)
    cd $dotfiles_dir

    if [[ "$1" == '-u' || "$1" == '--upgrade' ]]; then
        echo "\e[1mupgrading repo\e[0m"
        git -C $dotfiles_dir pull
        echo "\e[1mupgrading submodules\e[0m"
        git -C $dotfiles_dir submodule foreach git pull
    fi

    ignore_patterns+=('.git/*' '.gitignore' '.gitmodules')

    # make it possible for read to get answer from stdin (e.g. `yes`)
    [[ -t 0 ]] && readq_flags=('-q') || readq_flags=('-q' '-u' '0' '-E')

    # prompt to install of $1 to $2, i.a. run custom command
    function _sdf_install_dotfile() {
        printf "install $1? (y/*) "
        if read $readq_flags; then
            [[ -d $2 ]] && rm -rf $2 # directories aren't overwritten -> delete first
            mkdir -p "$(dirname $2)"
            cp -r "$1" "$2"
            printf '\n'
            for rgx cmd in ${(kv)dotfiles_actions}; do
                [[ "$1" =~ "$rgx" ]] && echo "  \e[2m\e[3m-> $cmd\e[0m" && ${(z)cmd}
            done
        else printf '\n'
        fi
    }

    function _sdf_is_ignored() {
        for pattern in ${(@)ignore_patterns}; do
            [[ "$1" == ${~pattern} ]] && return 0
        done
        return 1
    }

    # find submodules
    if [[ -f '.gitmodules' ]]; then
        local -a submodules
        for submodule in $(rg --no-line-number --replace '' '^\s*path ?= ?' '.gitmodules'); do
            _sdf_is_ignored "$submodule" || submodules+="$submodule"
        done
        ignore_patterns+=("${(@)submodules}")
    fi

    # install submodules if different from submodule in $HOME
    for sm in $submodules; do
        if [[ $(_sdf_dir_diff "$sm") != "0" || ! -d "$HOME/$sm" ]]; then
            _sdf_install_dotfile "$sm" "$HOME/$sm"
        fi
    done

    # find dotfiles
    local fd_opts=('--strip-cwd-prefix' '--type' 'f' '--type' 'l' '--hidden' '--no-ignore')
    fd_opts+=("${(z)$(printf '%s\n' ${ignore_patterns} | sed 's/^/--exclude /' | tr '\n' ' ')}")
    local dotfiles=("${(f)$(fd $fd_opts)}")

    # install files if different from file in $HOME
    for df in $dotfiles; do
        if ! cmp "$df" "$HOME/$df" &> /dev/null; then
            _sdf_install_dotfile "$df" "$HOME/$df"
        fi
    done

    cd $prev_dir
}
