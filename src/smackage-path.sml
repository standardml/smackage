(** Deal with filesystem elements in a sensible way. 

FIXME: This is heavily dependent on symlinks working. Windows will need some
deeper thought.
*)
structure SmackagePath =
struct
    exception Metadata of string

    (** Retrieve a list of currently installed versions of pkg.
        We do this by listing the directory, and ignoring everything
        that's not a valid semantic version.  This ignores the symlinks
        like v1 and v1.6, and only gets the full versions like v1.6.2.

        The result *MUST* be sorted in descending order.
    *)
    fun installedVersions smackage_root pkg =
    let
        val pkgDir' = OS.Path.joinDirFile {dir = smackage_root, file = "lib"}
        val pkgDir = OS.Path.joinDirFile {dir = pkgDir', file = pkg}
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
        InsertionSort.sort SemVer.compare
            (List.mapPartial 
                (fn x => SOME (SemVer.fromString x) handle _ => NONE) values)
    end

    (** Return me the latest installed version satisfying a given constraint
        in descending version order. *)
    fun installedSatisfying smackage_root pkg constr =
    let
        val cand = installedVersions smackage_root pkg
    in
        List.filter (SemVer.satisfies constr) cand
    end

    (** Get the metadata for a currently-installed package *)
    fun packageMetadata smackage_root (pkg,ver) =
    let
        val pkgDir' = OS.Path.joinDirFile {dir = smackage_root, file = "lib"}
        val pkgDir'' = OS.Path.joinDirFile {dir = pkgDir', file = pkg}
        val pkgDir = OS.Path.joinDirFile 
                            {dir = pkgDir'', file = "v" ^ SemVer.toString ver}
        val specFile = OS.Path.joinDirFile {dir=pkgDir,file=pkg ^ ".smackspec"}
 
    in
        if not (OS.FileSys.access (specFile, []))
            then raise Metadata ("Spec file not found: " ^ specFile)  else
        if not (OS.FileSys.access (specFile, [ OS.FileSys.A_READ ]))
            then raise Metadata "Spec file exists but can't be read"
        else Spec.fromFile specFile
            handle (Spec.SpecError s) => raise Fail ("Spec error: " ^ s)
    end


    (** Create the empty directory for pkg at a given version, and
        don't create the symlinks yet.

        Instead, call createVersionLinks *after* you've checked out the
        source.  This will make non-posix platforms behave correctly.
    


        This will leave the current working directory as the newly created
        directory for this package.
    *)
    fun createPackagePaths smackage_root (pkg,ver) =
    let
        val pkgDir' = OS.Path.joinDirFile {dir = smackage_root, file = "lib"}

        val _ = if not (OS.FileSys.access (pkgDir', [])) then
                    OS.FileSys.mkDir pkgDir' else ()

        val pkgDir = OS.Path.joinDirFile {dir = pkgDir', file = pkg}
        (* Create the top-level package directory if it doesn't exist *)
        val _ = OS.FileSys.isDir pkgDir handle _ =>
                    (OS.FileSys.mkDir pkgDir; true)
        val _ = OS.FileSys.chDir pkgDir

        val versionDir = "v" ^ SemVer.toString ver
        val _ = OS.FileSys.mkDir 
            (OS.Path.joinDirFile {dir=pkgDir, file=versionDir}) handle _ => ()

        val _ = OS.FileSys.chDir versionDir
    in
        ()
    end

    (* Create major and minor version links to the concrete version.

       The question we face is whether the new package we are installing
       should replace some other as the target of a version symlink.
        
       FIXME: There is very little error handling in here at the moment.
       This is somewhat intentional, as an exception anywhere should bail out
       the whole process.
    *)
    fun createVersionLinks smackage_root (pkg,ver) =
    let
        val pkgDir' = OS.Path.joinDirFile {dir = smackage_root, file = "lib"}
        val pkgDir = OS.Path.joinDirFile {dir = pkgDir', file = pkg}
        val _ = OS.FileSys.chDir pkgDir

        val versionDir = "v" ^ SemVer.toString ver

        val newPaths = map (fn x => 
            OS.Path.joinDirFile {dir = pkg, file = x}) 
                (SemVer.allPaths ver)
        val existing = 
            List.filter (fn x => not (SemVer.eq(x, ver))) (installedVersions smackage_root pkg)

        val majorPrefix = SemVer.constrToString (SemVer.major ver)
        val majors = 
            List.filter 
                (fn x => String.isPrefix majorPrefix (SemVer.toString x)) 
                    existing
        val symlinks = 
            if length majors = 0 orelse SemVer.< (hd majors, ver) 
                then ["v" ^ majorPrefix] else []

        val minorPrefix = SemVer.constrToString (SemVer.minor ver)
        val minors = List.filter 
            (fn x => String.isPrefix minorPrefix (SemVer.toString x)) existing

        val symlinks' = symlinks @
            (if length minors = 0 orelse SemVer.< (hd minors, ver)
                then ["v" ^ minorPrefix] else [])

        val _ = List.app (Symlink.replaceOrCreateSymlink versionDir) symlinks'

        val _ = OS.FileSys.chDir versionDir
    in
        ["v" ^ SemVer.toString ver] @ symlinks @ symlinks'
    end
end

