signature SMACKLIB =
sig
    val install : string -> string * SemVer.semver -> unit
    val uninstall : string -> string * SemVer.semver -> unit
    val versions : string -> SemVer.semver list
    val info : string -> string * SemVer.semver -> Spec.spec
end

structure SmackLib : SMACKLIB =
struct
    (* TODO: Verify that the package and version actually exist. *)
    fun install smackage_root (pkg,ver) =
        (SmackagePath.createPackagePaths smackage_root (pkg,ver);
         (*(#get (Conductor.package smackage_root pkg)) ver)*) ())

    fun uninstall smackage_root (pkg,ver) = raise Fail "Not implemented"

    (* Should return a sorted list of available versions *)
    fun versions pkg = raise Fail "Not implemented"
    
    fun info smackage_root (pkg,ver) = 
        Spec.fromFile 
            (smackage_root ^ "/" ^ 
             pkg ^ "/v" ^ SemVer.toString ver ^ "/" ^ 
             pkg ^ ".smackspec")
end
