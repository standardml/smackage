structure Smack =
struct
    exception SmackExn of string

    (* gian - I think it might be worth distinguishing where a .smackage 
     * configuration
     * file lives (maybe have a stateful Configure struct with defaults, in
     * case there's no such file) from the place where smackage code goes.
     * Course, if we can figure out where the directory is, we can just have
     * such a hypothetical config file go in $(SMACKAGE_HOME)/config, so 
     * that would work too... -rjs 2:30am est, SML hack day *)

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

    (** Parse the versions.smackspec file to produce a list of available
        (package,version,protocol) triples. *)
    fun parseVersionsSpec () =
    let
        val fp = TextIO.openIn (smackHome ^ "/versions.smackspec")
                    handle _ => raise Fail 
                        ("Cannot open `$SMACKAGE_HOME/versions.smackspec'. " ^ 
                         "Try running `smack refresh' to update this file.")

        val stanza = ref "";
        
        fun readStanzas () = 
        let
            val line = TextIO.inputLine fp
        in
            if line = NONE then [!stanza] else
            if line = SOME "\n"
                then (!stanza before stanza := "") :: readStanzas ()
                else (stanza := (!stanza) ^ (valOf line); readStanzas ())
        end

        val stanzas = readStanzas () handle _ => (TextIO.closeIn fp; [])

        val _ = TextIO.closeIn fp
    in
        map (Spec.toVersionSpec o Spec.fromString) stanzas
    end

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
        val _ = SmackLib.install smackHome (name,ver)
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

    fun printUsage () =
        (print "Usage: smackage <command> [args]\n";
         print " Commands:\n";
         print "\thelp\t\t\t\tDisplay this usage and exit\n";
         print "\tinfo <name> [version]\t\tDisplay package information.\n";
         print "\tinstall <name> [version]\tInstall the named package\n";
         print "\tlist\t\t\t\tList installed packages\n";
         print "\trefresh\t\t\t\tRefresh the versions.smackspec index\n";
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
        | ["refresh"] => (OS.Process.success)
        | ["install",pkg,ver] => (install pkg ver; OS.Process.success)
        | ["install",pkg] => (install pkg ""; OS.Process.success)
        | ["uninstall",pkg,ver] => (uninstall pkg ver; OS.Process.success)
        | ["uninstall",pkg] => (uninstall pkg ""; OS.Process.success)
        | ["list"] => (listInstalled(); OS.Process.success)
        | _ => (printUsage(); OS.Process.failure)
    handle (SmackExn s) => 
        (TextIO.output (TextIO.stdErr, s ^ "\n"); OS.Process.failure)
end

val _ = OS.Process.exit(Smack.main())

