(* CONDUCTOR is the interface between the "configuration"ey parts of smackage
 * and the raw, get-my-code parts. *)

signature CONDUCTOR =
sig
   (* get smackagePath packageName ver prot 
    *    Makes semantic version ver available within
    *    the package directory ($smackagePath)/lib/($packageName)/v($ver).
    *    It assumes this directory exists. *)
   val get: string -> string -> SemVer.semver -> Protocol.protocol -> unit

   (* poll name prot
    *    Query the remote store for which tags are available. *)
   val poll: string -> Protocol.protocol -> Spec.spec list
end

