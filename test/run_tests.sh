#!/usr/bin/env bash
# shellcheck disable=SC2155  # Declare and assign separately to avoid masking return values

: '
Vimwiki vader test script

Credit: https://github.com/w0rp/ale for script ideas and the color vader output function.
'

# Capture start time now
start_time=$(date +%s)


printHelp() {
  : 'Print usage to stdout'
  cat << '    EOF' | sed -e 's/^    //'
    Usage: bash run_tests.sh [OPTIONS]

    Runs Vimwiki Vader tests or Vint in a Docker container

    -h (Help) Print help message

    -n (versioN) Select "vim" or "nvim" from the current-release Docker image.
       Specify "local" to use your current editor (VIMWIKI_TEST_EDITOR=vim or nvim).
       Multiple editors can be specified as -n "vim nvim".
       Default is both current editors.

    -f (File) Space separated list of tests to run.
       E.g. -f "list_* z_success"

    -l (List) list available versions that can be used with the '-n' option

    -t (Type) Select test type: 'vader', 'vint', or 'all'

    -v (Verbose) Turn on verbose output.

    E.g. On Linux without with local Vim
    bash run_tests.sh -v -t vader -n local -f "link_creation.vader issue_markdown.vader"

    E.g. On Linux
    bash run_tests.sh -v -t vader -n "vim nvim" -f "link_creation.vader issue_markdown.vader"

    EOF

  exit 0
}


run_test(){
  : 'Main function'
  local -i res=0

  # Hi
  echo -en "Starting $(basename "$0") for VimWiki\n"

  # Hook ctrl-c or ctrl-z to stop tests
  trap exit 1 SIGINT SIGTERM
  
  # WORK
  parse_argument "$@"; ((res |= $?))
  execute_test_argument; ((res |= $?))

  # Print ellapsed time (after calculate it)
  end_time=$(date +%s)
  sec_time=$((end_time - start_time))
  printf -v script_time '%dh:%dm:%ds' $((sec_time/3600)) $((sec_time%3600/60)) $((sec_time%60))
  echo -ne "Script $(basename "$0"), in $script_time, Returned -> $res\n\n"
  
  return "$res"
}


parse_argument(){
  : 'Parse user argument'
  # Declare color helper
  red='\033[0;31m'
  green='\033[0;32m'
  nc='\033[0m'

  # Declare: Path of the script, supposing no spaces
  g_script_file=$(dirname "$0")
  g_script_path=$(realpath "$g_script_file")
  g_wiki_path=$(realpath "$g_script_path/..")
  g_tmp_dir=$(dirname "$(mktemp -u)")
  
  # Declare: list of vim/nvim versions
  g_vers="$(print_versions)"
  
  # Declare: type of tests to run - vader/vint/all
  g_type="all"
  
  # Declare: verbose output flag
  g_verbose=0
  
  # Declare: only run these tests
  g_file_test=""
  
  # Declare: docker flags
  flags=(--rm -v "$g_wiki_path:/source:ro" -w /testplugin vimwiki)
  
  # Parse all argument options
  while getopts ":hvn:lt:f:" opt; do
    case ${opt} in
      h)
        printHelp
        ;;
      n)
        g_vers="$OPTARG"
        ;;
      v)
        g_verbose=1
        ;;
      l)
        print_versions
        ;;
      t)
        g_type="$OPTARG"
        ;;
      f)
        g_file_test="$OPTARG"
        ;;
      \?)
        echo "Invalid option: $OPTARG" 1>&2
        exit 1
        ;;
      :)
        echo "Invalid option: $OPTARG requires an argument" 1>&2
        exit 1
        ;;
    esac
  done
  
  # Shift out parameters already processed 
  shift $((OPTIND -1))
  
  # Handle error for non-option arguments
  if [[ $# -ne 0 ]]; then
    echo "Error: Got $# non-option arguments." 1>&2
    exit 1
  fi
}


execute_test_argument(){
  : 'Execute test according to global variable'
  # Global error return of the script
  local -i res=0 ret=0
  
  # Select and run tests
  case $g_type in
    vader)
      run_vader; ret=$?
      echo "Main Vader: returned $ret"
      ((res |= ret))
      ;;
    vint)
      run_vint; ret=$?
      echo "Main Vint: returned $ret"
      ((res |= ret))
      ;;
    all)
      run_vint; ret=$?
      echo "Main Vint: returned $ret"
      ((res |= ret))
      run_vader; ret=$?
      echo "Main Vader: returned $ret"
      ((res |= ret))
      ;;
    *)
      echo "Error: invalid type - '$g_type'" 1>&2
      exit 1
  esac
  
  return "$res"
}


print_versions() {
  : 'Print the names of all vim/nvim versions'
  printf '%s\n' vim nvim
  exit 0
}


run_vader() {
  : 'Run Vader tests'
  echo -e "\nStarting Vader tests."
  local -i res=0
  local opt='' current_test=''

  # Parse tests files to execute
  if [[ -z "$g_file_test" ]]; then
    opt="test/*"
  else
    read -ra TEST <<< "$g_file_test"
    for current_test in "${TEST[@]}"; do
      # Remove quotes
      current_test=${current_test#\'}
      current_test=${current_test%\'}
      if [[ "$current_test" == *"*"* ]]; then
        opt+=" test/${current_test}"
      elif [[ -f "$current_test" ]]; then
        opt+=" test/${current_test}"
      elif [[ -f "${current_test}.vader" ]]; then
        opt+=" test/${current_test}.vader"
      else
        printf "WARNING: Test \"%s\" not found.\n", "$current_test"
      fi
    done
  fi

  # Run tests for each specified version
  for v in $g_vers; do
    echo -e "\n\nRunning version: $v"
    echo -e "============================="

    # Prepare an isolated copy for a local editor.
    if [[ "$v" == "local" ]]; then
      local_test_dir=$(mktemp -d "$g_tmp_dir/vimwiki-tests.XXXXXX") || return 1
      export VIMWIKI_TEST_ROOT="$local_test_dir"
      export VIMWIKI_TEST_HOME="$local_test_dir/home"
      vim="${VIMWIKI_TEST_EDITOR:-vim}"
      vim_opt="-u $local_test_dir/testplugin/test/vimrc"
    else
      vim="$v"
      vim_opt="-u test/vimrc"
    fi

    # Too talkative TODO make a verbose level 1..10 an 1 is not taking vim
    #if [[ "$verbose" != 0 ]]; then
    #    vim_opt+=' -V1'
    #fi
    # IDK why vim with -Es is returning ! and make fail:
    # -- tabnext profiling
    # -- map.vim
    vim_opt+=' -i NONE -n '
    if [[ "$vim" == *nvim ]]; then
      vim_opt+=' --headless '
    else
      vim_opt+=' -Es '
    fi

    # set -o pipefail

    # Copy the resources to temporary directory
    if [[ "$v" == "local" ]]; then
      if ! python3 - "$g_wiki_path" "$local_test_dir" <<'PY'
from pathlib import Path
import shutil
import sys

repo, root = map(Path, sys.argv[1:])
plugin = root / 'testplugin'
test_home = root / 'home'
test_home.mkdir()
shutil.copytree(repo, plugin, ignore=shutil.ignore_patterns('.git'))
for path in (plugin / 'test').rglob('*'):
    if path.is_file() and (path.suffix in ['.vader', '.vim', '.md', '.wiki'] or path.name == 'vimrc'):
        text = path.read_text()
        for old, new in [('$HOME', '$VIMWIKI_TEST_HOME'), ('$ROOT', '$VIMWIKI_TEST_ROOT'),
                         ('/home/vimtest', str(test_home)), ('/testplugin', str(plugin)),
                         ('~/', str(test_home) + '/')]:
            text = text.replace(old, new)
        path.write_text(text)
(root / 'rtp.vim').write_text('set runtimepath^=' + str(plugin) + '\n')
PY
      then
        return 1
      fi
      git clone --no-checkout https://github.com/junegunn/vader.vim "$local_test_dir/vader" \
        && git -C "$local_test_dir/vader" checkout de8a976f1eae2c2b680604205c3e8b5c8882493c \
        || return 1
    fi

    # Run batch of tests
    # shellcheck disable=SC2086,SC2206
    if [[ "$opt" != "" ]]; then
      if [[ "$v" == "local" ]]; then
        pushd "$local_test_dir/testplugin" \
          || echo 'Warning pushd testplugin failed'

        # Run the tests
        fcmd(){
          VADER_OUTPUT_FILE="$local_test_dir/vader.log" NVIM_LOG_FILE="$local_test_dir/nvim.log" \
            $vim $vim_opt "+Vader! ${opt}" > "$local_test_dir/editor.log" 2>&1
          local editor_status=$?
          if [[ "$editor_status" -ne 0 ]]; then
            cat "$local_test_dir/editor.log"
          fi
          if [[ ! -f "$local_test_dir/vader.log" ]]; then
            return 1
          fi
          vader_filter < "$local_test_dir/vader.log" | vader_color
          return "$(( editor_status | PIPESTATUS[0] | PIPESTATUS[1] ))"
        }
        echo -e "\nStarting Batch Vim/Vader:\n<- $opt\n"
        fcmd; ret=$?
        echo -e "\nReturned Batch Vim/Vader -> $ret"
        (( res |= ret ))

        popd || echo 'Warning popd failed'
      else
        # In docker
        fcmd() {
          docker run -a stderr -e "VADER_OUTPUT_FILE=/dev/stderr" \
            "${flags[@]}" "$v" $vim_opt "+Vader! ${opt}" 2>&1 \
            | vader_filter | vader_color
          return "$(( PIPESTATUS[0] | PIPESTATUS[1] | PIPESTATUS[2] ))"
        }
        echo -e "\nStarting Batch Vim/Vader with: $opt\n"
        fcmd; ret=$?
        echo -e "\nReturned Batch Docker/Vim/Vader -> $ret : ${PIPESTATUS[*]}"
        (( res |= ret ))
      fi
    fi

    #set +o pipefail

    if [[ "$v" == local ]]; then
      rm -rf "$local_test_dir"
    fi
  done
  return "$res"
}


run_vint() {
  : 'Run Vint test'
  local -i res=0
  
  local cmd="vint -s . && vint -s test/vimrc"
  
  if echo "$g_vers" | grep "local" > /dev/null; then
    echo -e "\nRunning Vint: $cmd : in $g_wiki_path"
    pushd "$g_wiki_path" > /dev/null \
      || echo 'Warning pushd wiki_path failed'
    $cmd
    res=$(( res | $? ))
    popd > /dev/null \
      || echo 'Warning popd also failed'
  else
    echo -e "\nStarting Docker container and running Vint: $cmd"
    docker run -a stdout "${flags[@]}" bash -c "$cmd"
    res=$(( res | $? ))
  fi
  
  return "$res"
}


vader_filter() {
  : 'Pipe Helper: Filter Vader Stdout'
  local -i res=0
  # Keep indentation
  local IFS=''

  while read -r REPLY; do
    # Print only possible error cases
    if [[ "$REPLY" = *'docker:'* ]] || \
        [[ "$REPLY" = *'Starting Vader:'* ]] || \
        [[ "$REPLY" = *'Vader error:'* ]] || \
        [[ "$REPLY" = *'Vim: Error '* ]]; then
      echo "$REPLY"
    elif [[ "$REPLY" = *'[EXECUTE] (X)'* ]] || \
        [[ "$REPLY" = *'[     DO] (X)'* ]] || \
        [[ "$REPLY" = *'[ EXPECT] (X)'* ]]; then
      echo -e "$red$REPLY$nc"
      res=1
    elif [[ "$REPLY" = *'Success/Total:'* ]]; then
      success="$(echo -n "$REPLY" | grep -o '[0-9]\+/' | head -n1 | cut -d/ -f1)"
      total="$(echo -n "$REPLY" | grep -o '/[0-9]\+' | head -n1 | cut -d/ -f2)"
      if [ "$success" -lt "$total" ]; then
        res=1
      fi
      echo "$REPLY"
    elif [[ "$g_verbose" != 0 ]]; then
      # just print everything
      echo "$REPLY"
    fi
  done

  if (( res == 1 )); then
    echo -e "\033[0;31m"
    echo -e "!---------Failed tests detected---------!"
    echo -e "Run with the '-v' flag for verbose output"
    echo -e "\033[0m"
  fi

  return "$res"
}


vader_color() {
  : 'Pipe Helper: Filter to add color to Vader'
  while read -r; do
    if [[ "$REPLY" = *'[EXECUTE] (X)'* ]] || \
      [[ "$REPLY" = *'[ EXPECT] (X)'* ]] || \
      [[ "$REPLY" = *'Vim: Error '* ]] || \
      [[ "$REPLY" = *'Vader error:'* ]]; then
      echo -en "$red"
    elif [[ "$REPLY" = *'[EXECUTE]'* ]] || [[ "$REPLY" = *'[  GIVEN]'* ]]; then
      echo -en "$nc"
    fi

    if [[ "$REPLY" = *'Success/Total'* ]]; then
      success="$(echo -n "$REPLY" | grep -o '[0-9]\+/' | head -n1 | cut -d/ -f1)"
      total="$(echo -n "$REPLY" | grep -o '/[0-9]\+' | head -n1 | cut -d/ -f2)"

      if [ "$success" -lt "$total" ]; then
        echo -en "$red"
      else
        echo -en "$green"
      fi

      echo "$REPLY"
      echo -en "$nc"
    else
      echo "$REPLY"
    fi
  done

  echo -en "$nc"
}


if ! (return 0 2>/dev/null); then
  run_test "$@"; exit $?
fi
