#!/usr/bin/env bash
set -eu -o pipefail

# try to test all possible different cases:
# - cloned repo vs. archive
# - tags vs. no tags in history
# - tagged commit vs. sometime after
# - on branch tip vs. detached head

export ALWAYS_LONG_VERSION="y"
export REVISION_SEPARATOR=" r"
export HASH_SEPARATOR=" "
export DIRTY_MARKER=" dirty"

compare() {
  echo -e "\033[32m> $1\033[0m"
  git archive HEAD | tar -x --to-stdout version.sh | bash -
  bash version.sh 2>/dev/null
}

pwd=$PWD
for script in "${@-version.sh}"; do
  echo -e "\033[1;31m--- TESTING: $script ---\033[0m"

  # create a temporary directory and init a repository
  tmp=$(mktemp -d -p /tmp version.sh-test-XXXXXXX)
  cd "$tmp"
  git init . >/dev/null
  git checkout -b main -q
  git config --local advice.detachedHead false >/dev/null
  git config --local user.name testscript
  git config --local user.email "git@$HOSTNAME"

  # copy the script and create a few commits
  cp "$pwd/$script" version.sh
  echo "version.sh export-subst" > .gitattributes
  git add version.sh .gitattributes
  git commit -m init >/dev/null
  git commit --allow-empty -m one >/dev/null
  git commit --allow-empty -m two >/dev/null
  git commit --allow-empty -m three >/dev/null
  git log --pretty=oneline | cat

  # begin comparisons
  compare "no tags, branch tip"
  git checkout -q HEAD~1
  compare "no tags, detached HEAD"
  git checkout -q main
  git tag -a -m tagged 0.1 HEAD~2
  compare "tagged ~2, branch tip"
  git checkout -q HEAD~1
  compare "tagged ~1, detached HEAD"
  git checkout -q HEAD~1
  compare "tagged, detached on tag"
  git checkout -q main
  git tag -a -m tagged 0.2 HEAD
  compare "tagged, branch tip"
  echo >> version.sh
  compare "tagged, branch tip, dirty"

  # clean up before next script
  cd /tmp && rm -rf "$tmp"
done
