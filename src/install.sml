(* The Install module is aware of platform-specific build and install specs *)
structure Install =
struct
    (* Platform is either of the form *, <os>+<compiler> or <compiler>.
       the 'platform' argument is from a spec file, i.e., a
       platform: declaration.

       The 'compiler' line is a compiler we have (from config) that we would
       like to try to use to run this software. Therefore for a given compiler
       (e.g. 'mlton'), we check whether our current Configure.platform value,
       plus the spec platform we are currently are considering are compatible
       e.g., if we are on osx, then we need to find a platform spec like:
       osx+mlton, or 'mlton', or '*'.

       isSupported returns true if the given spec is such a spec.
    *)
    fun isSupported compiler platform =
    let
        val f = String.fields (fn #"+" => true | _ => false) platform
        val (os,comp) = 
            case f of ["*"] => (NONE,NONE)
                    | [c] => (NONE,SOME c)
                    | [os,c] => (SOME os, SOME c)
                    | [] => raise 
                        Fail ("Invalid platform spec: `" ^ platform ^ "'")
        val os_supp =  os = NONE orelse valOf os = (!Configure.platform)
        val comp_supp = comp = NONE orelse valOf comp = compiler
    in
        os_supp andalso comp_supp
    end

    (* Note: we must already be in the package/version directory. *)
    fun install spec = 
    let
        val platforms = 
            List.map (fn x => List.filter (isSupported x) 
                                (Spec.platforms spec))
                                    (!Configure.compilers)
    in
        platforms
    end
end
