(* Manipulating packages with git *)
(* Try running 'GetGit.poll "git://github.com/robsimmons/toy.git"' *)
(* Robert J. Simmons *)

structure GetGit = struct

(*[ val poll: string -> (string * (int * int * int * string)) list ]*)
(* List of X.Y.Z versions provided by a repository *)
fun poll (gitAddr: string) = 
   let
      fun eq c1 c2 = c1 = c2 

      val tmpName = OS.FileSys.tmpName ()
      val _ = OS.Process.system ("git ls-remote " ^ gitAddr ^ " > " ^ tmpName)
      val tmp = TextIO.openIn tmpName
      val input = 
         String.tokens (eq #"\n")
            (TextIO.inputAll tmp before TextIO.closeIn tmp)
         handle exn => (TextIO.closeIn tmp handle _ => (); raise exn)
       
      exception NotSemVar
      fun process str =
         let val (hash, remote) = 
                case String.tokens Char.isSpace str of 
                   [ hash, remote ] => 
                       if size hash <> 40   
                       then raise Fail "Bad hash returned from git ls-remote"
                       else (hash, String.tokens (eq #"/") remote)
                 | _ => raise Fail "Unexpected output from `git ls-remote`"

            val tag =       
               case remote of
                  [ "refs", "tags", tag ] => 
                  if String.sub (tag, 0) = #"v" 
                  then String.extract (tag, 1, NONE)
                  else raise NotSemVar (* Not a version tag *)
                | _ => raise NotSemVar (* Not a tag at all *)

            fun numAndMore str = 
               case Int.fromString str of 
                  NONE => NONE
                | SOME i => 
                  SOME (i, String.extract (str, size (Int.toString i), NONE))

            val (major, minor, patch, ps) = 
               case map numAndMore (String.tokens (eq #".") tag) of
                  [ SOME (major, ""), SOME (minor, ""), SOME (patch, ps) ] =>
                  (major, minor, patch, ps)
                | _ => raise NotSemVar

            (* XXX check that ps is [A-Za-z][0-9A-Za-z-]* *)
         in 
            SOME (hash, (major, minor, patch, ps))
         end handle NotSemVar => NONE
   in
      List.mapPartial process input
   end handle _ => raise Fail "I/O error trying to access temporary file"

end

