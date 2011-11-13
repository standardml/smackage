(* Manipulating packages with mercurial *)
(* Try running 'GetHg.poll "http://codemonkey.com/mb0/extended-basis"' *)
(* Robert J. Simmons *)

structure GetHg = struct

   fun run s = let
      (* val () = print ("Running: `" ^ s ^ "'\n") *)
   in
      if OS.Process.isSuccess (OS.Process.system s)
         then ()
      else raise Fail ("System call `" ^ s ^ "' returned failure")
   end

   (*[ val poll: string -> (string * SemVer.semver) list ]*)
   (* List of X.Y.Z versions provided by a repository *)
   (* NOTE: Since mercurial doesn't support remote quering of tags, we have
    * to create a temporary clone of the desired repository and issue the command
    * locally... The api of `poll` needs to be changed to fix this issue. *)
   fun poll (address: string) = 
      let
         fun tmpdir () = let
            val fp = OS.FileSys.tmpName ()
            val dp = fp ^ "-temporary-hg-clone"
         in
            OS.FileSys.mkDir dp; dp
         end

         val clonePath = tmpdir ()

         fun createTemporaryClone () =
            run ("hg --quiet clone " ^ address ^ " " ^ clonePath)

         fun readTags () =
            FSUtil.systemLines ("hg tags -R " ^ clonePath)

         fun split tagAndRev = let
            val (tag, rev) =
               case String.tokens Char.isSpace tagAndRev of
                  [hash, rev] => (hash, rev)
                | _ => raise Fail "Unexpected output from `hg tags'"
         in
            if String.sub (tag, 0) = #"v"
               then SOME (rev, SemVer.fromString (String.extract (tag, 1, NONE)))
            else NONE
         end
      in
         createTemporaryClone ()
       ; List.mapPartial split (readTags ())
      end

   fun initialize path address =
     run ("hg clone --quiet " ^ address ^ " " ^ path)

   (*[ val get: string -> string -> SemVer.semver -> unit ]*)
   fun get base name address semver = let
      infix </> 
      val olddir = OS.FileSys.getDir ()
      fun dir </> file = OS.Path.joinDirFile {dir=dir, file=file}
      fun exists fp = OS.FileSys.access (fp, [])
      fun ensureIsDirectory fp = 
         if exists fp andalso not (OS.FileSys.isDir fp)
            then raise Fail ("file `" ^ fp ^ "' exists and isn't a directory")
         else ()
      fun maybeInitializeRepository path =
         if exists path
            then ()
         else (ensureIsDirectory path; initialize path address)
      fun updateRepository unstablePath =
         (run ("hg pull --quiet -R " ^ unstablePath)
        ; run ("hg update --quiet -R " ^ unstablePath)
        ; print "Repository updated\n")
      fun cloneRepositoryVersion origin version = let
         val version = "v" ^ SemVer.toString version
         val clone = base </> "lib" </> name </> version
      in
         (run ("hg clone --quiet " ^ origin ^ " " ^ clone)
        ; run ("hg checkout --quiet -R " ^ clone ^ " " ^ version)
        ; run ("rm -Rf " ^ (clone </> ".hg")))
      end
      val unstablePath = base </> "lib" </> name </> "unstable"
   in
      (maybeInitializeRepository unstablePath
     ; updateRepository unstablePath
     ; cloneRepositoryVersion unstablePath semver)
   end
end
