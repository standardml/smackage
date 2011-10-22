signature SMACKLIB =
sig
    val install : string -> string * SemVer.semver -> unit
    val uninstall : string -> string * SemVer.semver -> unit
end

structure SmackLib : SMACKLIB =
struct
    (* TODO: Verify that the package and version actually exist. *)
    fun install smackage_root (pkg,ver) =
        (SmackagePath.createPackagePaths smackage_root (pkg,ver);
         (#get (Conductor.package smackage_root pkg)) ver)

    fun uninstall smackage_root (pkg,ver) = raise Fail "Not implemented"
         
end
