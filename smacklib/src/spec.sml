(*
    This defines the data structure and syntax for smackage package definitions (smackspec files).
    The general syntax is a flat key/value format, eg.

        provides: test 1.2.3beta
        description:
            This is a sample smackspec file.
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

    exception Error of string

    type position

    type packageName

    type requirement

    type package
    
    type description
    
    type spec

    (* Parses a smackspec file. *)
    val fromFile : string -> spec

    (* Parses a smackspec string. *)
    val fromString : string -> spec
    
    (* Wraps error reporting around fromFile or fromString. Example:
           withErrorPrinter fromString "provides: foo-bar 1.2.3" "foobar.smackspec"

       In case of a parse error, this would print a message ala:
           Error in 'foobar.smackspec': Some error on line 2
    *)
    val withErrorPrinter : (string -> spec) -> string -> string -> spec

    val toString : spec -> string

    val toVersionSpec : spec -> string * SemVer.semver * Protocol.protocol
end


structure Spec : SPEC =
struct
    exception Error of string

    type position = int

    type packageName = string

    type requirement = packageName * SemVer.constraint * position

    type package = packageName * SemVer.semver * position
    
    type description = string * position
    
    type unparsed = string * position
    
    type spec = {
        provides : package,
        description : description option,
        requires : requirement list,
        maintainer : unparsed option,
        upstreamVersion : unparsed option,
        upstreamUrl : unparsed option,
        remote : Protocol.protocol, 
        documentationUrl : unparsed option,
        bugUrl : unparsed option,
        license : unparsed option,
        platform : unparsed option,
        build : unparsed option,
        test : unparsed option,
        install : unparsed option,
        uninstall : unparsed option,
        documentation : unparsed option
        }

         
    datatype directive
        = Comment
        | Provides of package
        | Description of description
        | Remote of Protocol.protocol * position
        | Requires of requirement
        | Unparsed of string * string * position

        
    fun dropWhile' predicate ([], count) = ([], count)
      | dropWhile' predicate ((head :: tail), count) = 
            if predicate head
                then dropWhile' predicate (tail, count + 1)
                else (head :: tail, count)

    fun dropWhile predicate list = #1 (dropWhile' predicate (list, 0))

    
    fun parseDirectives keyValues = 
        let
        
            fun parse (key, value, position) = case key of
                  "comment" => Comment
                | "description" => Description (value, position)
                | "maintainer" => Unparsed (key, value, position)
                | "keywords" => Unparsed (key, value, position)
                | "upstream-version" => Unparsed (key, value, position)
                | "upstream-url" => Unparsed (key, value, position)
                | "remote" => Remote (Protocol.fromString value, position)
                | "documentation-url" => Unparsed (key, value, position)
                | "bug-url" => Unparsed (key, value, position)
                | "license" => Unparsed (key, value, position)
                | "platform" => Unparsed (key, value, position)
                | "build" => Unparsed (key, value, position)
                | "test" => Unparsed (key, value, position)
                | "install" => Unparsed (key, value, position)
                | "uninstall" => Unparsed (key, value, position)
                | "documentation" => Unparsed (key, value, position)
                | "provides" => 
                    (case String.tokens Char.isSpace value of
                          [packageName, version] => Provides (packageName, SemVer.fromString version, position)
                        | _ => raise Error ("The syntax for the 'provides' field should resemble 'provides: my-package 1.2.3' on line " ^ Int.toString position))
                | "requires" => 
                    (case String.tokens Char.isSpace value of
                          (packageName :: constraint) => Requires (packageName, String.concatWith " " constraint, position)
                        | _ => raise Error ("The syntax for the 'requires' field should resemble 'requires: some-package >= 1.2.3' on line " ^ Int.toString position))
                | keyword => raise Error ("Unknown directive '" ^ keyword ^ "' on line " ^ Int.toString position)
            
            val directives = map parse keyValues
            
            val providesDirectives = List.mapPartial (fn (Provides directive) => SOME directive | _ => NONE) directives
            val provides = case providesDirectives of
                  [] => raise Error ("A 'provides' directive is required, eg: provides: mypackage 0.2.5")
                | [directive] => directive
                | (_ :: (_, _, position) :: _) => 
                    raise Error ("Only one 'provides' directive is allowed, but a second one is specified on line " ^ Int.toString position)
            
            val descriptionDirectives = List.mapPartial (fn (Description directive) => SOME directive | _ => NONE) directives
            val description = case descriptionDirectives of
                  [] => NONE
                | [directive] => SOME directive
                | (_ :: (_, position) :: _) => 
                    raise Error ("At most one 'description' directive is allowed, but a second one is specified on line " ^ Int.toString position)

            val remoteDirectives = List.mapPartial (fn (Remote directive) => SOME directive | _ => NONE) directives
            val remote = case remoteDirectives of
                  [] => raise Error ("A 'remote' directive is required, eg: remote: git git://example.org/foo.git")
                | [directive] => directive
                | (_ :: (_, position) :: _) => 
                    raise Error ("Only one 'remote' directive is allowed, but a second one is specified on line " ^ Int.toString position)

            val requires = List.mapPartial (fn (Requires directive) => SOME directive | _ => NONE) directives
            
            fun unparsed key = 
                let
                    val directives' = List.mapPartial 
                        (fn (Unparsed (key', value, position)) => 
                            if key' = key 
                                then SOME (value, position) 
                                else NONE | _ => NONE) 
                        directives
                in
                    case directives' of
                          [] => NONE
                        | [directive] => SOME directive
                        | (_ :: (_, position) :: _) => 
                            raise Error ("At most one '" ^ key ^ "' directive is allowed, but a second one is specified on line " ^ Int.toString position)
                end
                
        in
            {
                provides = provides,
                description = description,
                requires = requires,
                maintainer = unparsed "maintainer",
                upstreamVersion = unparsed "upstream-version",
                upstreamUrl = unparsed "upstream-url",
                remote = #1 remote,
                documentationUrl = unparsed "documentation-url",
                bugUrl = unparsed "bug-url", 
                license = unparsed "license",
                platform = unparsed "platform", 
                build = unparsed "build",
                test = unparsed "test",
                install = unparsed "install",
                uninstall = unparsed "uninstall",
                documentation = unparsed "documentation"
            }
        end
    

    fun parseKeyValues lines =
        let

            fun parseKeyLine (line, position) = 
                let
                    val (key,valueParts) = 
                        (fn (key :: valueParts) => (key,valueParts) | _ => raise Fail "parseKeyValues: key error") 
                            (String.fields (fn c => c = #":") line)
                in
                    if CharVector.all (fn c => Char.isAlphaNum c orelse c = #"-") key
                        then (key, String.concatWith ":" valueParts)
                        else raise Error ("The key '" ^ key ^ "' contains non-alphanumeric, non-dash characters on line " ^ Int.toString position)
                end
            
            fun parseValueLines (lines : (string * position) list) = 
                let
                    fun isValueLine (line, _) = String.size line = 0 orelse 
                        let
                            val c = String.sub (line, 0)
                        in
                            c = #"\r" orelse c = #"\n" orelse c = #" " orelse c = #"\t"
                        end
                        
                    val (lines', count) = dropWhile' isValueLine (lines, 0)
                in
                    (List.take (lines, count), lines')
                end

            fun parse ([], keyValues) = rev keyValues
              | parse ((line, position) :: lines, keyValues) = 
                    let
                        val (key, valueHead) = parseKeyLine (line, position)
                        val (valueTail, lines') = parseValueLines lines
                        val keyValue = (key, concat (valueHead :: map #1 valueTail), position)
                    in
                        parse (lines', keyValue :: keyValues)
                    end
                    
            val lines' = dropWhile (fn (line, _) => CharVector.all Char.isSpace line) lines
        in
            parse (lines', [])
        end 
    

    fun readLines (file, position, lines) = 
        case TextIO.inputLine file of
              NONE => rev lines
            | (SOME "\n") => readLines (file, position + 1, lines)
            | (SOME line) => readLines (file, position + 1, (line, position) :: lines)


    fun parseStream stream = 
        let
            val lines = readLines (stream, 1, [])
            val keyValues = parseKeyValues lines
        in
            parseDirectives keyValues
        end handle (e as Error s) => (
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
        handle (e as Error s) => (
            TextIO.output (TextIO.stdErr, "Error in '" ^ name ^ "': " ^ s ^ "\n"); 
            raise e
        )

    fun toString (spec : spec) = 
    let
        val provides = (#provides spec)
    in
        "provides: " ^ 
            #1 provides ^ " " ^ SemVer.toString (#2 provides)
    end

    fun toVersionSpec (spec : spec) =
    let
        val provides = (#provides spec)
    in
        (#1 provides, #2 provides, #remote spec)
    end

end

