Smackage is a prototype package manager for Standard ML libraries. Right now 
it does not do any installation, it just provides a standard way of getting
Standard ML code that understands where other Standard ML code might be found
on the filesystem.

Installation
============
Before installation, it's important to set up your SML compilers to interact
with smackage correctly. Smackage will live in a directory that we'll refer to
as `$SMACKAGE_HOME`. This directory is probably `~/.smackage`, but see the 
section on `$SMACKAGE_HOME` below for more information. 

Setting up SML/NJ
-----------------
To set up Standard ML of New Jersey to interact with Smackage, create a file
`~/.smlnj-pathconfig` containing the following line:

    SMACKAGE $SMACKAGE_HOME/lib

Don't actually write $SMACKAGE_HOME, though, replace it with the appropriate
absolute file path; on my machine this file contains the line

    SMACKAGE /Users/rjsimmon/.smackage/lib

Setting up MLton
----------------
MLton doesn't currently allow user-specific basis maps, so you'll have to be
able to edit the [MLBasis Path Map](http://mlton.org/MLBasisPathMap), which
is found in a place like `/usr/lib/mlton/mlb-path-map` or 
`/usr/lib/mlton/mlb-path-map`, depending on your system. Add the line

    SMACKAGE $SMACKAGE_HOME/lib

with the same caveat as before; after I edited my path map, the file 
had these contents:

    MLTON_ROOT $(LIB_MLTON_DIR)/sml
    SML_LIB $(LIB_MLTON_DIR)/sml
    SMACKAGE /Users/rjsimmon/.smackage/lib
    
Make sure it's an absolute path, starting with "/" or whatever your system
uses to refer to the file system root.

Compiling Smackage
------------------
Now, assuming you have downloaded the smackage source on your system, you can
build and start using smackage like this:
   
    $ cd smackage
    $ make mlton # (or make smlnj, not yet supported)
    $ bin/smack selfup
    $ bin/smack down cmlib v0

Referring to Smackage packages
------------------------------
If you've run the four lines as described above, you can refer to cmlib as 
`$SMACKAGE/cmlib/v0/cmlib.cm` (in SML/NJ .cm files) or as 
`$(SMACKAGE)/cmlib/v0/cmlib.mlb` (in MLton .mlb files).

You might want to add `$SMACKAGE_HOME/bin` to your path if you want to use 
applications compiled through smackage.

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

