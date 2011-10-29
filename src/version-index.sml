(* Interface to the stored $SMACKAGE_HOME/versions.smackspec file *)

structure VersionIndex:> 
sig
   (* Initialization, expects the value of $SMACKAGE_HOME, where the
    * file versions.smackspec already exists. *)
   val init: string -> unit

   (* Do we know anything about this package? *)
   val isKnown: string -> bool

   (* How do we obtain this (version of this) package? *)
   val getProtocol: string -> SemVer.semver -> Protocol.protocol option
 
   (* Query for versions of packages (straightforwardly and heuristicly) *)
   val getAll:
      string -> SemVer.constraint option -> SemVer.semver list
   val getLatest: 
      string -> SemVer.constraint option -> SemVer.constraint * SemVer.semver
   val getBest: 
      string -> SemVer.constraint option -> SemVer.constraint * SemVer.semver

   (* Rough search for a package name *)
   val search : string -> (string * Protocol.protocol SemVerDict.dict) list
end = 
struct
    fun // (dir, file) = OS.Path.joinDirFile { dir = dir, file = file }
    infix 5 //

    val versionIndex: Protocol.protocol SemVerDict.dict StringDict.dict ref = 
       ref StringDict.empty

    fun init smackage_root = 
    let 
       val specstanzas = 
          FSUtil.getStanzas 
              (TextIO.openIn (smackage_root // "versions.smackspec"))
    in
       versionIndex := Spec.toVersionIndex (map Spec.parse specstanzas)
    end

    fun isKnown pkg = StringDict.member (!versionIndex) pkg

    fun queryVersions pkg = 
       case StringDict.find (!versionIndex) pkg of 
          NONE => []
        | SOME dict => SemVerDict.domain dict

    fun getProtocol pkg ver = 
       Option.mapPartial (fn dict => SemVerDict.find dict ver) 
          (StringDict.find (!versionIndex) pkg)

    fun name pkg NONE = pkg
      | name pkg (SOME spec) = pkg ^ " " ^ SemVer.constrToString spec

    fun getAll pkg NONE = queryVersions pkg
      | getAll pkg (SOME spec) =
           List.filter (SemVer.satisfies spec) (queryVersions pkg)

    fun getLatest pkg constraint =
    let
        val cand = queryVersions pkg
        val cand' = 
           case constraint of 
              NONE => cand
            | SOME spec => List.filter (SemVer.satisfies spec) cand
        val () = if length cand > 0 then () 
                 else raise Fail ("Could not satisfy constraint `"
                                 ^ name pkg constraint ^ "`") 
        val best = 
           List.foldl (fn (v,v') => if SemVer.>(v,v') then v else v')
              (hd cand) cand
    in
        ( (case constraint of NONE => SemVer.major best | SOME spec => spec)
        , best)
    end

    fun getBest pkg constraint = 
    let in
       case SemVer.intelligentSelect constraint (queryVersions pkg) of 
          NONE => raise Fail ("Could not satisfy constraint `"  
                             ^ name pkg constraint ^ "`")
        | SOME (ver, spec) => (ver, spec)
    end

    fun search query =
        List.filter 
           (fn (pkg, versions) => String.isSubstring query pkg)
           (StringDict.toList (!versionIndex))
end

