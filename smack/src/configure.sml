(** Stateful configuration, hopefully with sensible defaults *)
structure Configure =
struct
   fun // (dir, file) = OS.Path.joinDirFile { dir = dir, file = file }
   infix 5 //

   val smackHome = ref "<dummy>"

   val smackSources: string list ref = ref [] 

   (** Attempt to ascertain the smackage home directory.
       Resolved in this order:

       SMACKAGE_HOME environment variable
       ~/.smackage/
       /usr/local/smackage/
       /opt/smackage/
   *)
   fun initSmackHome () = 
      let
         fun tryDir (SOME s) = ((OS.FileSys.openDir s; true) handle _ => false)
           | tryDir NONE = false
         val envHome = OS.Process.getEnv "SMACKAGE_HOME"
         val envHome' = 
            case OS.Process.getEnv "HOME" of 
               NONE => NONE
             | SOME home =>
                  SOME (OS.Path.joinDirFile { dir = home, file = ".smackage" })
      in
         if tryDir envHome then smackHome := valOf envHome else
         if tryDir envHome' then smackHome := valOf envHome' else
         if tryDir (SOME "/usr/local/smackage") 
            then smackHome := "/usr/local/smackage" else
         if tryDir (SOME "/opt/smackage") 
            then smackHome := "/opt/smackage" else
         raise Fail "Cannot find smackage home. Try setting SMACKAGE_HOME"
      end

   fun initFile fileName contents = 
      let
         val filePath =
            OS.Path.joinDirFile { dir = !smackHome, file = fileName }

         fun create () = 
            let
               val () = 
                  print ("NOTICE: file `" ^ fileName ^ "` doesn't exist,\
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
                            ^ "` (run as sudo?)")
         else ()
      end handle exn => 
             ( print ("Error with `" ^ fileName ^ "` file.\n")
             ; raise exn)

   fun initDir dirName = 
      let 
         val dirPath = 
            OS.Path.joinDirFile { dir = !smackHome, file = dirName }
         fun create () = 
            let
               val () = 
                  print ("NOTICE: directory `" ^ dirName ^ "` doesn't exist,\
                         \ trying to create it.\n")
            in
               OS.FileSys.mkDir dirPath
            end
      in
         if not (OS.FileSys.access (dirPath, []))
           then create () else
         if not (OS.FileSys.isDir dirPath)
           then raise Fail ("File `" ^ dirName
                            ^ "` exists and is not a directory")
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
             | SOME [ "source", file ] => 
                  ( smackSources := !smackSources @ [ file ])
             | SOME s => 
                  raise Fail ( "Bad configuration line: " 
                             ^ String.concatWith " " s )
      in 
         if not (OS.FileSys.access (config, [])) then () else
         if not (OS.FileSys.access (config, [ OS.FileSys.A_READ ]))
           then raise Fail "Config file exists but can't be read"
         else loop (TextIO.openIn config) 
      end

   fun init () =
      ( initSmackHome ()
      ; initFile "sources.local" 
           "smackage git git://github.com/standardml/smackage.git\n"
      ; initFile "config" ("source lib" // "smackage" // "v0" // "sources\n")
      ; initFile "packages.installed" "\n"
      ; initFile "versions.smackspec" "\n"
      ; initDir "lib"
      ; initDir "bin"
      ; readConfigFile ())
        
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
