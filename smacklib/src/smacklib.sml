signature SMACKLIB =
sig
    (** Adds or removes a particular packages from the library *)
    val install : string -> string * SemVer.semver * Protocol.protocol -> unit
    val uninstall : string -> string * SemVer.semver -> unit

    (** Returns a list of installed versions *)
    (* XXX should probably be sorted, relies on the filesystem for this now *)
    val versions : string -> string -> SemVer.semver list

    (** Returns the smackspec for a particular smackage package *)
    val info : string -> string * SemVer.semver -> Spec.spec
end

structure SmackLib : SMACKLIB =
struct
    fun // (dir, file) = OS.Path.joinDirFile { dir = dir, file = file }
    infix 5 //

    fun exists smackage_root (pkg, ver) = 
       let
          val pkgRoot = smackage_root // "lib" // pkg
          val verString = "v" ^ SemVer.toString ver
       in 
          OS.FileSys.access (pkgRoot, [])
          andalso 
          OS.FileSys.access (pkgRoot // verString, [])
       end

    fun install smackage_root (pkg,ver,prot) =
       if exists smackage_root (pkg, ver) 
       then print ( "Package `" ^ pkg ^ " " ^ SemVer.toString ver 
                  ^ "` already installed, nothing to do.\n") 
       else ( SmackagePath.createPackagePaths smackage_root (pkg,ver)
            ; Conductor.get smackage_root pkg ver prot
            ; print ( "Package `" ^ pkg ^ " " ^ SemVer.toString ver 
                    ^ "` installed.\n"))

    fun uninstall smackage_root (pkg,ver) = raise Fail "Not implemented"

    fun versions smackage_root pkg = 
       let
          val pkgRoot = smackage_root // "lib" // pkg
          fun read dir accum = 
             case OS.FileSys.readDir dir of 
                NONE => rev accum before OS.FileSys.closeDir dir
              | SOME file => 
                   if String.isPrefix "v" file 
                      andalso 3 = length (String.tokens (fn x => x = #".") file)
                   then read dir (SemVer.fromString file :: accum)
                   else read dir accum
       in 
          if OS.FileSys.access (pkgRoot, [])
          then read (OS.FileSys.openDir pkgRoot) []
          else []
       end
    
    fun info smackage_root (pkg,ver) = 
        Spec.fromFile 
            ( smackage_root
            // "lib"
            // pkg 
            // ("v" ^ SemVer.toString ver)
            // (pkg ^ ".smackspec"))
        handle (Spec.SpecError s) => raise Fail ("Spec error: " ^ s)
end
