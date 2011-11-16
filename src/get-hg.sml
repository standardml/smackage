(* Manipulating packages with mercurial *)
(* Try running 'GetHg.poll "http://codemonkey.com/mb0/extended-basis"' *)
(* Robert J. Simmons *)

structure GetHg = struct

   fun run s =
      if OS.Process.isSuccess (OS.Process.system s)
         then ()
      else raise Fail ("System call `" ^ s ^ "' returned failure")

   (** Convinience functions for handling mercurial repositories. *)
   structure Hg = struct
      (** Clone a mercurial repository from `remote` into `localPath` *)
      fun clone {remote, localPath} =
         run ("hg clone --quiet " ^ remote ^ " " ^ localPath)

      (** Pull changesets from `remoteOption` or the default remote repository.
       * 
       * The changesets will be stored in the repository given by `localPath`. *)
      fun pull {remoteOption, localPath} = let
         infix >>
         fun cmd >> effect = effect cmd
      in
         (case remoteOption
          of SOME remote => "hg pull --quiet -R " ^ localPath ^ " " ^ remote
           | NONE => "hg pull --quiet -R " ^ localPath) >> run
      end

      (** Update the working tree of the given repository `localPath` to
       * mercurial's *tip* *)
      fun update localPath =
         run ("hg update --quiet -R " ^ localPath)

      (** Checkout a given revision in the repository `localPath`. *)
      fun checkout {revision, localPath} =
         run ("hg checkout --quiet -R " ^ localPath ^ " " ^ revision)
   end

   infix </> 
   fun dir </> file = OS.Path.joinDirFile {dir=dir, file=file}
   fun exists fp = OS.FileSys.access (fp, [])
   fun ensureIsDirectory fp = 
      if exists fp andalso not (OS.FileSys.isDir fp)
         then raise Fail ("file `" ^ fp ^ "' exists and isn't a directory")
      else ()
   fun maybeCloneRepository remote localPath =
      if exists localPath
         then ()
      else (ensureIsDirectory localPath; Hg.clone {localPath=localPath, remote=remote})

   (*[ val poll: string -> (string * SemVer.semver) list ]*)
   (* List of X.Y.Z versions provided by a repository *)
   (* NOTE: Since mercurial doesn't support remote quering of tags, we may have
    * to do an inital clone of the remote repository. *)
   fun poll name (address: string) = let
      fun readTags path =
         FSUtil.systemLines ("hg tags -R " ^ path)
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
      val unstablePath = !Configure.smackHome </> "lib" </> name </> "unstable"
   in
      maybeCloneRepository address unstablePath
    ; Hg.pull {remoteOption=NONE, localPath=unstablePath}
    ; Hg.update unstablePath
    ; Hg.checkout {revision="tip", localPath=unstablePath}
    ; List.mapPartial split (readTags unstablePath)
   end

   (*[ val get: string -> string -> SemVer.semver -> unit ]*)
   fun get base name address semver = let
      fun updateRepository unstablePath =
         (Hg.pull {localPath=unstablePath, remoteOption=NONE}
        ; Hg.update unstablePath
        ; print "Repository updated\n")
      fun checkoutVersion origin version = let
         val version = "v" ^ SemVer.toString version
         val clone = base </> "lib" </> name </> version
      in
         (Hg.clone {remote=origin, localPath=clone}
        ; Hg.checkout {revision=version, localPath=clone}
          (* FIXME: what about windows, or !*nix? *)
        ; run ("rm -Rf " ^ (clone </> ".hg")))
      end
      val unstablePath = base </> "lib" </> name </> "unstable"
   in
      (maybeCloneRepository address unstablePath
     ; updateRepository unstablePath
     ; checkoutVersion unstablePath semver)
   end
end
