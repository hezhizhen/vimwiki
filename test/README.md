# Vimwiki Tests

The test suite uses [Vader](https://github.com/junegunn/vader.vim) for behavior
checks and [Vint](https://github.com/Kuniwak/vint) for Vimscript linting.
Only the latest stable Vim and Neovim releases are supported, currently Vim 9.2
and Neovim 0.12.6. Old editor matrices and version-dependent test skips have
been removed.

## Requirements

Run the tests on macOS with current Vim and Neovim executables on your `PATH`,
plus Git and Python 3. Install Vint in a virtual environment:

```sh
python3 -m venv /tmp/vimwiki-vint
/tmp/vimwiki-vint/bin/pip install 'setuptools<81' vim-vint
export PATH="/tmp/vimwiki-vint/bin:$PATH"
```

CI runs directly on macOS. It builds the latest tagged Vim patch release and
downloads the latest stable Neovim release for the runner's architecture.

## Running tests

From the `test/` directory:

```sh
# Run Vader and Vint with both installed editors.
bash run_tests.sh

# Run all Vader suites with one editor.
bash run_tests.sh -t vader -n vim
bash run_tests.sh -t vader -n nvim

# Run selected suites with both editors.
bash run_tests.sh -t vader -n 'vim nvim' -f 'list_clean.vader table_autoformat.vader'

# List the default editor names.
bash run_tests.sh -l
```

The runner also accepts an editor executable path. The `local` alias uses
`VIMWIKI_TEST_EDITOR`, defaulting to `vim`:

```sh
bash run_tests.sh -t vader -n local -f list_clean.vader
VIMWIKI_TEST_EDITOR=nvim bash run_tests.sh -t vader -n local -f list_clean.vader
```

Each editor run copies the plugin and test resources into a temporary directory
and downloads the pinned Vader revision there. Test writes stay in this copy.
The script can be invoked from any directory, including the repository root.

## Writing tests

Place new cases near the top of the relevant suite: earlier cases can change
editor state. Behavior checks must run on both supported editors without
skipping assertions based on old Vim versions.

Tests using the location list may need to run independently because of
[Vader issue #199](https://github.com/junegunn/vader.vim/issues/199).
