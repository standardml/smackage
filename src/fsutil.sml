
structure FSUtil:>
sig
   (* Get all the lines from a file. *)
   val getLines: string -> string list

   (* Trims leading whitespace, trailing newlines, and #linecomments. *)
   val getCleanLines: string -> string list

   (* Run a system command, get the output. *)
   val systemLines: string -> string list
   
   (* Trims leading whitespace, trailing newlines, and #linecomments. *)
   val systemCleanLines: string -> string list

   (* Write lines to a file; adds newlines. *)
   val putLines: string list -> string -> unit
end = 
struct
   fun trim s =
   let
       fun trimStart (#" "::t) = trimStart t
         | trimStart (#"\t"::t) = trimStart t
         | trimStart l = l

       fun trimEnd (#"#"::t) = []
         | trimEnd (#"\n"::t) = []
         | trimEnd (h::t) = h :: trimEnd t
         | trimEnd [] = []
   in
       String.implode (trimEnd (trimStart (String.explode s)))
   end

   fun getLines' trimmer fileName = 
   let 
      val file = TextIO.openIn fileName
      fun loop accum = 
         case TextIO.inputLine file of 
            NONE => rev accum before TextIO.closeIn file
          | SOME s => loop (trimmer s :: accum)
   in
      loop []
   handle exn => (TextIO.closeIn file handle _ => (); raise exn)
   end

   val getLines = getLines' (fn x => x)
   val getCleanLines = getLines' trim

   
   fun putLines lines fileName = 
   let 
      val file = TextIO.openOut fileName
      fun loop lines =
         case lines of 
            [] => TextIO.closeOut file
          | line :: lines => 
               (TextIO.output (file, line ^ "\n"); loop lines) 
   in 
      loop []
   handle exn => (TextIO.closeOut file handle _ => (); raise exn)
   end

   fun systemLines' reader cmd =
   let 
      val tmpName = OS.FileSys.tmpName ()
      val cmd' = (cmd ^ " > " ^ tmpName)
      (* val () = print ("Running: `" ^ cmd' ^ "`\n") *)
      val () = 
         if OS.Process.isSuccess (OS.Process.system cmd')
         then () else raise Fail ("System call failed: `" ^ cmd' ^ "`")
      val cleanup = fn () => OS.FileSys.remove tmpName
   in         
      (reader tmpName before cleanup ())
      handle exn => (cleanup () handle _ => (); raise exn)
   end

   val systemLines = systemLines' getLines
   val systemCleanLines = systemLines' getCleanLines

end
