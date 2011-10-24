structure Smack =
struct
    exception SmackExn of string

    infix 5 //
    fun (dir // file) = OS.Path.joinDirFile { dir = dir, file = file }

    (** Resolve the dependencies of a particular, newly-downloaded package.
        XXX this should eventually be factored into another module that
        does more intelligent checking to see if existing versions (that aren't 
        the most recent but that have the virtue of being installed) will do. *)
    fun resolveDependencies pkg ver = 
    let exception NoDeps in let
       val specFile = 
          !Configure.smackHome // "lib" // pkg // ("v" ^ SemVer.toString ver)
          // (pkg ^ ".smackspec")
       val () = if OS.FileSys.access (specFile, []) then () else raise NoDeps
  
       val deps = Spec.requires (Spec.fromFile specFile)
       val ltoi = Int.toString o length
    in
       ( if null deps then raise NoDeps else ()
       ; if length deps = 1 then print "Resolving 1 dependency\n"
         else print ("Resolving " ^ ltoi deps ^ "dependencies\n")
       ; app (fn (pkg, spec) => install pkg (SOME spec)) deps
       ; print ("Done resolving dependencies for `" ^ pkg ^ "`\n"))
    end handle NoDeps => () end

    (** Install a package with a given name and version specification.
        NONE means "the latest version", and specifications are handled by
        SemVer.intelligentSelect.
        raises SmackExn in the event that the package is already installed or
        if no such package or version is found. *)
    and install pkg specStr =
    let
        val () =
           if VersionIndex.isKnown pkg then ()
           else raise SmackExn 
                         ( "I don't know about the package `" ^ pkg
                         ^ "`, run 'smackage selfupdate'?")

        val (spec, ver) = 
           VersionIndex.getBest pkg specStr
           handle _ => 
           raise SmackExn 
                 ("No acceptable version of `" ^ pkg
                 ^ (case specStr of
                       NONE => "" 
                     | SOME s => " " ^ SemVer.constrToString s)
                 ^ "` found, try 'smackage refresh'?")

        val name = pkg ^ " " ^ SemVer.toString ver
        val _ = 
           if not (Option.isSome specStr)
           then print ( "No major version specified, picked v" 
                      ^ SemVer.constrToString spec ^ ".\n"
                      ^ "Selected `" ^ name ^ "`.\n")
           else print ( "Selected `" ^ name ^ "`\n")
       
        val proto = 
            case VersionIndex.getProtocol pkg ver of
                SOME p => p
              | NONE => raise SmackExn 
                ("Installation method for `" ^ name ^ "` not found")
    in
        if SmackLib.download (!Configure.smackHome) (pkg,ver,proto)
        then print ( "Package `" ^ name ^ "` already installed.\n") 
        else ( print ( "Package `" ^ name ^ "` downloaded.\n")
             ; resolveDependencies pkg ver)
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
    fun listInstalled () = 
       let
          val libRoot = !Configure.smackHome // "lib"
          fun printver ver = 
             print ("   Version: " ^ SemVer.toString ver ^ "\n")
          fun read dir = 
             case OS.FileSys.readDir dir of 
                NONE => OS.FileSys.closeDir dir
              | SOME pkg => 
                   ( print ("Package " ^ pkg ^ ":")
                   ; case SmackLib.versions (!Configure.smackHome) pkg of
                        [] => print " (no versions installed)\n"
                      | vers => (print "\n"; app printver vers)
                   ; read dir)
       in 
          if OS.FileSys.access (libRoot, [])
          then read (OS.FileSys.openDir libRoot) 
          else ()
       end


    (** Search for a package in the index, with an optional version.
        FIXME: currently ignoring version.
    *)
    fun search name version =
    let
        val _ = VersionIndex.init (!Configure.smackHome)
        val res = VersionIndex.search name
        val _ = if length res = 0 then print "No packages found.\n" else ()
        val _ = List.app 
            (fn (n,v,p) => 
                print (n ^ " " ^ SemVer.toString v ^ " (from " ^ 
                    Protocol.toString p ^ ")\n")) res
    in
        ()
    end

    (** Display metadata for a given package, plus installed status.
        FIXME: Doesn't really do this, but displaying all versions is a start.
    *)
    fun info name version = 
    let
        val _ = print "Candidates:\n"
        val candidates = VersionIndex.getAll name NONE
        val _ = List.app 
            (fn v => 
             let
                 val _ = print (name ^ " " ^ SemVer.toString v)
                 val s = SOME (SmackagePath.packageMetadata 
                            (!Configure.smackHome) (name,v)) 
                            handle (Spec.SpecError s) => 
                                (print ("Spec Error: " ^ s ^ "\n"); NONE)
                                 | (SmackagePath.Metadata s) => NONE

                 val _ = case s of NONE => print "\n\n" 
                                 | SOME sp =>
                                    print (" (installed)\n\n" ^
                                        Spec.toString sp ^ "\n")
             in () end) candidates 
    in
        ()
    end

    (* Hey, what does update do? *)
    fun update () = raise SmackExn "Not implemented"

    (* utility function - read a line from a file and get the source spec *)
    fun getLine file = 
       case Option.map 
              (String.tokens Char.isSpace) 
              (TextIO.inputLine file) of              
          NONE => NONE
        | SOME [] => getLine file
        | SOME [ pkg', prot', uri' ] =>
             SOME (pkg', Protocol.fromString (prot' ^ " " ^ uri'))
        | SOME s => raise Fail ( "Bad source line: " 
                               ^ String.concatWith " " s)

    (* Referesh the versions.smackspec file *)
    (* XXX this should notice when there is a redundant source in different
     * (or the same) sources file, issue a warning, and then pick only the
     * latter source definition, but we'll want string maps for that *)
    fun refresh () = 
       let val oldDir = OS.FileSys.getDir () in
       let 
          val () = OS.FileSys.chDir (!Configure.smackHome) 

          val versionSpackspec = "versions.smackspec"
          val output = TextIO.openOut versionSpackspec
      
          fun emit s = TextIO.output (output, s)
          fun emitSpec pkg prot ver =
             ( emit ("provides: " ^ pkg ^ " " ^ SemVer.toString ver ^ "\n")
             ; emit ("remote: " ^ Protocol.toString prot ^ "\n\n"))

          fun poll fileName (pkg, prot) =
             app (emitSpec pkg prot) (Conductor.poll prot)
             handle exn => (* Why is this not getting called? *)
                print ("WARNING: When trying to poll `" ^ pkg
                      ^ "`, got the following error \n\t\""
                      ^ exnMessage exn 
                      ^ "\"\nYou may need to run 'smackage unsource " 
                      ^ pkg ^ "'\n")

          fun read fileName file = 
             case getLine file of
                NONE => TextIO.closeIn file
              | SOME s => (poll fileName s; read fileName file)

          fun dofile fileName = 
             read fileName (TextIO.openIn fileName) 
             handle _ => print ("WARNING: error reading " ^ fileName ^ "\n")
       in
          ( app dofile (!Configure.smackSources @ [ "sources.local" ])
          ; TextIO.closeOut output
          ; OS.FileSys.chDir oldDir
          ; VersionIndex.init (!Configure.smackHome))
       end handle exn => (OS.FileSys.chDir oldDir; raise exn) end

    fun selfupdate () = 
       ( refresh ()
       ; install "smackage" (SOME (SemVer.constrFromString "v0"))
       ; refresh ())

    (* Manipulate the sources.local source spec file *)
    fun modsource pkg maybe_prot =  
       let 
          val sourcesLocal = 
             OS.Path.joinDirFile { dir = !Configure.smackHome
                                 , file = "sources.local"}
          val file = TextIO.openIn sourcesLocal

          fun notfound () =
             raise SmackExn ( "WARNING: Package `" ^ pkg 
                            ^ "` not in sources.local.")

          fun read_big accum = 
             case getLine file of 
                NONE => List.rev accum 
              | SOME line => read_big (line :: accum)

          fun read_small accum = 
             case getLine file of
                NONE => 
                (case maybe_prot of 
                    NONE => notfound ()
                  | SOME prot => List.rev ((pkg, prot) :: accum))
              | SOME (pkg', prot') => 
                (case String.compare (pkg, pkg') of
                    LESS => 
                    (case maybe_prot of 
                        NONE => notfound ()
                      | SOME prot => 
                           read_big ((pkg', prot') :: (pkg, prot) :: accum))
                  | EQUAL => 
                    (case maybe_prot of 
                        NONE =>  
                           ( print ("Deleting source spec " ^ pkg ^ "...\n")
                           ; read_big accum)
                      | SOME prot => 
                           ( print ("WARNING: overwriting source spec\n\
                                \OLD: " ^ pkg' ^ Protocol.toString prot' ^ "\n\
                                \NEW: " ^ pkg ^ Protocol.toString prot ^ "\n")
                           ; read_big ((pkg, prot) :: accum)))
                  | GREATER => read_small ((pkg', prot') :: accum))

          val sources = read_small [] before TextIO.closeIn file

          val file = TextIO.openOut sourcesLocal

          fun write [] = TextIO.closeOut file
            | write ((pkg, prot) :: sources) = 
              ( TextIO.output (file, pkg ^ " " ^ Protocol.toString prot ^ "\n")
              ; write sources)
       in
          ( write sources
          ; print "Done rewriting sources.local.\n\
                  \You probably want to run 'smackage refresh' now.\n")
       end

    fun printUsage () =
        (print "Usage: smackage <command> [args]\n";
         print " Commands:\n";
         print "\thelp\t\t\t\tDisplay this usage and exit\n";
         print "\tinfo <name> [version]\t\tDisplay package information.\n";
         print "\tinstall <name> [version]\tInstall the named package\n";
         print "\tlist\t\t\t\tList installed packages\n";
         print "\trefresh\t\t\t\tRefresh the package index\n";
         print "\tsearch <name>\t\t\tFind an appropriate package\n";
         print "\tselfupdate\t\t\tUpdate smackage\n";
         print "\tsource <name> <protocol> <url>\tAdd a smackage source to sources.local\n";
         print "\tunsource <name>\t\t\tRemove a source from sources.local\n";
         print "\tuninstall <name> [version]\tRemove a package\n"
         )

    fun main (name, args) = 
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
                ( modsource pkg (SOME (Protocol.fromString (prot ^ " " ^ url)))
                ; OS.Process.success)
           | ["unsource",pkg] => 
                ( modsource pkg NONE
                ; OS.Process.success)
           | ["selfupdate"] => (selfupdate (); OS.Process.success)
           | ["refresh"] => (refresh (); OS.Process.success)
           | ["install",pkg,ver] => 
                ( install pkg (SOME (SemVer.constrFromString ver))
                ; OS.Process.success)
           | ["install",pkg] => (install pkg NONE; OS.Process.success)
           | ["uninstall",pkg,ver] => (uninstall pkg ver; OS.Process.success)
           | ["uninstall",pkg] => (uninstall pkg ""; OS.Process.success)
           | ["list"] => (listInstalled(); OS.Process.success)
           | _ => (printUsage(); OS.Process.failure)
       end handle (SmackExn s) => 
           (TextIO.output (TextIO.stdErr, s ^ "\n"); OS.Process.failure)
                | (Fail s) => 
           (TextIO.output (TextIO.stdErr, s ^ "\n"); OS.Process.failure)
                | exn =>
           (TextIO.output (TextIO.stdErr, "UNEXPECTED ERROR: " 
                                          ^ exnMessage exn ^ "\n")
           ; OS.Process.failure)
end


