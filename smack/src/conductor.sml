
structure Conductor:> CONDUCTOR =
struct
   type semver = int * int * int * string
   fun package name =
     if name = "rob-toy" 
     then { poll = fn () => GetGit.poll "git://github.com/robsimmons/toy.git"
          , get = fn () => raise Fail "Not done"}
     else raise Fail ( "I don't know where to find `" ^ name ^ "`, perhaps\ 
                     \ you need to run \"smack selfup\"")

end


