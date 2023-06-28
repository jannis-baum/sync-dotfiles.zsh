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
    # parse args ---------------------------------------------------------------
    local arg_help
    for arg in "$@"; do
        case "$arg" in
            "-h" | "--help") arg_help=1; continue;;
            "-y" | "--yes") local arg_yes=1; continue;;
            "-A" | "--no-actions") local arg_no_actions=1; continue;;
            "-u" | "--upgrade") local arg_upgrade=1; continue;;
        esac
        [[ -z "$arg" ]] && continue
        if [[ "$arg" == "-"* ]]; then
            echo "Illegal option: $arg"
            arg_help=1
            break
        fi
    done

    if [[ -n "$arg_help" ]]; then
      cat <<EOF
usage: sdf [-h] [-y] [-A]

options:
  -h, --help            show this help message and exit
  -y, --yes             install all changed dotfiles without prompting
  -A, --no-actions      don't run configured install actions
EOF
    fi


    # load config, cd dotfiles_dir and setup ignore ----------------------------
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

    if [[ -n "$arg_upgrade" ]]; then
        echo "\e[1mupgrading repo\e[0m"
        git pull
        echo "\e[1mupgrading submodules\e[0m"
        git submodule foreach git pull
    fi

    ignore_patterns+=('.git/*' '.gitignore' '.gitmodules')

    # prompt installation ------------------------------------------------------
    [[ -t 0 ]] && local readq_flags=('-q') || local readq_flags=('-q' '-u' '0' '-E')
    function _sdf_prompt_install() {
        if [[ -n "$arg_yes" ]]; then
            printf "installing $1"
            return 0
        fi
        printf "install $1? (y/*) "
        read $readq_flags
    }

    # install & run actions ----------------------------------------------------
    function _sdf_install_dotfile() {
        if _sdf_prompt_install $1; then
            [[ -d $2 ]] && rm -rf $2 # directories aren't overwritten -> delete first
            mkdir -p "$(dirname $2)"
            cp -r "$1" "$2"
            printf '\n'
            [[ -n "$arg_no_actions" ]] && return
            for rgx cmd in ${(kv)dotfiles_actions}; do
                [[ "$1" =~ "$rgx" ]] && echo "  \e[2m\e[3m-> $cmd\e[0m" && ${(z)cmd}
            done
        else printf '\n'
        fi
    }

    # submodules ---------------------------------------------------------------
    # ignored helper
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

    # dotfiles -----------------------------------------------------------------
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
