#!/usr/bin/env bash

# Copyright (c) 2021 Anton Semjonov
# Licensed under the MIT License

# Print version information for a project manager with Git, working
# both in a checked-out repository or an exported archive file.
# For more information see: https://github.com/ansemjo/version.sh

# Note: this script requires Git version 2.32.0 or later.
# tl;dr: add "version-simple.sh export-subst" to .gitattributes

# get hash and describe string
if [[ '$Format:%%$' = '%' ]]; then
  # exported archive, replaced values
  hash='$Format:%H$'
  version='$Format:%(describe:exclude=*-[0-9]*-g[0-9a-f]*)$'
else
  # otherwise hopefully a live git repo
  git rev-parse >/dev/null || exit 1
  hash=$(git log -1 --pretty='%H') || exit 1
  version=$(git describe --exclude='*-[0-9]*-g[0-9a-f]*')
fi

# reformat version string to match `git describe --always --long`
if [[ -z "$version" ]]; then
  version="${hash:0:7}"
elif ! [[ "$version" =~ (.*)-([0-9]+)-g([0-9a-f]+)$ ]]; then
  version="$version-0-g${hash:0:7}"
fi

# output both strings
echo "$hash $version"