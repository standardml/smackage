(** A thin helper wrapping curl.  Can retrieve files via HTTP. *)
structure GetHttp =
struct
    exception HttpException

    fun retrieve url outputFile = 
    let
        val tmpName = OS.FileSys.tmpName ()
    in
        if OS.Process.system ("curl " ^ url ^ " > " ^ tmpName) <> 0
            then raise HttpException
            else OS.FileSys.rename {old=tmpName, new=outputFile}
                handle _ => raise HttpException
    end
end

