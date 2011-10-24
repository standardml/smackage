(** A thin helper wrapping curl.  Can retrieve files via HTTP.
 *  This should probably be in a seperate library?
 *  (Although it is kind of too bad to be worth doing that...)
 *)
structure CurlDownloader : HTTP_DOWNLOADER =
struct
  exception HttpException of string
  type url = string
  type filename = string

  fun retrieveTemp url =
      let val tmpName = OS.FileSys.tmpName ()
      in (* XXX: FIXME: security bug if url is untrusted. *)
          if not (OS.Process.isSuccess (OS.Process.system ("curl " ^ url ^ " > " ^ tmpName)))
          then raise HttpException "download fail"
          else tmpName
      end

  fun retrieve url outputFile = 
      let
          val tmpName = retrieveTemp url
      in
          OS.FileSys.rename {old=tmpName, new=outputFile}
          handle _ => raise HttpException "failure to rename file"
      end

  fun handleIOError error = raise HttpException "file IO error"

  (* LIB: This really should be in a library somewhere. *)
  fun finally f final =
      (f () handle e => (final (); raise e))
      before (final ())

  (* Return the contents of a file. Won't work in SML/NJ if the file is
   * more than 20MB... *)
  (* LIB: This really should be in a library somewhere. *)
  fun readFile fname =
      let val file = TextIO.openIn fname
      in finally
             (fn () => TextIO.inputAll file)
             (fn () => TextIO.closeIn file)
      end

  fun retrieveText url =
      let val tmpName = retrieveTemp url
      in finally
             (fn () => readFile tmpName handle IO.Io e => handleIOError e)
             (fn () => OS.FileSys.remove tmpName
                 handle _ => raise HttpException "failed to remove temp file")
      end
end

