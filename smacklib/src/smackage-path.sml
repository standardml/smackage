(** Deal with filesystem elements in a sensible way. 

FIXME: This is heavily dependent on symlinks working. Windows will need some
deeper thought.
*)
structure SmackagePath =
struct
    (** Return the full filesystem path to a package.
        XXX: Hard coded for local testing.  FIXME HAX HAX HAX.
    *)
    fun getPackageDir pkg = "/Users/gdpe/.smackage/" ^ pkg

    (** Retrieve a list of currently installed versions of pkg.
        We do this by listing the directory, and ignoring everything
        that's not a valid semantic version.  This ignores the symlinks
        like v1 and v1.6, and only gets the full versions like v1.6.2.

        The result *MUST* be sorted in descending order.
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
        ListMergeSort.sort SemVer.<
            (List.mapPartial 
                (fn x => SOME (SemVer.fromString x) handle _ => NONE) values)
    end

    (** Create the empty directory for pkg at a given version, and update
        symlinks accordingly.

        The question we face is whether the new package we are installing
        should replace some other as the target of a version symlink.
        
        FIXME: There is very little error handling in here at the moment.
        This is somewhat intentional, as an exception anywhere should bail out
        the whole process.

        This will leave the current working directory as the newly created
        directory for this package.
    *)
    fun createPackagePaths (pkg,ver) =
    let
        (* Create the top-level package directory if it doesn't exist *)
        val _ = OS.FileSys.isDir (getPackageDir pkg) handle _ =>
                    (OS.FileSys.mkDir (getPackageDir pkg); true)
        val _ = OS.FileSys.chDir (getPackageDir pkg)

        val newPaths = map (fn x => pkg ^ "/" ^ x) (SemVer.allPaths ver)
        val existing = installedVersions pkg

        val majorPrefix = Int.toString (#1 ver)
        val majors = 
            List.filter 
                (fn x => String.isPrefix majorPrefix (SemVer.toString x)) 
                    existing
        val symlinks = 
            if length majors = 0 orelse SemVer.< (hd majors, ver) 
                then ["v" ^ majorPrefix] else []

        val minorPrefix = Int.toString (#1 ver) ^ "." ^ Int.toString (#2 ver)
        val minors = List.filter (fn x => String.isPrefix minorPrefix (SemVer.toString x)) existing
        val symlinks' = symlinks @
            (if length minors = 0 orelse SemVer.< (hd minors, ver)
                then ["v" ^ minorPrefix] else [])

        val versionDir = "v" ^ SemVer.toString ver
        val _ = OS.FileSys.mkDir (getPackageDir pkg ^ "/" ^ versionDir) handle _ => ()

        fun replaceOrCreateSymlink dst link =
        let
            (* Delete the old link if it exists *)
            val e = OS.FileSys.isLink link handle _ => false
            val _ = 
                (if e then OS.FileSys.remove link else ())
                handle _ => ()

            (* Create the new one *)
            (* TODO: Windows support *)
            val _ = Posix.FileSys.symlink {old = dst, new = link}
        in
            ()
        end

        val _ = List.app (replaceOrCreateSymlink versionDir) symlinks'

        val _ = OS.FileSys.chDir versionDir
    in
        ["v" ^ SemVer.toString ver] @ symlinks @ symlinks'
    end
end

