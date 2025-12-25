#!/bin/bash

mkdir -p ~/.config/ghostty/themes && \
tmpdir=$(mktemp -d) && \
git clone --depth 1 --filter=blob:none --sparse https://github.com/mbadolato/iTerm2-Color-Schemes.git "$tmpdir" && \
cd "$tmpdir" && \
git sparse-checkout set ghostty && \
rsync -a ghostty/ ~/.config/ghostty/themes/ && \
cd ~
rm -rf "$tmpdir"
