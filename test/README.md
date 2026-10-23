# Vimwiki Tests

The test suite uses [Vader](https://github.com/junegunn/vader.vim) for behavior
checks and [Vint](https://github.com/Kuniwak/vint) for Vimscript linting.
Only the latest stable Vim and Neovim releases are supported, currently Vim 9.2
and Neovim 0.12.6. Old editor matrices and version-dependent test skips have
been removed.

## Building the Docker image

From the repository root:

```sh
docker build --no-cache -t vimwiki .
```

The image builds the latest tagged Vim patch release and downloads the latest
stable Neovim release for Linux x86_64 or arm64. `--no-cache` refreshes moving
release tags on manual rebuilds. CI resolves the current release tags on every
run and passes them as build arguments so editor updates invalidate its cache.

## Running tests

From the `test/` directory:

```sh
# Run Vader and Vint with both current editors in Docker.
bash run_tests.sh

# Run all Vader suites with one editor.
bash run_tests.sh -t vader -n vim
bash run_tests.sh -t vader -n nvim

# Run selected suites with both editors.
bash run_tests.sh -t vader -n 'vim nvim' -f 'list_clean.vader table_autoformat.vader'

# List the available Docker editors.
bash run_tests.sh -l
```

To use a local editor, select `local`; `VIMWIKI_TEST_EDITOR` selects the executable:

```sh
bash run_tests.sh -t vader -n local -f list_clean.vader
VIMWIKI_TEST_EDITOR=nvim bash run_tests.sh -t vader -n local -f list_clean.vader
```

Local mode copies the plugin and test resources into a temporary directory.
The script downloads Vader when preparing a local run.

For an interactive Docker session, run this from the repository root:

```sh
docker run -it --rm -v "$PWD:/source:ro" vimwiki vim -u test/vimrc -i NONE
```

Replace `vim` with `nvim` to use Neovim. Run `:Vader test/*.vader` inside the
editor, or name an individual suite.
Docker also copies the source into the container before running tests.

## Writing tests

Place new cases near the top of the relevant suite: earlier cases can change
editor state. Behavior checks must run on both supported editors without
skipping assertions based on old Vim versions.

Tests using the location list may need to run independently because of
[Vader issue #199](https://github.com/junegunn/vader.vim/issues/199).
