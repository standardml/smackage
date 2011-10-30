(*
    This defines the data structure and syntax for smackage package definitions
    (smackspec files). The general syntax is a flat key/value format, eg:

        provides: test 1.2.3beta
        description: This is a sample smackspec file.
        remote: git git://example.org/test.git
        requires: smacklib >= 1.2.3
        requires: ioextras 0.0.45

    The following keys are supported:

        description: ANY_STRING
        remote: TYPE URL
        requires: PACKAGE_NAME PARTIAL_SEMVER [optional: (MINIMAL_SEMVER)]
        comment: ANY_STRING
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

    See https://github.com/standardml/smackage/wiki/Smackspec for more 
    information. Please note that the parser is rather lax at the moment; it 
    will accept url values that aren't really URLs, etc. This will likely 
    change in the future.
*)

structure SemVerDict = ListDict (structure Key = SemVer)
structure SemConstrDict = 
   ListDict 
      (structure Key = 
       struct
          type t = SemVer.constraint 
          val compare = SemVer.compareConstr
       end)
structure StringDict =
   ListDict 
      (structure Key = struct type t = string val compare = String.compare end)

signature SPEC =
sig
   exception SpecError of string

   datatype spec_entry =
       Provides of string * SemVer.semver
     | Description of string
     | Requires of string * SemVer.constraint * SemVer.semver option
     | Maintainer of string
     | Remote of Protocol.protocol
     | License of string
     | Platform of string
     | Key of string * string 

   type spec = spec_entry list

   (* Parse a smackspec file (every line should be an empty string or a valid
    * spec_entry, such as one would get from FSUtil.getLines) *)
   val parse: string list -> spec
   val fromFile: string -> spec
   val toString: spec -> string

   (* Interprets the spec as a packages file, get the requirements *)
   val key: spec -> string -> string list
   val platforms: spec -> (string * spec) list
   val provides: spec -> string * SemVer.semver
   val remote: spec -> Protocol.protocol
   val requires: 
      spec -> (string * SemVer.constraint * SemVer.semver option) list

   (* Interprests a series of specs as a versions.smackspec file *)
   val toVersionIndex: 
      spec list -> Protocol.protocol SemVerDict.dict StringDict.dict
end


structure Spec:> SPEC =
struct
   exception SpecError of string

   datatype spec_entry =
      Provides of string * SemVer.semver
    | Description of string
    | Requires of string * SemVer.constraint * SemVer.semver option
    | Maintainer of string
    | Remote of Protocol.protocol
    | License of string
    | Platform of string
    | Key of string * string (* We just push all the unused keys in here *)

   type spec = spec_entry list

   (* Like String.fields, but split at most once *)
   fun splitOnce delim s =
      case CharVector.findi (fn (_, c) => c = delim) s of
         NONE => (s, NONE)
       | SOME (i, _) => 
            (String.extract (s,0,SOME i), SOME (String.extract (s,i+1,NONE)))

   fun parsePackage s =
      case String.tokens Char.isSpace s of
         [pkg, ver] => (pkg, SemVer.fromString ver)
       | _ => raise SpecError ("Invalid 'provides:' content: `" ^ s ^ "'")

   fun parseRequires s =
      case String.tokens Char.isSpace s of
         [pkg, con] => (pkg, SemVer.constrFromString con, NONE)
       | [pkg, con, min] =>
            if #"(" = String.sub (min, 0) 
               andalso #")" = String.sub (min, size min - 1)
            then ( pkg
                 , SemVer.constrFromString con
                 , SOME (SemVer.fromString 
                            (String.substring (min, 1, size min - 2))))
            else raise SpecError ("Invalid minimal version: `" ^ min ^ "'")
       | _ => raise SpecError ("Invalid 'requires:' content: `" ^ s ^ "'")

   fun parseLine "" = NONE
     | parseLine line = 
       let
          val (key, value) = 
             case splitOnce #":" line of 
                (key, SOME value) => (key, value)
              | _ => raise SpecError ("Malformed line in spec: `" ^ line ^ "'")
          val () = 
             if CharVector.all (fn c => Char.isAlphaNum c orelse c = #"-") key
             then ()
             else raise SpecError ("Invalid key in spec: `"^key^"'")
       in case (key,value) of
              ("provides",v) => SOME (Provides (parsePackage v))
            | ("description",v) => SOME (Description v)
            | ("requires",v) => SOME (Requires (parseRequires v))
            | ("maintainer",v) => SOME (Maintainer v)
            | ("remote",v) => SOME (Remote (Protocol.fromString v))
            | ("license",v) => SOME (License v)
            | ("platform",v) => SOME (Platform v)
            | (k,v) => SOME (Key (k,v))
       end

   fun parse lines = List.mapPartial parseLine lines

   val fromFile = parse o FSUtil.getCleanLines o TextIO.openIn

   fun toString' (Provides (s,v)) = 
          "provides: " ^ s ^ " " ^ SemVer.toString v
     | toString' (Description s) =
          "description: " ^ s 
     | toString' (Requires (p,v,min)) =
          ( "requires: " ^ p ^ " " ^ SemVer.constrToString v
          ^ (case min of NONE => "" | SOME v => "(" ^ SemVer.toString v ^ ")"))
     | toString' (Maintainer s) =
          "maintainer: " ^ s
     | toString' (Remote p) =
          "remote: " ^ Protocol.toString p
     | toString' (License s) =
          "license: " ^ s
     | toString' (Platform s) =
          "platform: " ^ s
     | toString' (Key (k,v)) = k ^ ": " ^ v

   fun toString spec = String.concatWith "\n" (map toString' spec)

   (* Helper functions *)

   fun key s key =
   let fun key' (key', v) = if key = key' then SOME v else NONE
   in 
      List.mapPartial (fn (Key kv) => key' kv | _ => NONE) s 
   end

   fun provides s =
      case List.mapPartial (fn (Provides v) => SOME v | _ => NONE) s of
         [] => raise SpecError "Missing `provides:' line in spec"
       | [ v ] => v
       | _ => raise SpecError "Multiple `provides:' lines in spec"

   fun platforms [] = []
     | platforms (Platform p :: t) =
       let
          fun loop [] s accum plats = rev ((s, rev accum) :: plats)
            | loop (Platform p :: t) s accum plats = 
                 loop t p [] ((s, rev accum) :: plats)
            | loop (h :: t) s accum plats = 
                 loop t s (h :: accum) plats
       in
           loop t p [] []
       end
     | platforms (h::t) = platforms t

   fun remote s =
      case List.mapPartial (fn (Remote v) => SOME v | _ => NONE) s of
         [] => raise SpecError "Missing `remote:' line in spec"
       | [ v ] => v
       | _ => raise SpecError "Multiple `remote:' lines in spec"

   val requires = 
      List.mapPartial (fn (Requires v) => SOME v | _ => NONE)

   fun toVersionIndex (spec: spec list) = 
   let 
      fun folder (spec, dict) =
      let 
         val remote = remote spec 
         val provides = 
            List.mapPartial (fn (Provides v) => SOME v | _ => NONE) spec
      in
         List.foldr
            (fn ((pkg, semver), dict) => 
                StringDict.insertMerge dict pkg 
                   (SemVerDict.singleton semver remote)
                   (fn dict => SemVerDict.insert dict semver remote))
            dict
            provides
      end
   in
      List.foldl folder StringDict.empty spec
   end
end

