# version.sh

![GitHub Workflow](https://github.com/ansemjo/version.sh/actions/workflows/ci.yml/badge.svg)

`version.sh` is a script to output "normalized" version strings of projects tracked with Git,
e.g. for usage during software builds. Specifically, it aims to produce the same strings whether
you are working from a cloned repository or a downloaded archive of it.

## tl;dr:

```bash
[install, see below ...]
$ git describe
1.0-1-g904b097
$ bash version.sh describe
1.0-1-g904b097
$ git archive HEAD | tar -x --to-stdout version.sh | bash /dev/stdin describe
1.0-1-g904b097
```

## what's the problem?

The problem with embedding consistent versions from a single "source of truth" is described a little
further in
[this blog post](https://semjonov.de/post/2018-10/commit-hash-replacement-in-git-archives/). In
short: you don't have the `.git` directory in downloaded archives and therefore cannot retrieve any
version information with Git. Furthermore you might not want to have Git as a requirement when
building your software if all you really need is a small makefile or a single `go build` command,
etc. But then you need a seperate workflow for updating e.g. a `VERSION` file and need to track that
in your repository.

This can be solved by adding an entry like `VERSION export-subst` to the project's `.gitattributes`
file and using [`$Format:__$` strings](https://git-scm.com/docs/gitattributes#_creating_an_archive)
that will be substituted upon archive creation. However, that simple approach only works when you're
working from an extracted archive and the possible format-strings are rather limited.
Git has recently [learned a new trick](https://raw.githubusercontent.com/git/git/master/Documentation/RelNotes/2.32.0.txt)
and you can now use `%(describe)` placeholders, which mimic `git describe` very well, even when the exported archive
is not *exactly* a tagged release.

The `version.sh` script attempts to combine both worlds:

- If working in a cloned repository, those format-strings will not be substituted but the `.git`
  directory will exist and normal Git commands can be used.

- If working on an extracted archive, which was created with `git archive` (e.g. GitHub source downloads),
  the format-strings will have been substituted and the script will attempt to parse those – no `git` required.



## installation

Copy `version.sh` to your repository and add the following line to your
[`.gitattributes`](https://git-scm.com/docs/gitattributes) file, creating it if it does not exist:

```
version.sh export-subst
```

Add and commit both files and try running `sh version.sh`.

Scripted installation for copy-pasting:

```
curl -LO https://github.com/ansemjo/version.sh/raw/main/version.sh
echo 'version.sh export-subst' >> .gitattributes
git add version.sh .gitattributes && git commit -m 'use ansemjo/version.sh'
```

I tried to stay POSIX compliant and portable with `version.sh`, so you should be able to execute the script with any
compliant shell implementation, given that some basic commands like `sed`, `test` and `printf` are available. This also
means that build tools like `make` or Python's `setuptools` should trivially be able to use its output during builds.
The [`ci` workflow](https://github.com/ansemjo/version.sh/actions/workflows/ci.yml) currently tests
`bash`, `dash` and `ksh` on Linux and OSX.

A greatly simplified, less configurable, but modern implementation is found in `version-simple.sh`. It requires
`bash` and a Git version of at least 2.32.0 because it uses the `%(describe)` string mentioned above. *Note that
this includes any server-side binaries as well! I.e. if your project is hosted on GitHub you shouldn't use it
yet because GitHub's `git` does not support this as of now (2021-11).*



## usage

The script optionally takes one argument: `describe`, `commit`, `json` or `env`.

```
$ sh version.sh 
904b09789961440a2703fad36d9ddfe6533f9928 1.0-1-g904b097

$ sh version.sh describe
1.0-1-g904b097

$ sh version.sh commit
904b09789961440a2703fad36d9ddfe6533f9928

$ sh version.sh json
{"version":"1.0-1-g904b097","commit":"904b09789961440a2703fad36d9ddfe6533f9928"}

$ sh version.sh env
VERSION='1.0-1-g904b097'
COMMIT='904b09789961440a2703fad36d9ddfe6533f9928'

```

You can configure the version string with a few environment variables:

| env | default | description |
| --- | ------- | ----------- |
| `REVISION_SEPARATOR` | `-` | separator for the "commits since tag" counter |
| `HASH_SEPARATOR` | `-g` | separator before the commit hash at the end |
| `DIRTY_MARKER` | `-dirty` | added when working in a dirty clone |
| `ALWAYS_LONG_VERSION` | `y` | always format a long string, even if exactly on a tagged commit (`y`/`n`)

**Note**: previous versions contained a typo in the variable names, so they have changed!

 For example, a slightly customized version format might look like this:

```
$ export REVISION_SEPARATOR=" rev"
$ export HASH_SEPARATOR=" #"
$ sh version.sh describe
1.0 rev1 #904b097
```

Some common usage examples with a few build tools follow below.

## edge cases

With a modern Git (see above) the script should almost always produce identical output
from cloned repositories and extracted archives, which will be similar to `git describe --always --long`.
However, most Gits today will have a few edge cases, where different strings are produced because
the information that can be gained from the format-strings is limited:

| where | condition | effect |
| ----- | --------- | ------ |
| archive | not exactly a tagged release, but is a tip of a branch, e.g. `main.zip` | `$REFS` will contain something like `HEAD -> main` and version will be formatted like `main-g904b097` |
| archive | not exactly a tagged release, nor a tip of a branch⁺ | no information available at all, version will the short commit hash `904b097` |
| cloned | no annotated tags in history, detached `HEAD`⁺ | no information available at all, version will the short commit hash `904b097` |
| cloned | no annotated tags in history, branch tip | version will be formatted like a branch archive: `main-g904b097` |
| cloned | modified files present | appended dirty marker after the commit hash: `1.0-1-g904b097-dirty` |

⁺) Note that in an extracted archive you cannot distinguish whether it's just *not exactly* a tagged release or *there are no tags at all*, so the output will actually be identical to a detached `HEAD` with not tags at all.

To summarize, only annotated tags / releases are absolutely guaranteed to be consistent between the cloned repository and a downloaded archive.



## build tool examples

### C and Makefile

```c
#include <stdio.h>

int main() {
  printf("My version: %s\ncommit: %s\n", VERSION, COMMIT);
  return(0);
}
```

```makefile
VERSION := $(shell sh version.sh describe)
COMMIT  := $(shell sh version.sh commit)
CFLAGS  := $(CFLAGS) -DVERSION="\"$(VERSION)\"" -DCOMMIT="\"$(COMMIT)\""

hello: hello.c
	gcc $(CFLAGS) $< -o $@
```

### autotools

```
...
AC_INIT([myprogram], [m4_esyscmd_s([sh version.sh describe])])
AC_CONFIG_HEADERS([config.h])
AC_DEFINE_UNQUOTED([COMMIT], "`sh version.sh commit`", "Git commit from which we build")
...
```

Running `autoreconf && ./configure` will add to `config.h`:

```h
...

/* Version number of package */
#define VERSION "1.0-1-g904b097"

/* "Git commit from which we build" */
#define COMMIT "904b09789961440a2703fad36d9ddfe6533f9928"

...
```

### Python with setuptools

```python
#!/usr/bin/env python

import os
from subprocess import check_output
from setuptools import setup, find_packages

os.environ["REVISION_SEPARATOR"] = ".post" # PEP 440 compatability
os.environ["HASH_SEPARATOR"] = " " # for splitting
cmd = check_output(["sh", "version.sh", "describe"]).strip() # => b'1.0.post1 g904b097'
version = cmd.split()[0].decode() # => '1.0.post1'

setup(
    name="mypkg",
    version=version,
    packages=find_packages(),
    ...
)
```

### Go

```go
package main

import "fmt"

var version string

func main() {
  fmt.Println("hello version", version)
}
```

```sh
go run -ldflags "-X main.version=$(sh version.sh describe)" hello.go
```
