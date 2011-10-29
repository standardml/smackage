(** A thin helper wrapping curl.  Can retrieve files via HTTP.
 *  This should probably be in a seperate library?
 *  (Although it is kind of too bad to be worth doing that...)
 *)
structure CurlDownloader : HTTP_DOWNLOADER =
struct
  exception HttpException of string
  type url = string
  type filename = string

  fun retrieve url outputFile =
      if (OS.Process.isSuccess o OS.Process.system)
            ("curl -s " ^ url ^ " > " ^ outputFile)
      then ()
      else raise HttpException "download fail (retrieve)"

  fun retrieveLines url = 
     FSUtil.systemLines ("curl -s " ^ url)
     handle _ => raise HttpException "download fail (retrieveText)"

  fun retrieveCleanLines url = 
     FSUtil.systemLines ("curl -s " ^ url)
     handle _ => raise HttpException "download fail (retrieveText)"
end

