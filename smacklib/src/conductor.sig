(* CONDUCTOR is the interface between the "configuration"ey parts of smackage
 * and the raw, get-my-code parts. *)

signature CONDUCTOR =
sig
   (* package smackage_root_dir some_package
    * 
    * Given a package, either returns NONE ("I don't know where or how to get 
    * "some_package") or SOME { poll, get }.
    * 
    * poll ()
    *    Query the remote store for which tags are available. Optionally,
    *    this may instead query smackage_root_dir/packlib to support people
    *    working with local libraries. This function assumes that 
    *    smackage_root_dir exists, but not that smackage_root_dir/packlib 
    *    exists.
    * 
    * get (X,Y,Z,ps) - 
    *    Makes semantic version X.Y.Zps available within
    *    the package directory smackage_root_dir/some_package/vX.Y.Zps,
    *    which it assumes has already been created for it. *)
   val package: string -> string -> 
                   { poll: unit -> (string * SemVer.semver) list 
                   , get: SemVer.semver -> unit }
end

