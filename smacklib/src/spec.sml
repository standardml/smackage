signature SPEC =
sig

    exception Error of string

    type position

    type packageName

    type requirement

    type package
    
    type description
    
    type smackspec
    
    val parseFile : string -> smackspec
    
end


structure Spec : SPEC =
struct

    exception Error of string

    type position = int

    type packageName = string

    type requirement = packageName * SemVer.constraint * position

    type package = packageName * SemVer.semver * position
    
    type description = string * position
    
    type smackspec = {
        provides : package,
        description : description option,
        requires : requirement list
        }
         
    datatype directive
        = Comment
        | Provides of package
        | Description of description
        | Requires of requirement

        
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
                | "provides" => 
                    let
                        val [packageName, version] = String.tokens Char.isSpace value
                    in
                        Provides (packageName, SemVer.fromString version, position)
                    end
                | "description" => Description (value, position)
                | "requires" => 
                    let
                        val (packageName :: constraint) = String.tokens Char.isSpace value
                    in
                        Requires (packageName, String.concatWith " " constraint, position)
                    end
                | keyword => raise Error ("Unknown directive '" ^ keyword ^ "' on line " ^ Int.toString position)
            
            val directives = map parse keyValues
            
            val providesDirectives = List.mapPartial (fn (Provides directive) => SOME directive | _ => NONE) directives
            val provides = case providesDirectives of
                  [] => raise Error ("A 'provides' directive is required, eg: provides: mypackage 0.2.5")
                | [directive] => directive
                | (_ :: (_, _, position) :: _) => raise Error ("Only one 'provides' directive is allowed, but a second one is specified on line " ^ Int.toString position)
            
            val descriptionDirectives = List.mapPartial (fn (Description directive) => SOME directive | _ => NONE) directives
            val description = case descriptionDirectives of
                  [] => NONE
                | [directive] => SOME directive
                | (_ :: (_, position) :: _) => raise Error ("At most one 'description' directive is allowed, but a second one is specified on line " ^ Int.toString position)

            val requires = List.mapPartial (fn (Requires directive) => SOME directive | _ => NONE) directives
        in
            {
                provides = provides,
                description = description,
                requires = requires
            }
        end
    

    fun parseKeyValues lines =
        let

            fun parseKeyLine line = 
                let
                    val (key :: valueParts) = String.fields (fn c => c = #":") line
                in
                    (key, String.concatWith ":" valueParts)
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
                        val (key, valueHead) = parseKeyLine line
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
            | (SOME line) => readLines (file, position + 1, (line, position) :: lines)


    fun parseFile filename : smackspec =
        let
            val file = TextIO.openIn filename
            val lines = readLines (file, 1, [])
            val _ = TextIO.closeIn file
            val keyValues = parseKeyValues lines
        in
            parseDirectives keyValues
        end

end

