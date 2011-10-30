(* Manipulating packages with git *)
(* Try running 'GetGit.poll "git://github.com/robsimmons/toy.git"' *)
(* Robert J. Simmons *)

structure GetGit = struct

fun systemSuccess s = 
let (* val () = print ("Running: `" ^ s ^ "'\n") *) in
   if OS.Process.isSuccess (OS.Process.system s) then ()
   else raise Fail ("System call `" ^ s ^ "' returned failure")
end

(*[ val poll: string -> (string * SemVer.semver) list ]*)
(* List of X.Y.Z versions provided by a repository *)
fun poll (gitAddr: string) = 
   let
      fun eq c1 c2 = c1 = c2 
      val input = FSUtil.systemLines ("git ls-remote " ^ gitAddr)
      fun process str =
         let exception Skip 
            val (hash, remote) = 
                case String.tokens Char.isSpace str of 
                   [ hash, remote ] => 
                       if size hash <> 40   
                       then raise Fail "Bad hash returned from git ls-remote"
                       else if String.isSuffix "^{}" remote 
                       then raise Skip (* Proposed bugfix for git tag -m "" 
                                          - Oct 24 2011 RJS *)
                       else (hash, String.tokens (eq #"/") remote) 
                 | _ => raise Fail "Unexpected output from `git ls-remote'"

            val tag =       
               case remote of
                  [ "refs", "tags", tag ] => 
                  if String.sub (tag, 0) = #"v" 
                  then String.extract (tag, 1, NONE)
                  else raise SemVer.InvalidVersion (* Not a version tag *)
                | _ => raise SemVer.InvalidVersion (* Not a tag at all *)
         in 
            SOME (hash, SemVer.fromString tag)
         end handle Fail s => raise Fail s
                  | _ => NONE
   in
      List.mapPartial process input
   end handle _ => raise Fail "I/O error trying to access temporary file"

fun chdirSuccess s = 
   let (* val () = print ("Changing directory: `" ^ s ^ "'\n") *) in
      OS.FileSys.chDir s
   end

fun download gitAddr = 
   ( OS.FileSys.mkDir ("unstable")
   ; chdirSuccess ("unstable")
   ; systemSuccess ("git init --quiet")
   ; systemSuccess ("git remote add origin " ^ gitAddr))

(*[ val get: string -> string -> SemVer.semver -> unit ]*)
fun get basePath projName gitAddr semver = 
   let val olddir = OS.FileSys.getDir () in 
   let 
      val projPath' = OS.Path.joinDirFile { dir = basePath, file = "lib" } 
      val projPath = OS.Path.joinDirFile { dir = projPath', file = projName } 
      val () = if OS.FileSys.isDir projPath then () 
               else raise Fail ("file `" ^ projName 
                                ^ "' exists and isn't a directory")
      val () = chdirSuccess projPath

      (* Get the repository in place if it's not there *)
      val repoPath = OS.Path.joinDirFile { dir = projPath, file = "unstable" }
      val () = if OS.FileSys.access (repoPath, []) 
               then (if OS.FileSys.isDir repoPath then ()
                     else raise Fail "file `unstable' exists and isn't\
                                     \ a directory")
               else download gitAddr 

      (* Update the repository *)
      val () = chdirSuccess repoPath
      val () = systemSuccess ("git fetch origin master --tags --quiet")
      val () = print "Repository is updated\n" 

      (* Output via cloning *)
      val ver = "v" ^ SemVer.toString semver
      val verPath = OS.Path.joinDirFile { dir = projPath, file = ver }
      val () = chdirSuccess verPath
      val () = systemSuccess ("git init --quiet")
      val () = systemSuccess ("git remote add origin " ^ (OS.Path.joinDirFile { dir = "..", file = "unstable" }))
      val () = systemSuccess ("git fetch --tags --quiet")
      val () = systemSuccess ("git checkout " ^ ver ^ " --quiet")

      (* Clean up *)
      val () = systemSuccess ( "rm -Rf .git" )
   in
      chdirSuccess olddir
   end handle exn => (OS.FileSys.chDir olddir; raise exn) end
end

