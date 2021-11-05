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
# like a constant / variable in single-quotes but isn't!
# shellcheck disable=SC2016,SC2050

# configure some strings, use env if given
ALWAYS_LONG_VERSION="${ALWAYS_LONG_VERSION-y}"
REVISION_SEPARATOR="${REVISION_SEPARATOR--}"
HASH_SEPARATOR="${HASH_SEPARATOR--g}"
DIRTY_MARKER="${DIRTY_MARKER--dirty}"

if test '$Format:%%$' = '%'; then
  # running from exported archive with replaced values

  longhash='$Format:%H$'
  hash=$(echo "$longhash" | head -c7)
  refs='$Format:%D$'
  desc='$Format:%(describe:exclude=*-[0-9]*-g[0-9a-f]*)$'
  dirty=''

  if test "$(printf '%s' "$desc" | head -c11)" != "%(describe:"; then
    # use desc if the git was modern enough
    version="${desc}"
  else
    # otherwise parse the reflist in %D to hopefully get tag and branch names
    #! this will NOT pick up valid local branch names with '/' in them
    version=$(echo "${refs}" | sed -ne 's/.*tag: \([^,]*\).*/\1/p')
    branch=$(echo "${refs}" | sed -E -ne 's/(HEAD -> |,)//' -e 's/^(.* )?([a-z0-9._-][a-z0-9._-]*)( .*)?$/\2/p')
  fi

else
  # otherwise hopefully in a checked-out git repo

  git rev-parse >/dev/null || exit 1
  longhash=$(git log -1 --pretty='%H') || exit 1
  hash=$(echo "$longhash" | head -c7)
  version=$(git describe --exclude='*-[0-9]*-g[0-9a-f]*')
  branch=$(git rev-parse --abbrev-ref HEAD)
  dirty=$(git diff-index --quiet HEAD -- || printf '%s' "${DIRTY_MARKER}")

fi

# reformat version string to somewhat match `git describe --always --long`
# and use configured separators if any, then append dirty marker
if test -z "${version}"; then
# fill in empty versions

  if test -z "${branch}" || test "${branch}" = 'HEAD'; then
    # if not a branch tip, use only hash
    version="${hash}"
  else
    # otherwise use branch name, too
    version="${branch}${HASH_SEPARATOR}${hash}"
  fi

elif test "${version%-[0-9]*-g[0-9a-f]*}" = "$version"; then
# replace short tags if they don't match "long" pattern

  if test "${ALWAYS_LONG_VERSION}" = 'y'; then
    version="${version}${REVISION_SEPARATOR}0${HASH_SEPARATOR}${hash}"
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
    echo "${longhash} ${version}" ;;
  commit|hash)
    echo "${longhash}" ;;
  version|describe)
    echo "${version}" ;;
  json)
    esc() { printf "%s" "$1" | sed -E 's/["\\]/\\&/g'; }
    printf '{"version":"%s","commit":"%s"}\n' \
      "$(esc "${version}")" "$(esc "${longhash}")" ;;
  env)
    esc() { printf "%s" "$1" | sed "s/'/'\\\\''/g"; }
    printf "VERSION='%s'\nCOMMIT='%s'\n" \
      "$(esc "${version}")" "$(esc "${longhash}")" ;;
  *)
    printf '%s [version|commit|json|env]\n' "$0"; exit 1 ;;
esac
