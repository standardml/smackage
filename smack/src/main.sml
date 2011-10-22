structure Smack =
struct
    exception SmackExn of string

    (** Install a package with a given name and version.
        An empty version string means "the latest version".
        raises SmackExn in the event that the package is already installed or
        if no such package or version is found. *)
    fun install name version =
    let
        val _ = if version = "" then 
                    raise Fail "Install needs an explicit version for now."
                else ()
        val ver = SemVer.fromString version
        val _ = SmackLib.install (!Configure.smackHome) (name,ver)
    in
        ()
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

    fun source pkg prot url = raise Fail "Not implemented"

    fun printUsage () =
        (print "Usage: smackage <command> [args]\n";
         print " Commands:\n";
         print "\thelp\t\t\t\tDisplay this usage and exit\n";
         print "\tinfo <name> [version]\t\tDisplay package information.\n";
         print "\tinstall <name> [version]\tInstall the named package\n";
         print "\tlist\t\t\t\tList installed packages\n";
         print "\tsearch <name>\t\t\tFind an appropriate package\n";
         print "\tsource <name> <protocol> <url>\t\t\tAdd a local source\n";
         print "\tuninstall <name> [version]\tRemove a package\n";
         print "\tupdate\t\t\t\tUpdate the package database\n");

    fun main _ = 
       let
          val () = Configure.init ()
       in
          case CommandLine.arguments () of
             ("--help"::_) => (printUsage(); OS.Process.success)
           | ("-h"::_) => (printUsage(); OS.Process.success)
           | ("help"::_) => (printUsage(); OS.Process.success)
           | ["info",pkg,ver] => (info pkg ver; OS.Process.success)
           | ["info",pkg] => (info pkg ""; OS.Process.success)
           | ["update"] => (update (); OS.Process.success)
           | ["search",pkg] => (search pkg ""; OS.Process.success)
           | ["search",pkg,ver] => (search pkg ver; OS.Process.success)
           | ["source",pkg,prot,url] => (source pkg prot url; OS.Process.success)
           | ["install",pkg,ver] => (install pkg ver; OS.Process.success)
           | ["install",pkg] => (install pkg ""; OS.Process.success)
           | ["uninstall",pkg,ver] => (uninstall pkg ver; OS.Process.success)
           | ["uninstall",pkg] => (uninstall pkg ""; OS.Process.success)
           | ["list"] => (listInstalled(); OS.Process.success)
           | _ => (printUsage(); OS.Process.failure)
       end handle (SmackExn s) => 
           (TextIO.output (TextIO.stdErr, s ^ "\n"); OS.Process.failure)
end

val _ = OS.Process.exit(Smack.main())

