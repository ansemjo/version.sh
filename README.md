# version.sh

![GitHub Workflow](https://github.com/ansemjo/version.sh/actions/workflows/ci.yml/badge.svg)

`version.sh` is a script to output normalized version strings of projects tracked with Git for usage
during software builds. Specifically, it aims to produce the same strings whether you are building
from a checked-out tag of a cloned repository or a downloaded archive of that same tag.

## UPDATE 2021-06

Git 2.32 has [learned a new trick](https://raw.githubusercontent.com/git/git/master/Documentation/RelNotes/2.32.0.txt):
thanks to [Eli Schwartz and René Scharfe](https://www.spinics.net/lists/git/msg398884.html), the `git log --format=...`
(and as such also the `export-subst` attribute) now handles `%(describe)` placeholders! This means all of the things
below can now be applied to archives of a commit that are *not* exactly a release! Implementation in this script TBA.

## THE PROBLEM

The problem with embedding consistent versions from a single "source of truth" is described a little
further in
[this blog post](https://semjonov.de/post/2018-10/commit-hash-replacement-in-git-archives/). In
short: you don't have the `.git` directory in downloaded archives and therefore cannot retrieve any
version information with Git. Furthermore you might not want to have Git as a requirement when
building your software if all you really need is a small makefile or a single `go build` command,
etc. But then you need a seperate workflow for updating e.g. a `VERSION` file and need to track that
in your repository ..

This can be solved by adding an entry like `VERSION export-subst` to the project's `.gitattributes`
file and using [`$Format:__$` strings](https://git-scm.com/docs/gitattributes#_creating_an_archive)
that will be substituted upon archive creation. The script goes a step further still:

- If we are working on a cloned repository, those strings will not be substituted but `./.git` will
  exist and the script will attempt to use `git describe ...` commands.

- If you are working on a downloaded copy, which was created with `git archive` (e.g. GitHub
  downloads), the strings will have been substituted and the script will simply parse and echo
  those - no `git` required.

I tried to stay POSIX compliant and portable, so you should be able to execute the script with any
shell implementation, given that commands like `sed`, `test` and `printf` are available. This also
means that build tools like `make` or Python's `setuptools` should trivially be able to use
`version.sh`'s output during builds. If you find a shell where it does not work, please open an
issue. The workflow [currently tests](https://github.com/ansemjo/version.sh/actions/workflows/ci.yml)
`bash`, `dash` and `ksh` on Linux and OSX.

## INSTALLATION

Copy `version.sh` to your project directory and add the following line to your
[`.gitattributes`](https://git-scm.com/docs/gitattributes):

```
version.sh export-subst
```

Now commit both files and try running `sh version.sh`!

Scripted installation for copy-pasting:

```
cd path/to/your/project
curl -LO https://github.com/ansemjo/version.sh/raw/master/version.sh
echo 'version.sh export-subst' >> .gitattributes
git add version.sh .gitattributes
git commit -m 'begin using ansemjo/version.sh'
```

## USAGE

The script takes the following arguments: nothing/`print`, `version`, `commit`, `describe`, `json`

```
$ sh version.sh
version : 0.1.1-6
commit  : d2dcc2b48f4a3993eea1bbbd4e0419825c2b5875-dirty

$ sh version.sh version
0.1.1-6

$ sh version.sh commit
d2dcc2b48f4a3993eea1bbbd4e0419825c2b5875-dirty

$ sh version.sh describe
0.1.1-6-gd2dcc2b

$ sh version.sh json | jq .
{
  "version": "0.1.1-6",
  "commit": "d2dcc2b48f4a3993eea1bbbd4e0419825c2b5875-dirty",
  "describe":"0.1.1-6-gd2dcc2b"
}
```

You can configure the version strings with `REVISION_SEPERATOR` and `COMMIT_SEPERATOR`:

```
$ REVISION_SEPERATOR=.r COMMIT_SEPERATOR=.commit- sh version.sh describe
0.2.1.r4.commit-1f80826
```

Some usage examples with common build tools follow below.

## SPECIAL CASES

On the one hand the format strings that can be used with `export-subst` are limited. On the other
hand a cloned repository allows for some more specific information. Thus a few special cases arise:

| workdir    | condition                                                            | effect                                                                                                             |
| ---------- | -------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| archive    | not a tagged release, but is a tip of a branch, e.g. `master.tar.gz` | `$REFS` will contain something like `HEAD -> master` and version will be parsed as `master` in this case           |
| archive    | neither a tagged release nor a current tip of a branch               | `$REFS` is empty and version will default to `FALLBACK_VERSION`, which is currently defined as the string `commit` |
| repository | modified but uncommitted files present                               | appended `-dirty` after the commit hash                                                                            |
| repository | `HEAD` is a few commits after the last annotated tag                 | the version string will contain an appended `-X` where `X` is the number of commits after the last tag             |
| repository | no annotated tags in history                                         | version will default to `0.0.0-X` where `X` is the total number of commits                                         |

All in all, only annotated tags / releases are really consistent between the cloned repository and a
downloaded archive.

## BUILD TOOL INTEGRATION

### C + Makefile

```c
#include <stdio.h>

int main() {
  printf("Hello, World!\n");
  printf("version: %s\ncommit: %s\n", VERSION, COMMIT);
  return(0);
}
```

```makefile
VERSION := $(shell ./version.sh version)
COMMIT  := $(shell ./version.sh commit)

CFLAGS := $(CFLAGS) -DVERSION="\"$(VERSION)\"" -DCOMMIT="\"$(COMMIT)\""

hello: hello.c
	gcc $(CFLAGS) $< -o $@
```

### autotools

```
...
AC_INIT([myprogram], [m4_esyscmd_s([sh version.sh version])])
AC_CONFIG_HEADERS([config.h])
AC_DEFINE_UNQUOTED([COMMIT], "`sh version.sh commit`", "Git commit from which we build")
...
```

Running `autoreconf && ./configure` will add to `config.h`:

```h
...

/* Version number of package */
#define VERSION "*****"

/* "Git commit from which we build" */
#define COMMIT "****************************************"

...
```

### Python + setuptools

```python
#!/usr/bin/env python

from os import environ
from subprocess import check_output
from setuptools import setup, find_packages

environ['REVISION_SEPERATOR'] = '.post' # PEP 440 compatability
version = check_output(['sh', 'version.sh', 'version']).strip().decode()

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

var commit string
var version string

func main() {

  fmt.Println("hello version", version)

  if commit != "" {
    fmt.Println("commit:", commit)
  }

}
```

```sh
go run -ldflags "-X main.version=$(sh version.sh version) -X main.commit=$(sh version.sh commit)" hello.go
```
