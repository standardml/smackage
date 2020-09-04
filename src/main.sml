structure Smack =
struct
    exception SmackExn of string

    infix 5 //
    fun (dir // file) = OS.Path.joinDirFile { dir = dir, file = file }

    type packages = unit SemConstrDict.dict StringDict.dict

    fun addPackage (dict: packages) pkg semconstr =
       StringDict.insertMerge dict pkg
          (SemConstrDict.singleton semconstr ())
          (fn dict => SemConstrDict.insert dict semconstr ())

    fun readPackagesInstalled (): packages =
    let
       val packagesInstalled =
          OS.Path.joinDirFile { dir = !Configure.smackHome
                              , file = "packages.installed"}
       fun folder (line, dict) =
          case String.tokens Char.isSpace line of
             [] => dict
           | [ pkg, semconstr ] =>
                addPackage dict pkg (SemVer.constrFromString semconstr)
           | _ => raise Fail ( "Bad package line: `" ^ line ^ "'")
    in
       List.foldr folder StringDict.empty
          (FSUtil.getCleanLines (TextIO.openIn packagesInstalled))
    end

    fun writePackagesInstalled (dict: packages) =
    let
       val packagesInstalled =
          OS.Path.joinDirFile { dir = !Configure.smackHome
                              , file = "packages.installed"}
       fun mapper (pkg, semconstrs) =
          map (fn (sc, ()) => pkg ^ " " ^ SemVer.constrToString sc)
             (SemConstrDict.toList semconstrs)
    in
       FSUtil.putLines packagesInstalled
          (  "# This file was automatically generated by smackage."
          :: "# It holds every package explicitly installed by the user with a"
          :: "# `smackage install' command, and determines which packages are"
          :: "# accessed and directly updated by `smackage update'."
          :: ""
          :: List.concat (map mapper (StringDict.toList dict)))
    end


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
         else print ("Resolving " ^ ltoi deps ^ " dependencies\n")
       (* XXX here's the place to shortcut-stop if we have an acceptable
        * version installed (issue #4) *)
       ; app (fn (pkg, spec, _) =>
            ignore (get false false pkg (SOME spec))) deps
       ; print ("Done resolving dependencies for `" ^ pkg ^ "'\n"))
    end handle NoDeps => () end

    (** Obtain a package with a given name and version specification.
        NONE means "the latest version." Specifications are handled by
        SemVer.intelligentSelect.

        Raises SmackExn in the event that no acceptable version of the package
        is available.

        silentMode tells 'get' to not report what it is doing assuming
        everything is going well. This allows us to have 'refresh'
        not output confusing messages about selecting smackage versions.

        *)
    and get silentMode isTopLevel pkg specStr =
    let
        fun maybePrint s = if silentMode then () else print s

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

        val () =
           if not isTopLevel then ()
           else writePackagesInstalled
                   (addPackage (readPackagesInstalled ()) pkg spec)

        val name = pkg ^ " " ^ SemVer.toString ver
        val () =
           if Option.isSome specStr then ()
           else print ( "No major version specified, picked v"
                      ^ SemVer.constrToString spec ^ ".\n")
        val () = maybePrint ( "Selected `" ^ name ^ "'.\n")

        val proto =
            case VersionIndex.getProtocol pkg ver of
                SOME p => p
              | NONE => raise SmackExn
                ("Installation method for `" ^ name ^ "' not found")
    in
     ( if SmackLib.download (!Configure.smackHome) (pkg,ver,proto)
       then maybePrint ( "Package `" ^ name ^ "' already installed.\n")
       else ( maybePrint ( "Package `" ^ name ^ "' downloaded.\n")
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

    (** Ouput a path for a given package, for integration with smbt.
        It is important for smbt's purposes that indicative status
        codes are returned, so we return OS.Process.success
        or OS.Process.failure here. **)
    fun pathinfo pkg spec =
    let
        val ver = SemVer.constrFromString spec
        val (spec, semver) =
          case SemVer.intelligentSelect (SOME ver)
                  (SmackLib.versions (!Configure.smackHome) pkg) of
                NONE =>
                    raise SmackExn
                      ("No acceptable version of `" ^ pkg
                      ^ (SemVer.constrToString ver)
                      ^ "' around, try getting one with `smackage get'?")
              | SOME (spec, semver) => (spec, semver)

        val specStr = "v" ^ SemVer.toString semver

        val path = (!Configure.smackHome // "lib" // pkg // specStr)

    in
        if OS.FileSys.access (path, []) then
            (print (path ^ "\n"); OS.Process.success)
        else
            (print ("Smackage: No acceptable version of `" ^ pkg ^ "\n"); OS.Process.failure)
    end

    fun update () =
    let
       val pkgs = readPackagesInstalled ()

       fun update1 (pkg, vers) =
          SemConstrDict.app
             (fn (semconst, _) => ignore (get false false pkg (SOME semconst)))
             vers

       fun reportBest (pkg, _) =
       let
          val (_, semver) = VersionIndex.getBest pkg NONE
       in
          if SmackLib.exists (!Configure.smackHome) (pkg, semver) then ()
          else print ("NOTICE: `" ^ pkg ^ " v" ^ SemVer.toString semver
                      ^ "' is available, run `smackage get "
                      ^ pkg ^ "' to get it.\n")
       end
    in
     ( if not (StringDict.isEmpty pkgs) then ()
       else print "Nothing to update!\nPerhaps you should use\
                  \ `smackage get <package>' to get something first?\n"
     ; StringDict.app update1 pkgs
     ; StringDict.app reportBest pkgs
     ; OS.Process.success)
    end

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


    fun runCmd pkg spec args =
    let
       val oldDir = OS.FileSys.getDir ()
       val (spec, semver) =
          case SemVer.intelligentSelect spec
                  (SmackLib.versions (!Configure.smackHome) pkg) of
             NONE =>
                raise SmackExn
                      ("No acceptable version of `" ^ pkg
                      ^ (case spec of
                            NONE => ""
                          | SOME s => " " ^ SemVer.constrToString s)
                      ^ "' around, try getting one with `smackage get'?")
           | SOME (spec, semver) => (spec, semver)
       val specStr = "v" ^ SemVer.toString semver
       val cmd = String.concatWith " " args
    in
     ( OS.FileSys.chDir (!Configure.smackHome // "lib" // pkg // specStr)
     ; print ("In directory: `" ^ OS.FileSys.getDir () ^ "'\n")
     ; print ("smackage is preparing to run `" ^ cmd ^ "'\n")
     ; OS.Process.system cmd
     ; OS.FileSys.chDir oldDir
     ; OS.Process.success)
    handle exn => (OS.FileSys.chDir oldDir; raise exn)
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
                ^ "', got the following error \n\t\""
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
       ; ignore (get true false "smackage" (SOME (SemVer.constrFromString "v1")))
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
       "Smackage " ^ Version.version ^ "\n" ^
       "Usage: smackage <command> [args]\n\
       \Commands, with <required> and [optional] arguments:\n\
       \\texec <name> [version] <cmd ...>\tRuns `cmd ...' in the specified\n\
       \\t\t\t\t\tpackage's directory\n\
       \\tget <name> [version]\t\tObtain the named package\n\
       \\thelp\t\t\t\tDisplay this usage and exit\n\
       \\tinfo <name> [version]\t\tDisplay package information.\n\
       \\tlist\t\t\t\tList installed packages\n\
       \\tmake <name> [version] [args...]\tRuns `make [args ...]' in the\n\
       \\t\t\t\t\tspecified package's directory\n\
       \\tpathinfo <name> <version>\tOutputs <name>'s filesystem path\n\
       \\trefresh\t\t\t\tRefresh the package index\n\
       \\tsearch <name>\t\t\tFind an appropriate package\n\
       \\tsource <name> <protocol> <url>\tAdd a smackage source to sources.local\n\
       \\tupdate \t\t\t\tUpdate all packages\n\
       \\tunsource <name>\t\t\tRemove a source from sources.local\n"

    exception ArgsError of string * string
    fun main (name, args) =
       let
          val () = Configure.init ()
          fun runCmdNotMake pkg spec rest =
          let
             fun confirm () =
             let
                val () = print ("Are you sure you want to proceed? [Y/n]: ")
                val () = TextIO.flushOut TextIO.stdOut
             in case String.tokens Char.isSpace
                        (valOf (TextIO.inputLine TextIO.stdIn)) of
                   [] => ()
                 | (str :: _) =>
                      if String.isPrefix "y" str
                         orelse String.isPrefix "Y" str
                      then ()
                      else if String.isPrefix "n" str
                           orelse String.isPrefix "N" str
                      then raise SmackExn "User cancelled command"
                      else (print "I don't understand that.\n"; confirm ())
             end
          in
           ( if "make" = hd rest
             then ( print ("WARNING: It is suggested that you run\n\
                          \`" ^ CommandLine.name () ^ " make "
                          ^ String.concatWith " " (pkg :: tl rest)
                          ^ "'\nrather than invoking make with `"
                          ^ CommandLine.name () ^ " exec'.\n")
                  ; confirm ())
             else ()
           ; runCmd pkg spec rest)
          handle Option => raise SmackExn "User cancelled command"
          end
       in
          case args of
             [] => (print usage; OS.Process.success)
           | ("--help"::_) => (print usage; OS.Process.success)
           | ("-h"::_) => (print usage; OS.Process.success)
           | ("help"::_) => (print usage; OS.Process.success)

           | ["exec", pkg, cmd] => runCmdNotMake pkg NONE [ cmd ]
           | ("exec" :: pkg :: maybe_spec :: rest) =>
             let
                val (spec, rest) =
                   (SOME (SemVer.constrFromString maybe_spec), rest)
                handle _ => (NONE, maybe_spec :: rest)
              in runCmdNotMake pkg spec rest
              end
           | ("exec" :: _) =>
                raise ArgsError ("exec", "requires at least two arguments")

           | ["get",pkg] => get false true pkg NONE
           | ["get",pkg,ver] =>
                get false true pkg (SOME (SemVer.constrFromString ver))
           | ("get" :: _) =>
                raise ArgsError ("get", "requires one or two arguments")

           | ["info",pkg] => (info pkg ""; OS.Process.success)
           | ["info",pkg,ver] => (info pkg ver; OS.Process.success)
           | ("info" :: _) =>
                raise ArgsError ("info", "requires one or two arguments")

           | ("install" :: args) =>
                raise ArgsError ("install", "not a command\n\
                   \Did you want to run `" ^ CommandLine.name () ^ " get "
                   ^ String.concatWith " " args ^ "'?")

           | ["list"] => (listInstalled(); OS.Process.success)
           | ("list" :: _) =>
                raise ArgsError ("list", "does not expect arguments")

           | ["pathinfo"] =>
                raise ArgsError ("pathinfo", "requires two arguments")
           | ["pathinfo",pkg,ver] => pathinfo pkg ver

           | ["make"] => raise ArgsError ("make", "requires arguments")
           | ["make", pkg] =>
                runCmd pkg NONE [ "make", "DESTDIR=" ^ !Configure.smackHome]
           | ("make" :: pkg :: maybe_spec :: rest) =>
             let
                val (spec, rest) =
                   (SOME (SemVer.constrFromString maybe_spec), rest)
                handle _ => (NONE, maybe_spec :: rest)
             in
                runCmd pkg spec
                   ("make" :: "DESTDIR=" ^ !Configure.smackHome :: rest)
             end

           | ["refresh"] => selfupdate ()
           | ("refresh" :: _) =>
                raise ArgsError ("refresh", "does not expect arguments")

           | ["search",pkg] => (search pkg ""; OS.Process.success)
           | ["search",pkg,ver] => (search pkg ver; OS.Process.success)
           | ("search" :: _) =>
                raise ArgsError ("search", "expects one or two arguments")

           | ["source",pkg,prot,url] =>
                source pkg (Protocol.fromString (prot ^ " " ^ url))
           | ("source" :: _) =>
                raise ArgsError ("source", "expects exactly three arguments")

           | ["update"] => update ()
           | ("update" :: args) =>
                raise ArgsError ("update", "does not expect arguments\n\
                   \Did you want to run `" ^ CommandLine.name () ^ " get "
                   ^ String.concatWith " " args ^ "'?")

           | ["unsource",pkg] => unsource pkg
           | ("unsource" :: _) =>
                raise ArgsError ("unsource", "expectes exactly one argument")

           | (str :: _) => raise ArgsError (str, "is an unknown command")
       end handle
              (SmackExn s) =>
                ( TextIO.output (TextIO.stdErr, "\nERROR: " ^ s ^ "\n\n")
                ; OS.Process.failure)
            | (Fail s) =>
                ( TextIO.output (TextIO.stdErr, "\nERROR: " ^ s ^ "\n\n")
                ; OS.Process.failure)
            | (Spec.SpecError s) =>
                ( TextIO.output (TextIO.stdErr, "\nERROR: " ^ s ^ "\n\n")
                ; OS.Process.failure)
            | (ArgsError (cmd, s)) =>
                ( TextIO.output (TextIO.stdErr, "\nERROR: `"
                                          ^ CommandLine.name ()
                                          ^ " " ^ cmd ^ "' " ^ s ^ "\n\n")
                ; print usage
                ; OS.Process.failure)
            | exn =>
                ( TextIO.output (TextIO.stdErr, "\nUNEXPECTED ERROR: "
                                          ^ exnMessage exn ^ "\n\n")
                ; OS.Process.failure)
end


