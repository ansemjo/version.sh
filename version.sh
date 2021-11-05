#!/bin/sh

# Copyright (c) 2018 Anton Semjonov
# Licensed under the MIT License

# Print version information for a project manager with Git, working
# both in a checked-out repository or an exported archive file.
# For more information see: https://github.com/ansemjo/version.sh

# tl;dr: copy script to your project and add "version.sh export-subst"
# to your .gitattributes file, then commit both files and use annotated
# tags for versioning

# Ignore shellcheck warnings for '$Format:..$', which looks
# like a variable in single-quotes but isn't!
# shellcheck disable=SC2016

# configure some strings, use env if given
ALWAYS_LONG_VERSION="${ALWAYS_LONG_VERSION-y}"
REVISION_SEPARATOR="${REVISION_SEPARATOR--}"
HASH_SEPARATOR="${HASH_SEPARATOR--g}"
DIRTY_MARKER="${DIRTY_MARKER--dirty}"

if test '$Format:%%$' = '%'; then
  # running from exported archive with replaced values

  hash='$Format:%H$'
  refs='$Format:%D$'
  # parse the reflist in %D to get a tag and/or branch name
  #! this will NOT pick up valid local branch names with '/' in them
  version=$(echo "${refs}" | sed -ne 's/.*tag: \([^,]*\).*/\1/p')
  branch=$(echo "${refs}" | sed -E -ne 's/(HEAD -> |,)//' -e 's/^(.* )?([a-z0-9._-][a-z0-9._-]*)( .*)?$/\2/p')
  dirty=''

else
  # otherwise hopefully a live git repo

  git rev-parse >/dev/null || exit 1
  hash=$(git log -1 --pretty='%H') || exit 1
  version=$(git describe)
  branch=$(git rev-parse --abbrev-ref HEAD)
  dirty=$(git diff-index --quiet HEAD -- || printf '%s' "${DIRTY_MARKER}")

fi

# reformat version string to somewhat match `git describe --always --long`
# and use configured separators if any, then append dirty marker
if test -z "${version}"; then
# fill in empty versions

  if test -z "${branch}" || test "${branch}" = 'HEAD'; then
    # if not a branch tip, use only hash
    version="${hash:0:7}"
  else
    # otherwise use branch name, too
    version="${branch}${HASH_SEPARATOR}${hash:0:7}"
  fi

elif test "${version%-[0-9]*-g[0-9a-f]*}" = "$version"; then
# replace short tags if they don't match "long" pattern

  if test "${ALWAYS_LONG_VERSION}" = 'y'; then
    version="${version}${REVISION_SEPARATOR}0${HASH_SEPARATOR}${hash:0:7}"
  fi

else

  # reformat long versions with configured separators
  v=$(echo "${version}" | sed -E 's/^(.*)-([0-9]+)-g([0-9a-f]+)$/\1/')
  r=$(echo "${version}" | sed -E 's/^(.*)-([0-9]+)-g([0-9a-f]+)$/\2/')
  h=$(echo "${version}" | sed -E 's/^(.*)-([0-9]+)-g([0-9a-f]+)$/\3/')
  version="${v}${REVISION_SEPARATOR}${r}${HASH_SEPARATOR}${h}"

fi
version="${version}${dirty}"

# parse commandline argument
case "$1" in
  '')
    echo "${hash} ${version}" ;;
  commit|hash)
    echo "${hash}" ;;
  version|describe)
    echo "${version}" ;;
  json)
    printf '{"version":"%s","commit":"%s"}\n' \
      "${version//\"/\\\"}" "${hash//\"/\\\"}" ;;
  env)
    esc() { printf "%s" "$1" | sed "s/'/'\\\\''/g"; }
    printf "VERSION='%s'\nCOMMIT='%s'\n" \
      "$(esc "${version}")" "$(esc "${hash}")" ;;
  *)
    printf '%s [version|commit|json|env]\n' "$0"; exit 1 ;;
esac
