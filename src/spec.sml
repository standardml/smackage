(*
    This defines the data structure and syntax for smackage package definitions (smackspec files).
    The general syntax is a flat key/value format, eg.

        provides: test 1.2.3beta
        description: This is a sample smackspec file.
        remote: git git://example.org/test.git
        requires: smacklib >= 1.2.3
        requires: ioextras 0.0.45

    Lines that aren't indented or empty must contain a key name followed by a colon (with no whitspace before the colon).
    The string to the right of the colon as well as any following indented or empty lines constitutes the value belonging
    to that key. There is no order and keys may occur multiple times. Lines with only whitespace at the beginning of the
    file are ignored. Keys that have no meaning in smackspec are syntax errors.
    
    The values have further syntactic restrictions depending on the key, vaguely summerized here:
    
        provides: PACKAGE_NAME SEMANTIC_VERSION     (exactly once)
        description: ANY_STRING                     (at most once)
        remote: TYPE URL                            (exactly once)
        requires: PACKAGE_NAME VERSION_CONSTRAINTS  (zero or more)
        comment: ANY_STRING                         (zero or more)
    
    Apart from that, the following keys are supported, but their values are not checked for syntax errors at the moment:
    
        maintainer: FULL_NAME <EMAIL_ADDRESS>               
        keywords: KEYWORD_1 KEYWORD_2 KEYWORD_3
        upstream-version: VERSION
        upstream-url: URL
        documentation-url: URL
        bug-url: URL
        license: CANONICAL_LICENSE_NAME
        platform: SML_PLATFORM
        build: COMMAND
        test: COMMAND
        install: COMMAND
        uninstall: COMMAND
        documentation: COMMAND
        
    All of these keys can appear at most once.

    Please note that the parser is rather lax at the moment; it will accept url values that aren't really URLs etc.
    This will likely change in the future, so please be careful to get it right when pasting or typing in the values.
*)



signature SPEC =
sig
    exception SpecError of string

    datatype spec_entry =
        Provides of string * SemVer.semver
      | Description of string
      | Requires of string * SemVer.constraint
      | Maintainer of string
      | Remote of Protocol.protocol
      | License of string
      | Platform of string
      | Key of string * string 

    type spec

    (* Parses a smackspec file. *)
    val fromFile : string -> spec

    (* Parses a smackspec string. *)
    val fromString : string -> spec
    val toString : spec -> string
    val toVersionSpec : spec -> string * SemVer.semver * Protocol.protocol
    
    (* Helpers for extracting things from specs *)
    val provides : spec -> string * SemVer.semver
    val requires : spec -> (string * SemVer.constraint) list
    val remote : spec -> Protocol.protocol
    val platforms : spec -> (string * spec) list
    val key : spec -> string -> string
end


structure Spec : SPEC =
struct
    exception SpecError of string

    datatype spec_entry =
        Provides of string * SemVer.semver
      | Description of string
      | Requires of string * SemVer.constraint
      | Maintainer of string
      | Remote of Protocol.protocol
      | License of string
      | Platform of string
      | Key of string * string (* We just push all the unused keys in here *)

    type spec = spec_entry list
    
    fun trim s =
    let
        fun trimStart (#" "::t) = trimStart t
          | trimStart (#"\t"::t) = trimStart t
          | trimStart l = l

        fun trimEnd (#"#"::t) = []
          | trimEnd (#"\n"::t) = []
          | trimEnd (h::t) = h :: trimEnd t
          | trimEnd [] = []
    in
        String.implode (trimEnd (trimStart (String.explode s)))
    end

    (* Like String.fields, but split at most once *)
    fun splitOnce delim s =
        case CharVector.findi (fn (_,c) => c = delim) s of
            NONE => [s]
          | SOME (i,_) => 
            [String.extract (s,0,SOME i), String.extract (s,i+1,NONE)]

    fun parsePackage s =
        (fn [pkg,ver] => (pkg, SemVer.fromString ver)
          | _ => raise SpecError ("Invalid 'provides:' content: `" ^ s ^ "'"))
            (String.fields Char.isSpace s)

    fun parseRequires s =
        (fn [pkg,con] => (pkg,SemVer.constrFromString con)
          | _ => raise SpecError ("Invalid 'requires:' content: `" ^ s ^ "'"))
            (String.fields Char.isSpace s)

    fun parseLine line =
    if String.isPrefix "#" line orelse line = "\n" orelse line = "" then NONE else
    let
        val f = splitOnce #":" line
        val _ = if length f <> 2 then 
            raise SpecError ("Malformed line in spec: `" ^ line ^ "'")
            else ()
        val (key,value) = (List.nth(f,0), trim (List.nth(f,1)))
        val _ = 
            if CharVector.all (fn c => Char.isAlphaNum c orelse c = #"-") key
                then ()
                else raise SpecError ("Invalid key in spec: `"^key^"'")
    in
        case (key,value) of
            ("provides",v) => SOME (Provides (parsePackage v))
          | ("description",v) => SOME (Description v)
          | ("requires",v) => SOME (Requires (parseRequires v))
          | ("maintainer",v) => SOME (Maintainer v)
          | ("remote",v) => SOME (Remote (Protocol.fromString v))
          | ("license",v) => SOME (License v)
          | ("platform",v) => SOME (Platform v)
          | (k,v) => SOME (Key (k,v))
    end

    fun parse lines =
        List.mapPartial (parseLine o trim) lines

    fun readLines (file, position, lines) = 
        case TextIO.inputLine file of
              NONE => rev lines
            | (SOME "\n") => readLines (file, position + 1, lines)
            | (SOME line) => 
                readLines (file, position + 1, line :: lines)


    fun parseStream stream = 
        let
            val lines = readLines (stream, 1, [])
        in
            parse lines 
        end handle (e as SpecError s) => (
            TextIO.output (TextIO.stdErr, "Error in smackspec: " ^ s ^ "\n"); 
            raise e
        )


    fun fromFile filename =
        let
            val file = TextIO.openIn filename
            val result = parseStream file
            val _ = TextIO.closeIn file
        in
            result
        end

    fun fromString string = parseStream (TextIO.openString string)

    fun withErrorPrinter parser name input = parser input
        handle (e as SpecError s) => (
            TextIO.output (TextIO.stdErr, "Error in '" ^ name ^ "': " ^ s ^ "\n"); 
            raise e
        )

    fun toString' (Provides (s,v)) = 
        "provides: " ^ s ^ " " ^ SemVer.toString v
      | toString' (Description s) =
        "description: " ^ s 
      | toString' (Requires (p,v)) =
        "requires: " ^ p ^ " " ^ SemVer.constrToString v
      | toString' (Maintainer s) =
        "maintainer: " ^ s
      | toString' (Remote p) =
        "remote: " ^ Protocol.toString p
      | toString' (License s) =
        "license: " ^ s
      | toString' (Platform s) =
        "platform: " ^ s
      | toString' (Key (k,v)) = k ^ ": " ^ v

    fun toString spec = 
        String.concatWith "\n" (map toString' spec)

    fun provides s =
        (fn (Provides v) => v | _ => 
            raise SpecError "Missing provides line in spec")
            (hd (List.filter (fn (Provides _) => true | _ => false) s)) 
                handle _ =>  raise SpecError "Missing provides: line in spec"

    val requires = 
        List.mapPartial (fn (Requires v) => SOME v | _ => NONE)

    fun remote s =
        (fn (Remote v) => v | _ => 
            raise SpecError "Missing remote: line in spec")
            (hd (List.filter (fn (Remote _) => true | _ => false) s)) 
                handle _ =>  raise SpecError "Missing remote: line in spec"


    fun toVersionSpec (spec : spec) =
        (fn (pkg,ver) => (pkg,ver,remote spec)) (provides spec)
        handle (e as SpecError s) => (
            TextIO.output (TextIO.stdErr, 
                "Error in smackspec: " ^ s ^ "\n" ^ toString spec); 
            raise e)

    fun platform2spec (s,[]) = (s,[])
      | platform2spec (s, l as (Platform p :: t)) = (s,l)
      | platform2spec (s,h::t) = platform2spec (s @ [h], t)

    fun platforms (Platform p :: t) =
        let
            val (cont,t') = platform2spec ([],t)
        in
            (p,cont) :: platforms t'
        end
      | platforms (h::t) = platforms t
      | platforms [] = []

    fun key [] name = raise SpecError ("Key `" ^ name ^ "' not found in spec.")
      | key ((Key(k,v)::t)) name = if k = name then v else key t name
      | key (h::t) name = key t name

end

