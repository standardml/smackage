(** Deal with filesystem elements in a sensible way. *)
structure SmackagePath =
struct
    (** Return the full filesystem path to a package.
        XXX: Hard coded for local testing.  FIXME HAX HAX HAX.
    *)
    fun getPackageDir pkg = "/Users/gdpe/.smackage/" ^ pkg

    (** Retrieve a list of currently installed versions of pkg.
        We do this by listing the directory, and ignoring everything
        that's not a valid semantic version.  This ignores the symlinks
        like v1 and v1.6, and only gets the full versions like v1.6.2
    *)
    fun installedVersions pkg =
    let
        val pkgDir = getPackageDir pkg
        val dh = OS.FileSys.openDir pkgDir
        fun untilNone () = 
        let
            val v = OS.FileSys.readDir dh
        in
            if v = NONE then [] else (valOf v) :: untilNone ()
        end
        val values = untilNone () 
        val _ = OS.FileSys.closeDir dh
    in
        List.mapPartial 
            (fn x => SOME (SemVer.fromString x) handle _ => NONE) values
    end 

    fun createPackagePaths (pkg,ver) =
    let
        val newPaths = map (fn x => pkg ^ "/" ^ x) (SemVer.allPaths ver)
        
    in
        newPaths
    end
end

