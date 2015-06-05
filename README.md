# App::Multigit

This module allows you to run commands against a set of git modules in the same
directory. It works like git submodules, except you don't actually have to deal
with git submodules.

It ships with a single command, `mg`, which dispatches to all the configured
modules in the directory.

A file `.mgconfig` uses standard INI format to list the relevant modules:

    [https://github.com/Author/Some-Module.git]
    confkey=val
    [https://github.com/Author/Some-Other-Module.git]
    [ssh://my-git-server/Local-Module.git]

The repository's URL is the key to the section in the INI format. The `dir` key
can be used to specify its location:

    [https://github.com/Author/Some-Module]
    dir=alternative-location

By default, the final path part of the URL is used, minus the `.git` extension.

The key here doesn't have to be the URL, but it normally is. You can be explicit
about the URL:

    [Some-Module]
    dir=/path/to/whatever
    url=https://github.com/Author/Some-Module

The module `App::Multigit` itself provides an interface into this config. See
the POD for details.

## Commands

Commands are created like with git itself; the file `mg-$cmd` should exist and
be executable.

The command is run:

    mg-command --workdir /absolute/directory/name/

This is the only interface between you and App::Multigit. For any other
behaviour, simply use App::Multigit inside your script.

`mg` itself is only a thin wrapper. It checks the environment and then execs the
above. The command itself is required to do whatever it needs to do.

Commonly, the command will almost certainly want to run a git command for each
repository and deal with the results. The examples do this by means of
`App::Multigit::each` and an `IO::Async::Process` object.

The `mg-branch` example simply blurts back the output from a git command run on
each repository; the `mg-closes` example is more involved, only reporting those
repositories for which the output is relevant.

## Help

The usage string of `mg` is accessed by running `mg` on its own, or `mg help`.

Running `mg help command` simply execs `mg-command --help`, so each command
should understand the help option and implement it.

The POD for `App::Multigit` will give you more information about how to actually
use the interface to write a command.
