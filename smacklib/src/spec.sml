signature SPEC =
sig

    type position

    type packageName

    type requirement

    type smackspec
    
    (* Parses KEY: VALUE where KEY is alphanumeric and VALUE is any string, 
       continuing as long as every line is either indented by one or more spaces or tabs,
       or is empty. *)
    val parseKeyValues : (string * position) list -> (string * string * position) list

end


structure Spec (*: SPEC*) =
struct

    type position = int

    type packageName = string

    type requirement = packageName * string * position

    type package = packageName * SemVer.semver * position
    
    type description = string option * position
    
    type requirements = requirement list
    
    type smackspec = {
        package : package,
        description : description,
        requirements : requirements
        }

    datatype directive
        = Provides of package
        | Description of description
        | Requirement of requirement
        
    fun dropWhile' predicate ([], count) = ([], count)
      | dropWhile' predicate ((head :: tail), count) = 
            if predicate head
                then dropWhile' predicate (tail, count + 1)
                else (head :: tail, count)

    fun dropWhile predicate list = #1 (dropWhile' predicate (list, 0))
    
    fun parseDirectives keyValues = 
        let
        
            fun parse (key, value, position) = case key of
                  "provides" => 
                    let
                        val [packageName, version] = String.tokens Char.isSpace value
                    in
                        Provides (packageName, SemVer.fromString version, position)
                    end
                | "description" => Description (SOME value, position)
                | "requires" => 
                    let
                        val (packageName :: constraint) = String.tokens Char.isSpace value
                    in
                        Requirement (packageName, String.concatWith " " constraint, position)
                    end
            
            val directives = map parse keyValues
        in
            ()
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

    fun parseFile filename =
        let
            val file = TextIO.openIn filename
            val lines = readLines (file, 1, [])
            val _ = TextIO.closeIn file
            val keyValues = parseKeyValues lines
        in
            parseDirectives keyValues
        end

end

