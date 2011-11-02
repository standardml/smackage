signature SMACKLIB =
sig
    (** Ensure that a package is present in the library; returns true if it
     ** was already there *)
    val download : string -> string * SemVer.semver * Protocol.protocol -> bool

    (** Checks for a package's existance without modifying anything. *)
    val exists : string -> string * SemVer.semver -> bool

(*
    (** Build a previously downloaded package by invoking a command
        specified as 'build:' in the spec file. *)
    val build : string -> (string * string list) -> 
                        (string * SemVer.semver) -> unit;

    (** Install a previously downloaded package by invoking a command
        specified as 'install:' in the spec file. *)
    val install : string -> (string * string list) -> 
                        (string * SemVer.semver) -> unit;
*)

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

    fun download smackage_root (pkg, ver, prot) =
       if exists smackage_root (pkg, ver) 
       then true
       else ( SmackagePath.createPackagePaths smackage_root (pkg,ver)
            ; Conductor.get smackage_root pkg ver prot
            ; SmackagePath.createVersionLinks smackage_root (pkg,ver)
            ; false)

(*
    fun build smackage_root host (pkg,ver) =
    let
        val pkgDir = (smackage_root // "lib" // pkg // "v"^SemVer.toString ver)

        val spec = Spec.fromFile (pkgDir // (pkg ^ ".smackspec"))

        val _ = OS.FileSys.chDir pkgDir
    in
        Install.build host spec
    end handle (Spec.SpecError _) => () (* Silently fail if there is no spec. *)

    fun install smackage_root host (pkg,ver) =
    let
        val pkgDir = (smackage_root // "lib" // pkg // "v"^SemVer.toString ver)

        val spec = Spec.fromFile (pkgDir // (pkg ^ ".smackspec"))

        val _ = OS.FileSys.chDir pkgDir
    in
        Install.install host spec
    end handle (Spec.SpecError _) => () (* Silently fail if there is no spec. *)

    fun uninstall smackage_root (pkg,ver) = raise Fail "Not implemented"
*)

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
    let  
       val file = 
          ( smackage_root
          // "lib"
          // pkg 
          // ("v" ^ SemVer.toString ver)
          // (pkg ^ ".smackspec"))
    in
       Spec.fromFile file
    end handle (Spec.SpecError s) => raise Fail ("Spec error: " ^ s)
end
