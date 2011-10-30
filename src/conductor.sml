
structure Conductor:> CONDUCTOR =
struct
   fun get smackagePath packageName ver prot = 
      case prot of 
         Protocol.Git { uri } => GetGit.get smackagePath packageName uri ver

   fun poll name prot = 
      case prot of 
         Protocol.Git { uri } =>
         let fun prov (_, semver) = Spec.Provides (name, semver)
         in
            [ Spec.Remote prot :: map prov (GetGit.poll uri) ]
         end
end


