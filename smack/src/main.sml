structure Smack =
struct
    exception SmackExn of string

    (** Parse the versions.smackspec file to produce a list of available
        (package,version,protocol) triples. *)
    fun parseVersionsSpec () =
    let
        val versions = 
           OS.Path.joinDirFile { dir = !Configure.smackHome,
                                 file = "versions.smackspec" } 
        val fp = TextIO.openIn versions
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

    fun newsource pkg prot uri =  
       let 
          val prot = Protocol.fromString (prot ^ " " ^ uri)
          val sourcesLocal = 
             OS.Path.joinDirFile { dir = !Configure.smackHome
                                 , file = "sources.local"}
          val file = TextIO.openIn sourcesLocal

          fun getLine () = 
             case Option.map 
                    (String.tokens Char.isSpace) 
                    (TextIO.inputLine file) of              
                NONE => NONE
              | SOME [] => getLine ()
              | SOME [ pkg', prot', uri' ] =>
                   SOME (pkg', Protocol.fromString (prot' ^ " " ^ uri'))
              | SOME s => raise Fail ( "Bad source line: " 
                                     ^ String.concatWith " " s)

          fun read_big accum = 
             case getLine () of 
                NONE => List.rev accum
              | SOME line => read_big (line :: accum)

          fun read_small accum = 
             case getLine () of
                NONE => List.rev ((pkg, prot) :: accum)
              | SOME (pkg', prot') => 
                (case String.compare (pkg, pkg') of
                    LESS => 
                      read_big ((pkg', prot') :: (pkg, prot) :: accum)
                  | EQUAL => 
                      ( print ("WARNING: overwriting old source specification\n\
                              \OLD: " ^ pkg' ^ Protocol.toString prot' ^ "\n\
                              \NEW: " ^ pkg ^ Protocol.toString prot ^ "\n")
                      ; read_big ((pkg, prot) :: accum))
                  | GREATER => 
                      read_small ((pkg', prot') :: accum))

          val sources = read_small []

          val file = TextIO.openOut sourcesLocal

          fun write [] = TextIO.closeOut file
            | write ((pkg, prot) :: sources) = 
              ( TextIO.output (file, pkg ^ " " ^ Protocol.toString prot ^ "\n")
              ; write sources)
       in
          write sources
       end

    fun printUsage () =
        (print "Usage: smackage <command> [args]\n";
         print " Commands:\n";
         print "\thelp\t\t\t\tDisplay this usage and exit\n";
         print "\tinfo <name> [version]\t\tDisplay package information.\n";
         print "\tinstall <name> [version]\tInstall the named package\n";
         print "\tlist\t\t\t\tList installed packages\n";
         print "\trefresh\t\t\t\tRefresh the versions.smackspec index\n";
         print "\tsearch <name>\t\t\tFind an appropriate package\n";
         print "\tsource <name> <protocol> <url>\t\t\tAdd a smackage source\n";
         print "\tuninstall <name> [version]\tRemove a package\n";
         print "\tupdate\t\t\t\tUpdate the package database\n");

    fun main args = 
       let
          val () = Configure.init ()
       in
          case args of
             ("--help"::_) => (printUsage(); OS.Process.success)
           | ("-h"::_) => (printUsage(); OS.Process.success)
           | ("help"::_) => (printUsage(); OS.Process.success)
           | ["info",pkg,ver] => (info pkg ver; OS.Process.success)
           | ["info",pkg] => (info pkg ""; OS.Process.success)
           | ["update"] => (update (); OS.Process.success)
           | ["search",pkg] => (search pkg ""; OS.Process.success)
           | ["search",pkg,ver] => (search pkg ver; OS.Process.success)
           | ["source",pkg,prot,url] => 
                (newsource pkg prot url; OS.Process.success)
           | ["refresh"] => (OS.Process.success)
           | ["install",pkg,ver] => (install pkg ver; OS.Process.success)
           | ["install",pkg] => (install pkg ""; OS.Process.success)
           | ["uninstall",pkg,ver] => (uninstall pkg ver; OS.Process.success)
           | ["uninstall",pkg] => (uninstall pkg ""; OS.Process.success)
           | ["list"] => (listInstalled(); OS.Process.success)
           | _ => (printUsage(); OS.Process.failure)
       end handle (SmackExn s) => 
           (TextIO.output (TextIO.stdErr, s ^ "\n"); OS.Process.failure)
                | (Fail s) => 
           (TextIO.output (TextIO.stdErr, s ^ "\n"); OS.Process.failure)
end

val _ = OS.Process.exit(Smack.main(CommandLine.arguments ()))

