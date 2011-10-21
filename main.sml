(******************************************************************************
 Smackage SML Package System
 
 Copyright (c) 2011, Gian Perrone <gdpe at itu dot dk>
 All rights reserved.

 Redistribution and use in source and binary forms, with or without 
 modification, are permitted provided that the following conditions are met:

 Redistributions of source code must retain the above copyright notice, this 
 list of conditions and the following disclaimer.

 Redistributions in binary form must reproduce the above copyright notice, 
 this list of conditions and the following disclaimer in the documentation 
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
 INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
 CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
 ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
******************************************************************************)

structure Smackage =
struct
    exception SmackExn of string

    (** Attempt to ascertain the smackage home directory.
        Resolved in this order:

        SMACKAGE_HOME environment variable
        ~/.smackage/
        /usr/local/smackage/
        /opt/smackage/
    *)
    val smackHome =
    let
        fun tryDir (SOME s) = ((OS.FileSys.openDir s; true) handle _ => false)
          | tryDir NONE = false
        val envHome = OS.Process.getEnv "SMACKAGE_HOME"
        val envHome' = if OS.Process.getEnv "HOME" = NONE 
            then NONE 
            else SOME (valOf (OS.Process.getEnv "HOME") ^ "/.smackage")
    in
        if tryDir envHome then valOf envHome else
        if tryDir envHome' then valOf envHome' else
        if tryDir (SOME "/usr/local/smackage") then "/usr/local/smackage" else
        if tryDir (SOME "/opt/smackage") then "/opt/smackage" else
        raise SmackExn "Cannot find smackage home. Try setting SMACKAGE_HOME"
    end

    (** Install a package with a given name and version.
        An empty version string means "the latest version".
        raises SmackExn in the event that the package is already installed or
        if no such package or version is found. *)
    fun install name version =
    let
        val workingDir = smackHome ^ "/tmp"
    in
        raise SmackExn "Not implemented"
    end

    (** Uninstall a package with a given name and version.
        An empty version string means "all versions".
        raises SmackExn in the event that the package is already installed or
        if no such package or version is found. *)
    fun uninstall name version =
    let
        val _ = ()
    in
        raise SmackExn "Not implemented"
    end

    (** List the packages currently installed. *)
    fun listInstalled () = raise SmackExn "Not implemented"

    (** Search for a package in the index, with an optional version *)
    fun search name version = raise SmackExn "Not implemented"

    (** Display metadata for a given package, plus installed status *)
    fun info name version = raise SmackExn "Not implemented"

    fun update () = raise SmackExn "Not implemented"

    fun printUsage () =
        (print "Usage: smackage <command> [args]\n";
         print " Commands:\n";
         print "\thelp\t\t\t\tDisplay this usage and exit\n";
         print "\tinfo <name> [version]\t\tDisplay package information.\n";
         print "\tinstall <name> [version]\tInstall the named package\n";
         print "\tlist\t\t\t\tList installed packages\n";
         print "\tsearch <name>\t\t\tFind an appropriate package\n";
         print "\tuninstall <name> [version]\tRemove a package\n";
         print "\tupdate\t\t\t\tUpdate the package database\n");

    fun main _ = case CommandLine.arguments () of
          ("--help"::_) => (printUsage(); OS.Process.success)
        | ("-h"::_) => (printUsage(); OS.Process.success)
        | ("help"::_) => (printUsage(); OS.Process.success)
        | ["info",pkg,ver] => (info pkg ver; OS.Process.success)
        | ["info",pkg] => (info pkg ""; OS.Process.success)
        | ["update"] => (update (); OS.Process.success)
        | ["search",pkg] => (search pkg ""; OS.Process.success)
        | ["search",pkg,ver] => (search pkg ver; OS.Process.success)
        | ["install",pkg,ver] => (install pkg ver; OS.Process.success)
        | ["install",pkg] => (install pkg ""; OS.Process.success)
        | ["uninstall",pkg,ver] => (uninstall pkg ver; OS.Process.success)
        | ["uninstall",pkg] => (uninstall pkg ""; OS.Process.success)
        | ["list"] => (listInstalled(); OS.Process.success)
        | _ => (printUsage(); OS.Process.failure)
    handle (SmackExn s) => 
        (TextIO.output (TextIO.stdErr, s ^ "\n"); OS.Process.failure)
end

val _ = OS.Process.exit(Smackage.main())

