(** Stateful configuration, hopefully with sensible defaults *)
structure Configure =
struct
   fun // (dir, file) = OS.Path.joinDirFile { dir = dir, file = file }
   infix 5 //

   val smackHome = ref "<dummy>"

   val smackSources: string list ref = ref []

   val platform : string ref = ref ""

   val compilers : string list ref = ref []

   (** Attempt to ascertain the smackage home directory.
       Resolved in this order:

       SMACKAGE_HOME environment variable
       /usr/local/smackage/
       /opt/smackage/
       ~/.smackage/
   *)
   fun initSmackHome () = 
   let 
      val getEnv = OS.Process.getEnv
      fun tryDir (SOME s) = ((OS.FileSys.openDir s; true) handle _ => false)
        | tryDir NONE = false
      fun useThisDir dir = 
         if tryDir (SOME dir) then smackHome := dir
         else ( print ( "NOTICE: dir `"
                      ^ dir ^ "' doesn't exist, trying to create it.\n")
              ; OS.FileSys.mkDir dir
                handle _ => raise Fail "Couldn't create home directory"
              ; smackHome := dir)
   in
      if Option.isSome (getEnv "SMACKAGE_HOME")
         then (* $SMACKAGE_HOME is set, definitely go with that. *)
           useThisDir (valOf (getEnv "SMACKAGE_HOME"))
      else if tryDir (SOME "/usr/local/smackage") 
         then smackHome := "/usr/local/smackage" 
      else if tryDir (SOME "/opt/smackage") 
         then smackHome := "/opt/smackage"
      else if Option.isSome (OS.Process.getEnv "HOME")
         then (* $HOME set, we're out of other options. Try ~/.smackage *)
           useThisDir (valOf (getEnv "HOME") // ".smackage")
      else raise Fail "Cannot find smackage home. Try setting SMACKAGE_HOME"
   end

   fun initFile fileName contents = 
      let
         val filePath =
            OS.Path.joinDirFile { dir = !smackHome, file = fileName }

         fun create () = 
            let
               val () = 
                  print ("NOTICE: file `" ^ fileName ^ "' doesn't exist,\
                         \ trying to create it.\n")
               val file = TextIO.openOut filePath
            in
               ( TextIO.output (file, contents)
               ; TextIO.closeOut file)
            end
      in
         if not (OS.FileSys.access (filePath, []))
           then create () else
         if not (OS.FileSys.access (filePath, [ OS.FileSys.A_READ
                                              , OS.FileSys.A_WRITE ]))
           then raise Fail ("Can't read/write to `" ^ fileName
                            ^ "' (run as sudo?)")
         else ()
      end handle exn => 
             ( print ("Error with `" ^ fileName ^ "' file.\n")
             ; raise exn)

   fun initDir dirName = 
      let 
         val dirPath = 
            OS.Path.joinDirFile { dir = !smackHome, file = dirName }
         fun create () = 
            let
               val () = 
                  print ("NOTICE: dir `" ^ dirName ^ "' doesn't exist,\
                         \ trying to create it.\n")
            in
               OS.FileSys.mkDir dirPath
            end
      in
         if not (OS.FileSys.access (dirPath, []))
           then create () else
         if not (OS.FileSys.isDir dirPath)
           then raise Fail ("File `" ^ dirName
                            ^ "' exists and is not a directory")
         else ()
      end

   fun readConfigFile () = 
      let
         val config = OS.Path.joinDirFile { dir = !smackHome, file = "config" }

         fun loop file = 
            case Option.map 
                    (String.tokens Char.isSpace) 
                    (TextIO.inputLine file) of 
               NONE => TextIO.closeIn file
             | SOME [] => loop file
             | SOME [ "source", f ] => 
                  ( smackSources := !smackSources @ [ f ] ; loop file)
             | SOME [ "platform", p ] =>
                  ( platform := p ; loop file)
             | SOME [ "compiler", cmp ] =>
                  ( compilers := !compilers @ [ cmp ] ; loop file)
             | SOME s => 
                  raise Fail ( "Bad configuration line: " 
                             ^ String.concatWith " " s )
      in 
         if not (OS.FileSys.access (config, [])) then () else
         if not (OS.FileSys.access (config, [ OS.FileSys.A_READ ]))
           then raise Fail "Config file exists but can't be read"
         else loop (TextIO.openIn config) 
      end


   (** Attempt to guess an appropriate default 'platform' config value.
       Based on the output of 'uname -s'. Defaults to 'linux' if we can't
       guess, because that's probably safe for most POSIX-compliant systems. *)
   fun guessPlatform () =
      let
         val s = FSUtil.systemCleanLines "uname -s"
      in 
         if null s then "win" else
         if String.isPrefix "Darwin" (hd s) then "osx" else
         if String.isPrefix "CYGWIN" (hd s) then "win" else "linux"
      end

   fun init () =
      ( initSmackHome ()
      ; initFile "sources.local" 
           "smackage git git://github.com/standardml/smackage.git\n"
      ; initFile "config" 
          ("source " ^ ("lib" // "smackage" // "v1" // "sources") ^ "\n\ 
           \compiler mlton\n\
           \compiler smlnj\n\
           \platform " ^ guessPlatform () ^ "\n")
      ; initFile "packages.installed" "smackage v1\n"
      ; initFile "versions.smackspec" "\n"
      ; initDir "lib"
      ; initDir "bin"
      ; readConfigFile ()
      ; VersionIndex.init (!smackHome))
        
(*
   fun readConfig () = 
      let
         val config = 
            OS.FileSys.joinDirPath { dir = smackHome, file = "config" } 
      in
         if OS.FileSys.access (config, [ OS.FileSys.A_READ ])
         then 
         else ()
      end
*)
end
