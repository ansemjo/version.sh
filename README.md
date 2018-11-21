# version.sh

`version.sh` is a script to output somewhat normalized version strings for embedding during software
builds from git repositories and archives.

Specifically, it attempts to produce the same strings whether you are building from a checked-out
tag of a cloned repository or a downloaded archive of that same tag. This problem is described a
little further in
[this blog post](https://semjonov.de/post/2018-10/commit-hash-replacement-in-git-archives/). In
short: you don't have the `.git` directory in downloaded archives and therefore cannot retrieve any
version information with `git`. Furthermore you might not want to require `git` when building your
software if all you really need is a small makefile or a single `go build` command, etc.

I solved this by adding an entry like `version.sh export-subst` to the project's `.gitattributes`
file and using `$Format:__$` strings inside the script.

- If we are working on a cloned repository, those strings will not be substituted, `./.git` will
  exist and the script will attempt to use `git describe ...` commands.

- If you are working on a downloaded copy, which was created with `git archive` (GitHub downloads
  fall into this category), the strings will have been substituted and the script will simply parse
  and echo those - no `git` required.

I tried to stay POSIX compliant, so you should be able to execute the script with any `sh`
implementation, given that external commands like `expr`, `sed`, `test` and `printf` are available.
This also means that build tools like `make` or Python's `setuptools` should trivially be able to
use `version.sh`'s output during builds. If you find a shell where it does not work, please open an
issue.

## example

Take this repository as an example:

```
$ cd $(mktemp -d)
$ git clone https://github.com/ansemjo/version.sh .
$ git checkout 0.1.0
$ ./version.sh describe
0.1.0-gbd4436b
```

vs.

```
$ cd $(mktemp -d)
$ curl -L https://github.com/ansemjo/version.sh/archive/0.1.0.tar.gz | tar xz --strip-components=1
$ ./version.sh describe
0.1.0-gbd4436b
```

## installation

Copy `version.sh` to your project directory and add this line to your
[gitattributes](https://git-scm.com/docs/gitattributes):

```
version.sh export-subst
```

Or scripted:

```
cd path/to/my/project
curl -LO https://github.com/ansemjo/version.sh/raw/master/version.sh
chmod +x version.sh
echo "version.sh export-subst" >> .gitattributes
```

## sepcial cases

The format strings that can be used with `export-subst` are limited and a few special cases arise:

- Downloaded archive, which is neither a tagged release nor a current tip of a branch: `%D` is empty
  and `version` will default to `FALLBACK_VERSION`, which is currently defined as `commit`.

- Downloaded archive, which is not tagged but is the tip of a branch: `%D` will contain something
  like `HEAD -> master` and `version` will be parsed as `master`.

- Cloned repository, a few commits after the last annotated tag: the version string will contain an
  appended `.rX` where `X` is the number of commits after the last tag.

- Cloned repository with no annotated tags: `version` will default to `0.0.0.rX` where `X` is the
  total number of commits.

- Cloned repository with modified but uncommitted files: appended `-dirty` after the commit hash.

All in all, only tagged releases are really consistent between the cloned repository and a
downloaded archive.

## usage

The script has four "commands": nothing/`print`, `version`, `commit`, `describe`

```
$ ./version.sh
version : 0.1.0
commit  : bd4436b39ee1b10eb71046b03b720dc4c3985349-dirty

$ ./version.sh version
0.1.0

$ ./version.sh commit
bd4436b39ee1b10eb71046b03b720dc4c3985349-dirty

$ ./version.sh describe
0.1.0-gbd4436b
```

Some usage examples with build tools:

### make + C

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

### setuptools + Python

```python
#!/usr/bin/env python

from subprocess import check_output
from setuptools import setup, find_packages

cmd = lambda c: check_output(c).strip().decode()

setup(
    name="mypkg",
    version=cmd(['./version.sh', 'version']),
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
go run -ldflags "-X main.version=$(./version.sh version) -X main.commit=$(./version.sh commit)" hello.go
```
