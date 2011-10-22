
structure Conductor:> CONDUCTOR =
struct
   fun package _ = raise Match

   fun get smackagePath packageName ver prot = 
      case prot of 
         Protocol.Git { uri } => GetGit.get smackagePath packageName uri ver
end


