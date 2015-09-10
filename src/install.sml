signature INSTALL =
sig
    exception InstallError of string

    (* These will fail silently if the package is not buildable
       or not installable, so it is safe to always call them.  *)
    val build : (string * string list) -> Spec.spec -> unit
    val install : (string * string list) -> Spec.spec -> unit
end

(* The Install module is aware of platform-specific build and install specs *)
structure Install : INSTALL =
struct
    exception InstallError of string

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
    fun isSupported hostos compiler platform =
    let

        val f = String.fields (fn #"+" => true | _ => false) platform
        val (os,comp) = 
            case f of ["*"] => (NONE,NONE)
                    | [c] => (NONE,SOME c)
                    | [os,c] => (SOME os, SOME c)
                    | _ => raise 
                        Fail ("Invalid platform spec: `" ^ platform ^ "'")
        val os_supp =  os = NONE orelse valOf os = hostos
        val comp_supp = comp = NONE orelse valOf comp = compiler
    in
        os_supp andalso comp_supp
    end

    (* Which platforms can we use to install/build this package? *)
    fun selectPlatforms (hostos,compilers) spec = 
    let
        val platforms = 
            List.foldr (op @) [] 
                (List.map (fn x => List.filter (fn (y,_) => isSupported hostos y x)
                                (Spec.platforms spec))
                                    (compilers))

        val _ = 
            if length (Spec.platforms spec) > 0 andalso length platforms = 0 
            then
                TextIO.output (TextIO.stdErr, 
                    "WARNING: the package you are installing does not have " ^
                    "an appropriate `platform:' section for your current " ^
                    "compiler/platform combination. Consider adjusting your " ^
                    "configuration settings in $SMACKAGE_HOME/config.\n" ^ 
                    "WARNING: Package will be downloaded but not installed\n")
            else ()
    in
        platforms
    end

    (* We must already be in the working directory of the package version.
        
        Fails silently if this is not a platform with 'key:'.
    *)
    fun runHook key (hostos,compilers) spec =
        case selectPlatforms (hostos,compilers) spec of
            [] => ()
          | ((platform,platSpec)::_) => 
          let
              val cmd = Spec.key platSpec key
              (* TODO: Do some simple macro expansion here.
                 e.g.: $(MLTON) -> absolute path to MLton
                 $(SMLNJ) -> path to SMLNJ
                 $(PLATFORM) -> selected platform
                 $(SMACKAGE_HOME) -> smackage_home
                 $(BIN) -> smackage binary path
                 $(LIB) -> smackage library path?
                 etc etc.
              *)
              val cmd' = String.concat cmd
              val _ = print ("NOTICE: selected platform `" ^ platform ^ "'\n")
              val _ = print (key ^ ": " ^ cmd' ^ "\n")
          in
              if OS.Process.isSuccess (OS.Process.system cmd') then ()
              else raise InstallError ("Hook `"^key^"' failed.")
          end handle (Spec.SpecError e) => ()

    val build = runHook "build"
    val install = runHook "install"
end
