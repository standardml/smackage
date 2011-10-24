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
   val search : string -> (string * SemVer.semver * Protocol.protocol) list
end = 
struct
    fun // (dir, file) = OS.Path.joinDirFile { dir = dir, file = file }
    infix 5 //

    val versionIndex = ref [] : (string * SemVer.semver * Protocol.protocol) list ref

    (** Parse the versions.smackspec file to produce a list of available
        (package,version,protocol) triples. *)
    fun parseVersionsSpec smackage_root =
    let
        val fp = TextIO.openIn (smackage_root // "versions.smackspec")

        val stanza = ref "";
        
        fun readStanzas () = 
        let
            val line = TextIO.inputLine fp
        in
            if line = NONE then [!stanza] else
            if line = SOME "\n"
                then (!stanza before stanza := "") :: readStanzas ()
                else (stanza := (!stanza) ^ (valOf line); readStanzas ())
        end

        val stanzas = readStanzas () handle _ => (TextIO.closeIn fp; [])

        fun whitespace s =
        let
            fun ws [] = true
              | ws (#"\n"::t) = ws t
              | ws (#"\r"::t) = ws t
              | ws (#" "::t) = ws t
              | ws (#"\t"::t) = ws t
              | ws _ = false
        in
            ws (String.explode s)
        end
        val _ = TextIO.closeIn fp
    in
        map (Spec.toVersionSpec o Spec.fromString) 
            (List.filter (fn s => not (whitespace s)) stanzas)
    end

    fun init smackage_root = 
        versionIndex := parseVersionsSpec smackage_root

    fun isKnown pkg = 
       not (null (List.filter (fn (n,_,_) => pkg = n) (!versionIndex)))

    fun queryVersions pkg = List.filter (fn (n,_,_) => pkg = n) (!versionIndex)

    fun latestVersion pkg =
    let
        val cand = queryVersions pkg
        val _ = if length cand = 0 then 
                    raise Fail ("Package `"^pkg^"' not found") else ()
    in
        List.foldl (fn ((n,v,p),v') => if SemVer.>(v,v') 
                        then v else v') (#2 (hd cand)) cand
    end

    fun getProtocol pkg ver = 
        (SOME (#3 (hd 
            (List.filter (fn (n,v,p) => n = pkg andalso v = ver) 
                (!versionIndex))))) handle _ => NONE

    fun name pkg NONE = pkg
      | name pkg (SOME spec) = pkg ^ " " ^ SemVer.constrToString spec

    fun getAll pkg NONE = map #2 (queryVersions pkg)
      | getAll pkg (SOME spec) =
           List.filter (SemVer.satisfies spec) (map #2 (queryVersions pkg))

    fun getLatest pkg constraint =
    let
        val cand = queryVersions pkg
        val cand' = 
           case constraint of 
              NONE => cand
            | SOME spec => List.filter (SemVer.satisfies spec o #2) cand
        val () = if length cand > 0 then () 
                 else raise Fail ("Could not satisfy constraint `"
                                 ^ name pkg constraint ^ "`") 
        val best = 
           List.foldl (fn ((n,v,p),v') => if SemVer.>(v,v') then v else v')
              (#2 (hd cand)) cand
    in
        ( (case constraint of NONE => SemVer.major best | SOME spec => spec)
        , best)
    end

    fun getBest pkg constraint = 
    let in
       case SemVer.intelligentSelect constraint (map #2 (queryVersions pkg)) of 
          NONE => raise Fail ("Could not satisfy constraint `"  
                             ^ name pkg constraint ^ "`")
        | SOME (ver, spec) => (ver, spec)
    end

    fun search query =
        List.filter (fn (n,_,_) => String.isSubstring query n) (!versionIndex)
end

