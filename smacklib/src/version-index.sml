structure VersionIndex =
struct
    val versionIndex = ref [] : (string * SemVer.semver * Protocol.protocol) list ref

    (** Parse the versions.smackspec file to produce a list of available
        (package,version,protocol) triples. *)
    fun parseVersionsSpec smackage_root =
    let
        val fp = TextIO.openIn (smackage_root ^ "/versions.smackspec")
                    handle _ => raise Fail 
                        ("Cannot open `$SMACKAGE_HOME/versions.smackspec'. " ^ 
                         "Try running `smack refresh' to update this file.")

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

        val _ = TextIO.closeIn fp
    in
        map (Spec.toVersionSpec o Spec.fromString) stanzas
    end

    (* Avoid re-loading the version index ever again. *)
    fun loadVersions smackage_root = 
        if length (!versionIndex) > 0 then () else
            versionIndex := parseVersionsSpec smackage_root

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

    fun getProtocol (pkg,ver) = 
        (SOME (#3 (hd 
            (List.filter (fn (n,v,p) => n = pkg andalso v = ver) 
                (!versionIndex))))) handle _ => NONE
end

