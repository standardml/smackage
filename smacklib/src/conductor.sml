
structure Conductor:> CONDUCTOR =
struct
   fun package smackage_root_dir some_package =
     if some_package = "rob-toy" 
     then { poll = fn () => GetGit.poll "git://github.com/robsimmons/toy.git"
          , get = fn _ => raise Fail "Not done"}
     else raise Fail ( "I don't know where to find `" ^ some_package 
                     ^ "`, perhaps you need to run \"smack selfup\"")

end


