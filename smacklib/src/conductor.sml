
structure Conductor:> CONDUCTOR =
struct
   fun get smackagePath packageName ver prot = 
      case prot of 
         Protocol.Git { uri } => GetGit.get smackagePath packageName uri ver

   fun poll prot = 
      case prot of 
         Protocol.Git { uri } => map #2 (GetGit.poll uri)
end


