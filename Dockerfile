FROM debian:stable-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash build-essential ca-certificates curl git libncurses-dev \
    passwd python3 python3-venv util-linux \
    && rm -rf /var/lib/apt/lists/*

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# CI resolves these tags on every run so a cached image cannot retain old editors.
# A manual build resolves the current releases when no tags are supplied.
ARG VIM_VERSION
RUN vim_tag="${VIM_VERSION:-$(git ls-remote --tags --refs https://github.com/vim/vim.git 'v[0-9]*' \
    | sed 's,.*refs/tags/,,' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' \
    | sort -V | tail -n 1)}" \
    && test -n "$vim_tag" \
    && git clone --depth 1 --branch "$vim_tag" https://github.com/vim/vim.git /vim \
    && cd /vim \
    && ./configure --with-features=huge --enable-gui=no --without-x --disable-nls \
    && make -j"$(nproc)" && make install \
    && rm -rf /vim

ARG NVIM_VERSION
RUN nvim_tag="${NVIM_VERSION:-$(curl -fsSL https://api.github.com/repos/neovim/neovim/releases/latest \
    | python3 -c 'import json, sys; print(json.load(sys.stdin)["tag_name"])')}" \
    && case "$(dpkg --print-architecture)" in \
         amd64) nvim_arch=x86_64 ;; \
         arm64) nvim_arch=arm64 ;; \
         *) exit 1 ;; \
       esac \
    && mkdir -p /opt/nvim \
    && curl -fsSL "https://github.com/neovim/neovim/releases/download/$nvim_tag/nvim-linux-$nvim_arch.tar.gz" \
       | tar -xz --strip-components=1 -C /opt/nvim

RUN python3 -m venv /opt/vint \
    && /opt/vint/bin/pip install --no-cache-dir 'setuptools<81' vim-vint
ENV PATH="/opt/vint/bin:/opt/nvim/bin:${PATH}"

RUN git clone --no-checkout https://github.com/junegunn/vader.vim /vader \
    && git -C /vader checkout de8a976f1eae2c2b680604205c3e8b5c8882493c

RUN printf 'set runtimepath^=/testplugin\n' > /rtp.vim \
    && useradd --create-home --uid 1000 vimtest
ENV ROOT=/
WORKDIR /testplugin
COPY test/docker-entrypoint.sh /usr/local/bin/vimwiki-test
ENTRYPOINT ["sh", "/usr/local/bin/vimwiki-test"]
