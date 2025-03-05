# transform stdin paths from source to destination
# stdin: paths
# args: source destination
function _sdf_destination() {
    sed "s|^$1|$2|"
}

# check if directory is different from source to destination
# args: dir source destination
function _sdf_dir_diff() {
    # - find all files in dotfiles subrepo
    # - get modified time for these and the corresponding files in $HOME
    # - compare times with >, i.e. 1 if dotfile is newer, 0 if install is newer
    # - return sum of these comparisons
    local files=$(fd --no-ignore --hidden . "$1")
    paste -sd '+' \
        <(paste -d '>' \
            <(xargs stat -f %m 2> /dev/null <<<"$files") \
            <(_sdf_destination "$2" "$3" <<<"$files" | xargs stat -f %m 2> /dev/null) \
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
usage: sdf [-h] [-y] [-A] [-u]

options:
  -h, --help            show this help message and exit
  -y, --yes             install all changed dotfiles without prompting
  -A, --no-actions      don't run configured install actions
  -u, --upgrade         pull dotfiles repo and all submodules before syncing
EOF
        return
    fi


    # load config, cd dotfiles_dir and setup ignore ----------------------------
    local actions dotfiles_dir ignore_patterns mapping
    typeset -A actions mapping

    [[ -z "$SDFRC_PATH" ]] && local SDFRC_PATH="${XDG_CONFIG_HOME:-$HOME/.config}/sdfrc"
    test -f "$SDFRC_PATH" && source "$SDFRC_PATH"
    [[ -z "$dotfiles_dir" ]] && dotfiles_dir="$DOTFILES_DIR"

    if [[ -z "$dotfiles_dir" ]]; then
        echo 'Please set your dotfiles directory either in your sdfrc or as the environment variable $DOTFILES_DIR'
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
    # ignored helper
    function _sdf_is_ignored() {
        for pattern in ${(@)ignore_patterns}; do
            [[ "$1" == ${~pattern} ]] && return 0
        done
        return 1
    }


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
            for rgx cmd in ${(kv)actions}; do
                [[ "$1" =~ "$rgx" ]] && echo "  \e[2m\e[3m-> $cmd\e[0m" && eval "$cmd"
            done
        else printf '\n'
        fi
    }

    # find submodules ----------------------------------------------------------
    if [[ -f '.gitmodules' ]]; then
        local -a submodules
        for submodule in $(rg --no-line-number --replace '' '^\s*path ?= ?' '.gitmodules'); do
            _sdf_is_ignored "$submodule" || submodules+="$submodule"
        done
    fi

    # install dotfiles according to mapping ------------------------------------
    for source destination in ${(kv)mapping}; do
        if ! test -d "$source"; then
            echo "source directory $source does not exist"
            continue
        fi

        local ignores=("${(@)ignore_patterns}")

        # install submodules
        for sm in $submodules; do
            # skip if not in current mapping.source
            [[ $sm == "$source"* ]] || continue
            # install submodule if necessary
            local sm_dest="$(_sdf_destination "$source" "$destination" <<<"$sm")"
            if [[ $(_sdf_dir_diff "$sm" "$source" "$destination") != "0" || ! -d "$sm_dest" ]]; then
                _sdf_install_dotfile "$sm" "$sm_dest"
            fi
            # track for to ignore in search for dotfiles
            ignores+="$(_sdf_destination "$source/" "" <<<"$sm")"
        done

        # install dotfiles
        local fd_opts=('--type' 'f' '--type' 'l' '--hidden' '--no-ignore')
        fd_opts+=("${(z)$(printf '%s\n' ${ignores} | sed 's/^/--exclude /' | tr '\n' ' ')}")
        local dotfiles=("${(f)$(fd $fd_opts . "$source")}")
        # install files if different from file in $HOME
        for df in $dotfiles; do
            local df_dest="$(_sdf_destination "$source" "$destination" <<<"$df")"
            if ! cmp "$df" "$df_dest" &> /dev/null; then
                _sdf_install_dotfile "$df" "$df_dest"
            fi
        done
    done

    cd $prev_dir
}
