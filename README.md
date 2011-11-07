Smackage is a prototype package manager for Standard ML libraries. Right now 
it does not do any installation, it just provides a standard way of getting
Standard ML code that understands where other Standard ML code might be found
on the filesystem.

Installation
============
Installation takes three steps, and the first step is optional.

First, you have to pick the `$SMACKAGE_HOME` directory where Smackage will put
all of its files. This will be `~/.smackage` by default if you don't do
anything; see the section "The $SMACKAGE_HOME directory" below if you'd like
Smackage to put its files somewhere else.

Second, you have to configure your SML compilers to find the code that
Smackage will put on your system; see the section "Setting up your SML path
map" below.

Finally, you can actually build Smackage with the following commands:

    $ git clone git://github.com/standardml/smackage.git # or something
    $ cd smackage
    $ make mlton # (or `smlnj', or `win+smlnj' if you're in Cygwin)
    $ bin/smackage refresh
    $ bin/smackage get cmlib

(NOTE ON UPDATING: If you previously used smackage v0, you will want to edit
the `$SMACKAGE_HOME/config` file to change the `v0` to `v1`. Alternatively,
you can just delete `$SMACKAGE_HOME/config`.)

Referring to Smackage packages
------------------------------
If you've performed all the steps described above, you can will be able to 
refer to cmlib as `$SMACKAGE/cmlib/v1/cmlib.cm` (in SML/NJ .cm files) or as 
`$(SMACKAGE)/cmlib/v1/cmlib.mlb` (in MLton .mlb files).

You might want to add `$SMACKAGE_HOME/bin` to your path if you want to use 
applications compiled through smackage.

Building Smackage packages
--------------------------
Smackage doesn't have a uniform build process, at least not yet. Instead, we
support a simple `smackage make` command. If you type 
`smackage make package blah blah blah`, smackage will try to run 
`make blah blah blah` in the directory where `package` lives. We suggest that
if your tool compiles, you add a makefile option `install` that copies a 
created binary to the directory `$(DESTDIR)/bin`, in the style
described [here](http://www.gnu.org/prep/standards/html_node/DESTDIR.html). 
For instance, the following commands get and install [Twelf](http://twelf.org).

    $ bin/smackage refresh
    Selected `smackage 0.6.0'.
    Package `smackage 0.6.0' already installed.
    $ bin/smackage get twelf
    No major version specified, picked v1.
    Selected `twelf 1.7.1'.
    Repository is updated
    Package `twelf 1.7.1' downloaded.
    $ bin/smackage make twelf smlnj
    In directory: `/Users/rjsimmon/.smackage/lib/twelf/v1.7.1'
    smackage is preparing to run `make DESTDIR=/Users/rjsimmon/.smackage smlnj'
    <...snip...>
    $ smackage make twelf install
    In directory: `/Users/rjsimmon/.smackage/lib/twelf/v1.7.1'
    smackage is preparing to run `make DESTDIR=/Users/rjsimmon/.smackage install'
    cp bin/twelf-server /Users/rjsimmon/.smackage/bin/twelf-server.new
    mv /Users/rjsimmon/.smackage/bin/twelf-server.new /Users/rjsimmon/.smackage/bin/twelf-server

If `$SMACKAGE_HOME/bin` is on your search path, you can then refer to the
`twelf-server` binary.

    $ which twelf-server
    /Users/rjsimmon/.smackage/bin/twelf-server
    $ twelf-server
    Twelf 1.7.1+ (built 10/30/11 at 00:37:12 on concordia.wv.cc.cmu.edu)
    %% OK %%

Building Smackage with Smackage
-------------------------------
If you're on a reasonably Unix-ey system (OSX or Linux), the following 
commands will install smackage into the directory `$SMACKAGE_HOME/bin`.

    $ bin/smackage refresh
    $ bin/smackage make smackage mlton # or smlnj
    $ bin/smackage make smackage install

Then, if `$SMACKAGE_HOME/bin` is on your search path, you can refer 
directly to `smackage` on the command line:

    $ smackage list
    Package smackage:
       Version: 0.6.0
    Package twelf:
       Version: 1.7.1

If you have a Windows+Cygwin setup (smackage only works within Cygwin on
Windows), then you can try replacing the second command with 

    $ bin/smackage make smackage win+smlnj

but your mileage may vary.

Setting up your SML path map
============================
Smackage will live in a directory that we'll refer to
as `$SMACKAGE_HOME` in this section. This directory is probably 
`~/.smackage`, but see the section on `$SMACKAGE_HOME` below for more 
information. Whenever you see the string `$SMACKAGE_HOME` in this system, you 
should replace it with the appropriate absolute file path, for instance I 
wouldn't actually write

    SMACKAGE $SMACKAGE_HOME/lib

in a pathconfig file for Standard ML of New Jersey; instead, I'd write 

    SMACKAGE /Users/rjsimmon/.smackage/lib

Make sure you use an absolute path - starting with "/", or whatever your system
uses to refer to the file system root.

Setting up SML/NJ (system-wide)
-------------------------------
Find the file `lib/pathconfig` in the installation directory for SML/NJ, and 
add the following line:
  
    SMACKAGE $SMACKAGE_HOME/lib

Setting up SML/NJ (user-only)
-----------------------------
Create a file `~/.smlnj-pathconfig` containing the following line (or add
the following line to `~/.smlnj-pathconfig` if it exists already):

    SMACKAGE $SMACKAGE_HOME/lib

Setting up MLton (system-wide)
------------------------------
Find the [MLBasis Path Map](http://mlton.org/MLBasisPathMap), stored
in a file called `mlb-path-map`, usually somewhere like 
`/usr/lib/mlton/mlb-path-map` or 
`/usr/local/lib/mlton/mlb-path-map`, depending on your system. Add the line

    SMACKAGE $SMACKAGE_HOME/lib

Setting up MLton (user-only)
------------------------
MLton allows mlb path variables to be set on the mlton command
line. If you don't want to edit the global mlb-path-map file, you
can pass the SMACKAGE path as a command line argument to mlton. Since
doing this all the time is tedious and would break build scripts, you
probably want to set up a wrapper script somewhere in your path that
looks like:

    #!/bin/sh
    $MLTON_PATH -mlb-path-var 'SMACKAGE $SMACKAGE_HOME/lib' "$@"

where `$MLTON_PATH` and `$SMACKAGE_HOME` are replaced with the appropriate
paths. For example, on my system, I have a file /home/sully/bin/mlton
that contains:

    #!/bin/sh
    /usr/bin/mlton -mlb-path-var 'SMACKAGE /home/sully/.smackage/lib' "$@"

The $SMACKAGE_HOME directory
============================
Smackage has to figure out where it lives on the file system whenever it
starts up; the installation instructions referred to the directory where
smackage lives as `$SMACKAGE_HOME`. Smackage goes through the following process
to try and determine `$SMACKAGE_HOME`:

 1. If the `SMACKAGE_HOME` environment variable is defined, then smackage will
    always use that as `$SMACKAGE_HOME`. If this directory does not 
    exist, smackage will try to create it. Otherwise,
 2. If `/usr/local/smackage` exists, smackage will use that as
    `$SMACKAGE_HOME`. Otherwise,
 3. If `/opt/smackage/` exists, smackage will use that as
    `$SMACKAGE_HOME`. Otherwise,
 4. As a last resort, smackage will try to use `~/.smackage`, where `~` is 
    defined by the `HOME` environment variable. If this directory does not 
    exist, smackage will try to create it. 

