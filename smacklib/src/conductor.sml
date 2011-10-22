
structure Conductor:> CONDUCTOR =
struct
   datatype protocol =
      Git of string

   (* XXX PERF GOOD GRIEF MAKE THIS A HASH MAP OR SOMETHING *)
   val pkg_map: (string * protocol) list ref = 
      ref [ ("rob-toy", Git "git://github.com/robsimmons/toy.git") ]

   fun insert' (less, []) name prot =
          List.revAppend (less, [ (name, prot) ])
     | insert' (less, (name', prot') :: greater) name prot =
         (case String.compare (name, name') of
             LESS => 
                List.revAppend (less, (name, prot) :: (name', prot') :: greater)
           | EQUAL => 
                List.revAppend (less, (name, prot) :: greater)
           | GREATER => 
                insert' ((name', prot') :: less, greater) name prot)

   fun insert name prot = pkg_map := insert' ([], !pkg_map) name prot

   fun find' [] name = NONE
     | find' ((name', prot) :: greater) name = 
         (case String.compare (name, name') of
             LESS => NONE
           | EQUAL => SOME prot
           | GREATER => find' greater name)

   fun find name = find' (!pkg_map) name

   fun loadDef (name, protocol, uri) = 
      case protocol of 
         "git" => insert name (Git uri)
       | _ => raise Fail ("Protocol `" ^ protocol ^ "` not understood")

   fun package smackage_root_dir some_package =
      case find some_package of
         NONE => 
            raise Fail ( "I don't know where to find `" ^ some_package 
                       ^ "`, perhaps you need to run \"smack selfup\"")
       | SOME (Git protocol) =>
          { poll = fn () => GetGit.poll protocol,
            get = GetGit.get smackage_root_dir some_package protocol }
end


