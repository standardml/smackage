Smackage is a prototype package manager for Standard ML libraries. Right now 
it does only minimal installation; it is mainly designed to provide a 
standard way of getting Standard ML code that understands where other 
Standard ML code might be found on the filesystem.

Installation
------------
Installation takes five steps, and the first and last two steps are 
optional.

**Step 1: Pick a `SMACKAGE_HOME` directory (optional).**

The `$SMACKAGE_HOME` directory is where Smackage will put all of its files. 
This will be `~/.smackage` by default if you don't do anything; see the 
section "The $SMACKAGE_HOME directory" towards the bottom if you'd like 
Smackage to put its files somewhere else.

**Step 2: Set up your SML compilers to use Smackage.**

You have to configure your SML compilers to find the code that Smackage 
will put on your system. This is a bit system-dependent; see the section 
"Setting up your SML path map" below for details.

**Step 3: Download.**

Finally, you can actually build Smackage with the following commands; the 
first `git clone...` command is just one of the ways you can get smackage
onto your hard drive; an alternative would be to download one of the
[tarred or zipped releases](https://github.com/standardml/smackage/tags). 
Note: the directory (probably named `smackage`) that you put the initial 
Smackage code into should *not* be the same as the `$SMACKAGE_HOME` 
directory.

    $ git clone git://github.com/standardml/smackage.git # or something
    $ cd smackage
    $ make mlton # (or `smlnj', or `win+smlnj' if you're in Cygwin)
    $ bin/smackage

Smackage now lives in the `bin` subdirectory of the current directory.

To install smackage in $SMACKAGE_HOME,

    $ DESTDIR=$SMACKAGE_HOME make install

Now you can proceed to update your path and use smackage without having the build repository available.

**Step 4: Update your PATH (optional).**

Smackage-aware applications have a makefile option `install` that places 
a binary in `$SMACKAGE_HOME/bin` *IF* the makefile is invoked through 
`smackage make`. If you want to use Smackage to install applications,
you should add `$SMACKAGE_HOME/bin` to your `PATH` environment variable.

(Remember: don't literally add `$SMACKAGE_HOME/bin`, replace 
`$SMACKAGE_HOME` with the absolute path of whatever directory you picked
in Step 1. So you'll really add something like 
`/Users/myusername/.smackage/bin` to your path.)

**Step 5: Bootstrap (optional).**

Smackage is a smackage-aware application! If you added 
`$SMACKAGE_HOME/bin` to your search path, then you can run the following:

    $ bin/smackage refresh
    $ bin/smackage make smackage mlton # or smlnj, or win+smlnj, etc
    $ bin/smackage make smackage install
    $ which smackage 

(Type `bin/smackage make smackage` to see all the possible installation 
options: polyml, win+mlton, mlkit, etc...)

The last command, `which smackage`, should report that Smackage can be found
at `$SMACKAGE_HOME/bin/smackage`. Now you've bootstrapped Smackage: you no 
longer need the current directory where you downloaded Smackage, you just 
need the `$SMACKAGE_HOME` directory.

### Referring to Smackage packages

If you've performed all the steps described above, you will be able to 
refer to cmlib as `$SMACKAGE/cmlib/v1/cmlib.cm` (in SML/NJ .cm files) or as 
`$(SMACKAGE)/cmlib/v1/cmlib.mlb` (in .mlb files).

You want to add `$SMACKAGE_HOME/bin` to your path if you want to use 
applications compiled through Smackage.

### Building Smackage packages

Smackage doesn't have a uniform build process, at least not yet. Instead, we
support a simple `smackage make` command. If you type 
`smackage make package blah blah blah`, smackage will try to run 
`make blah blah blah` in the directory where `package` lives. We suggest that
if your tool compiles into binaries, say, you add a makefile option `install` that copies the 
created binaries to the directory `$(DESTDIR)/bin`, in the style
described [here](http://www.gnu.org/prep/standards/html_node/DESTDIR.html). 
For instance, the following commands get and install [Twelf](http://twelf.org).

    $ smackage refresh
    $ smackage get twelf
    $ smackage make twelf smlnj # or mlton, ...
    $ smackage make twelf install

If `$SMACKAGE_HOME/bin` is on your search path, you can then refer to the
`twelf-server` binary like this:

    $ which twelf-server
    /Users/rjsimmon/.smackage/bin/twelf-server
    $ twelf-server
    Twelf 1.7.1+ (built 10/30/11 at 00:37:12 on concordia.wv.cc.cmu.edu)
    %% OK %%

Setting up your SML path map
----------------------------
Smackage will live in a directory that we'll refer to
as `$SMACKAGE_HOME` in this section. This directory is probably 
`~/.smackage`, but see the section on `$SMACKAGE_HOME` below for more 
information. Whenever you see the string `$SMACKAGE_HOME` in the text below, you 
should replace it with the appropriate absolute file path, for instance I 
wouldn't actually write

    SMACKAGE $SMACKAGE_HOME/lib

in a pathconfig file for Standard ML of New Jersey; instead, I'd write

    SMACKAGE /Users/rjsimmon/.smackage/lib

Make sure you use an absolute path - starting with "/", or whatever your system
uses to refer to the file system root.

### Setting up SML/NJ (system-wide)

Find the file `lib/pathconfig` in the installation directory for SML/NJ, and 
add the following line:
  
    SMACKAGE $SMACKAGE_HOME/lib

### Setting up SML/NJ (user-only)

Create a file `~/.smlnj-pathconfig` containing the following line (or add
the following line to `~/.smlnj-pathconfig` if it exists already):

    SMACKAGE $SMACKAGE_HOME/lib

### Setting up MLton (system-wide)

Find the [MLBasis Path Map](http://mlton.org/MLBasisPathMap), stored
in a file called `mlb-path-map`, usually somewhere like 
`/usr/lib/mlton/mlb-path-map` or 
`/usr/local/lib/mlton/mlb-path-map`, depending on your system. Add the line

    SMACKAGE $SMACKAGE_HOME/lib

### Setting up MLton (user-only)

MLton allows mlb path variables to be set on the `mlton` command
line. If you don't want to edit the global `mlb-path-map` file, you
can pass the SMACKAGE path as a command line argument to `mlton`. Since
doing this all the time is tedious and would break build scripts, you
probably want to set up a wrapper script somewhere in your path that
looks like:

    #!/bin/sh
    $MLTON_PATH -mlb-path-var 'SMACKAGE $SMACKAGE_HOME/lib' "$@"

where `$MLTON_PATH` and `$SMACKAGE_HOME` are replaced with the appropriate
paths. For example, on my system, I have a file `/home/sully/bin/mlton`
that contains:

    #!/bin/sh
    /usr/bin/mlton -mlb-path-var 'SMACKAGE /home/sully/.smackage/lib' "$@"

### Setting up MLKit or SMLtoJs

[MLKit](http://melsman.github.io/mlkit) and
[SMLtoJs](http://www.smlserver.org/smltojs) support
[.mlb-files](http://www.elsman.com/mlkit/mlbasisfiles.html) much like
MLton. The only limitation is that MLKit and SMLtoJs do not support
export filtering through the use of explicit MLB module bindings. 

To allow for MLKit or SMLtoJs to find a definition for the `$SMACKAGE`
MLB path variable, add a line to the appropriate `mlb-path-map` file
found in `~/.mlkit/`, `~/.smltojs/`, `/usr/local/mlkit/`, or
`/usr/local/smltojs`:

    SMACKAGE $SMACKAGE_HOME/lib

Be aware that when MLKit (or SMLtoJs) is compiling a package, it will
write files within `MLB/` subfolders of the package's folder. This
behavior may cause problems if you don't have write access to the
`$SMACKAGE_HOME/lib` folder.

The $SMACKAGE_HOME directory
----------------------------
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

