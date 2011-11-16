
structure Conductor:> CONDUCTOR =
struct
   fun get smackagePath packageName ver prot = 
      case prot of 
         Protocol.Git { uri } => GetGit.get smackagePath packageName uri ver
       | Protocol.Hg { uri } => GetHg.get smackagePath packageName uri ver

   fun poll name prot = let
      fun poll' poll uri = let
         fun prov (_, semver) = Spec.Provides (name, semver)
      in
         [Spec.Remote prot :: map prov (poll uri)]
      end
   in
      case prot of 
         Protocol.Git { uri } => poll' GetGit.poll uri
       | Protocol.Hg { uri } => poll' (GetHg.poll name) uri
   end
end


