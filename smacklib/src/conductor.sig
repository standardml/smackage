(* CONDUCTOR is the interface between the "configuration"ey parts of smackage
 * and the raw, get-my-code parts. *)

signature CONDUCTOR =
sig
   (* get smackagePath packageName ver prot 
    *    Makes semantic version ver available within
    *    the package directory ($smackagePath)/($packageName)/v($ver).
    *    It assumes this directory exists. *)
   val get: string -> string -> SemVer.semver -> Protocol.protocol -> unit

   (* Old function, throws an error now *)
   val package: 'a -> 'b -> { get: 'c, poll: 'd }
end

