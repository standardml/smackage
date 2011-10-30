structure Smack =
struct
    exception SmackExn of string

    infix 5 //
    fun (dir // file) = OS.Path.joinDirFile { dir = dir, file = file }

    (** Resolve the dependencies of a particular, newly-downloaded package. *)
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
       (* XXX here's the place to shortcut-stop if we have an acceptable
        * version installed (issue #4) *)
       ; app (fn (pkg, spec, _) => ignore (get pkg (SOME spec))) deps 
       ; print ("Done resolving dependencies for `" ^ pkg ^ "'\n"))
    end handle NoDeps => () end

    (** Obtain a package with a given name and version specification.
        NONE means "the latest version." Specifications are handled by
        SemVer.intelligentSelect.

        Raises SmackExn in the event that no acceptable version of the package
        is available. *)
    and get pkg specStr =
    let
        val () =
           if VersionIndex.isKnown pkg then ()
           else raise SmackExn 
                         ( "I don't know about the package `" ^ pkg
                         ^ "', run `smackage refresh'?")

        val (spec, ver) = 
           VersionIndex.getBest pkg specStr
           handle _ => 
           raise SmackExn 
                   ("No acceptable version of `" ^ pkg
                   ^ (case specStr of
                         NONE => "" 
                       | SOME s => " " ^ SemVer.constrToString s)
                   ^ "' found, try `smackage refresh'?")

        val name = pkg ^ " " ^ SemVer.toString ver
        val () = 
           if Option.isSome specStr then ()
           else print ( "No major version specified, picked v" 
                      ^ SemVer.constrToString spec ^ ".\n")
        val () = print ( "Selected `" ^ name ^ "'.\n")
       
        val proto = 
            case VersionIndex.getProtocol pkg ver of
                SOME p => p
              | NONE => raise SmackExn 
                ("Installation method for `" ^ name ^ "' not found")
    in
     ( if SmackLib.download (!Configure.smackHome) (pkg,ver,proto)
       then print ( "Package `" ^ name ^ "' already installed.\n") 
       else ( print ( "Package `" ^ name ^ "' downloaded.\n")
            ; resolveDependencies pkg ver (*
             ; (if runHooks then
                (SmackLib.build 
                (!Configure.smackHome) 
                (!Configure.platform,!Configure.compilers)
                (pkg,ver)
              ; SmackLib.install
                (!Configure.smackHome)
                (!Configure.platform,!Configure.compilers)
                (pkg,ver)) else ())
             *))
     ; OS.Process.success)
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
            (fn (n,dict) =>
                SemVerDict.app 
                   (fn (v, p) =>  
                       print (n ^ " " ^ SemVer.toString v ^ " (from " ^ 
                              Protocol.toString p ^ ")\n")) dict) res
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



    fun readSourcesLocal () = 
    let 
       val sourcesLocal = 
          OS.Path.joinDirFile { dir = !Configure.smackHome
                              , file = "sources.local"}
       fun folder (line, dict) = 
          case String.tokens Char.isSpace line of 
             [] => dict
           | [ pkg', prot', uri' ] => 
                StringDict.insert dict pkg'
                   (Protocol.fromString (prot' ^ " " ^ uri'))
           | _ => raise Fail ( "Bad source line: `" ^ line ^ "'")
    in
       List.foldr folder StringDict.empty
          (FSUtil.getCleanLines (TextIO.openIn sourcesLocal))
    end

    fun writeSourcesLocal dict = 
    let
       val sourcesLocal = 
          OS.Path.joinDirFile { dir = !Configure.smackHome
                              , file = "sources.local"}
    in
       FSUtil.putLines sourcesLocal
          (  "# This file was automatically generated by smackage."
          :: "# You can edit it directly or edit it with the smackage tool:"
          :: "# `smackage source <sourcename> <protocol>' adds a source, and"
          :: "# `smackage unsource <sourcename>' removes a source."
          :: ""
          :: map (fn (source, prot) => source ^ " " ^ Protocol.toString prot)
                (StringDict.toList dict))
    end



    (* Referesh the versions.smackspec file based one existing sources. *)
    fun refresh warn = 
    let val oldDir = OS.FileSys.getDir () in
    let 
       val () = OS.FileSys.chDir (!Configure.smackHome) 

       val versionSpackspec = "versions.smackspec"
       val output = TextIO.openOut versionSpackspec
      
       fun emit s = TextIO.output (output, s)

       fun poll line =
       let in 
          case String.tokens Char.isSpace line of 
             [] => ()
           | [ pkg', prot', uri' ] => 
                app (fn spec => emit (Spec.toString spec ^ "\n\n"))
                   (Conductor.poll pkg' 
                     (Protocol.fromString (prot' ^ " " ^ uri')))
           | _ => raise Fail ( "Bad source line: `" ^ line ^ "'")
       end
       handle exn => 
          print ("WARNING: When trying to pull source `" ^ line
                ^ "`, got the following error \n\t\""
                ^ exnMessage exn 
                ^ "\"\nIf this line is in sources.local, you may need to run\n\
                \`smackage unsource' to remove it.\n")

       fun dofile fileName = 
          app poll (FSUtil.getCleanLines (TextIO.openIn fileName))
       handle _ => if not warn then ()
                   else print ("WARNING: error reading " ^ fileName ^ "\n")
    in
     ( app dofile (!Configure.smackSources @ [ "sources.local" ])
     ; TextIO.closeOut output
     ; OS.FileSys.chDir oldDir
     ; VersionIndex.init (!Configure.smackHome))
    end handle exn => (OS.FileSys.chDir oldDir; raise exn) end

    (* We should think about whether there's a better way to distributed
       the "blessed" sources list to separate "selfupdate" from 
       "refresh." As it is, I can't really figure out a less-wasteful way
       to do a "total" refresh than to re-download smackage's sources. *)
    fun selfupdate () = 
       ( refresh false
       ; ignore (get "smackage" (SOME (SemVer.constrFromString "v0")))
       ; refresh true
       ; OS.Process.success)


    (* Manipulate the sources.local source spec file *)
    fun source pkg prot =  
    let 
       val dict = readSourcesLocal ()
       val dict' = StringDict.insert dict pkg prot
    in
     ( case StringDict.find dict pkg of
          NONE => ()
        | SOME prot' => 
             if EQUAL = Protocol.compare (prot, prot') then ()
             else print ( "WARNING: overwriting source spec\nOLD: "
                        ^ pkg ^ " " ^ Protocol.toString prot' ^ "\nNEW: "
                        ^ pkg ^ " " ^ Protocol.toString prot ^ "\n")
     ; writeSourcesLocal dict'
     ; OS.Process.success)
    end

    (* Manipulate the sources.local source spec file *)
    fun unsource pkg =  
    let 
       val dict = readSourcesLocal ()
       val dict' = StringDict.remove dict pkg
    in
     ( case StringDict.find dict pkg of
          NONE => print ("WARNING: Package `" ^ pkg ^ "' not in sources.local.")
        | SOME prot' => ()
     ; writeSourcesLocal dict'
     ; OS.Process.success)
    end

    val usage =
       "Usage: smackage <command> [args]\n\
       \ Commands:\n\
       \\tget <name> [version]\t\tObtain the named package\n\
       \\thelp\t\t\t\tDisplay this usage and exit\n\
       \\tinfo <name> [version]\t\tDisplay package information.\n\
       \\tlist\t\t\t\tList installed packages\n\
       \\trefresh\t\t\t\tRefresh the package index\n\
       \\tsearch <name>\t\t\tFind an appropriate package\n\
       \\tsource <name> <protocol> <url>\tAdd a smackage source to sources.local\n\
       \\tunsource <name>\t\t\tRemove a source from sources.local\n"

    fun main (name, args) = 
       let
          val () = Configure.init ()
       in
          case args of
             ("--help"::_) => (print usage; OS.Process.success)
           | ("-h"::_) => (print usage; OS.Process.success)
           | ("help"::_) => (print usage; OS.Process.success)

           | ["get",pkg] => get pkg NONE
           | ["get",pkg,ver] => get pkg (SOME (SemVer.constrFromString ver))
           | ["info",pkg,ver] => (info pkg ver; OS.Process.success)
           | ["info",pkg] => (info pkg ""; OS.Process.success)
           | ["list"] => (listInstalled(); OS.Process.success)
           | ["refresh"] => selfupdate ()
           | ["search",pkg] => (search pkg ""; OS.Process.success)
           | ["search",pkg,ver] => (search pkg ver; OS.Process.success)
           | ["source",pkg,prot,url] => 
                source pkg (Protocol.fromString (prot ^ " " ^ url))
           | ["unsource",pkg] => unsource pkg 
           | _ => (print usage; OS.Process.failure)
       end handle (SmackExn s) => 
           (TextIO.output (TextIO.stdErr, s ^ "\n"); OS.Process.failure)
                | (Fail s) => 
           (TextIO.output (TextIO.stdErr, s ^ "\n"); OS.Process.failure)
                | (Spec.SpecError s) => 
           (TextIO.output (TextIO.stdErr, s ^ "\n"); OS.Process.failure)
                | exn =>
           (TextIO.output (TextIO.stdErr, "UNEXPECTED ERROR: " 
                                          ^ exnMessage exn ^ "\n")
           ; OS.Process.failure)
end


