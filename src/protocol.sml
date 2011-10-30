
structure Protocol = 
struct
   datatype protocol = Git of { uri: string }
   type t = protocol

   fun toString prot = 
      case prot of 
         Git { uri } => "git " ^ uri

   fun fromString s =
      case String.tokens Char.isSpace s of
         [ "git", s ] => Git { uri = s }
       | _ => raise Fail ("Unknown protocol: `" ^ s ^ "`")

   fun compare (Git {uri}, Git {uri = uri'}) = String.compare (uri, uri') 
end

