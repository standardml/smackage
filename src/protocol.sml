
structure Protocol = 
struct
   datatype protocol =
      Git of { uri: string }
    | Hg of { uri: string }
   type t = protocol

   fun toString prot = 
      case prot of 
         Git { uri } => "git " ^ uri
       | Hg { uri } => "hg " ^ uri

   fun get s t =
      case t of
         Git ? => s ?
       | Hg ? => s ?

   fun fromString s =
      case String.tokens Char.isSpace s of
         [ "git", s ] => Git { uri = s }
       | [ "hg", s ] => Hg { uri = s }
       | _ => raise Fail ("Unknown protocol: `" ^ s ^ "`")

   fun compare (a, b) = String.compare (get#uri a, get#uri b)
end
