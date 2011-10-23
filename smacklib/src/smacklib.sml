signature SMACKLIB =
sig
    val install : string -> string * SemVer.semver * Protocol.protocol -> unit
    val uninstall : string -> string * SemVer.semver -> unit
    val versions : string -> SemVer.semver list
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

    (* Should return a sorted list of available versions *)
    fun versions pkg = raise Fail "Not implemented"
    
    fun info smackage_root (pkg,ver) = 
        Spec.fromFile 
            ( smackage_root
            // "lib"
            // pkg 
            // ("v" ^ SemVer.toString ver)
            // (pkg ^ ".smackspeck"))
end
