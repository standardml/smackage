
structure FSUtil:>
sig
   (* Run a system command, get the output, clean up. *)
   (* XXX sully warns this won't work in SML/NJ if the file is > 20MB... *)
   val systemStr: string -> string

   (* Get all the lines from a file. *)
   val getLines: string -> string list

   (* Trims leading whitespace, trailing newlines, and #linecomments. *)
   val getCleanLines: string -> string list

   (* Write lines to a file; adds newlines. *)
   val putLines: string list -> string -> unit
end = 
struct
   fun systemStr cmd =
   let 
      val tmpName = OS.FileSys.tmpName ()
      val _ = OS.Process.system (cmd ^ " > " ^ tmpName)
      val tmp = TextIO.openIn tmpName
      val cleanup = fn () => OS.FileSys.remove tmpName
   in         
      (TextIO.inputAll tmp before (TextIO.closeIn tmp; cleanup ()))
      handle exn => 
       ( (TextIO.closeIn tmp; cleanup ()) handle _ => ()
       ; raise exn)
   end

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

   fun getLines' file trimmer accum = 
      case TextIO.inputLine file of 
         NONE => rev accum before TextIO.closeIn file
       | SOME s => getLines' file trimmer (trimmer s :: accum)

   fun getLines fileName = 
   let val file = TextIO.openIn fileName
   in
      getLines' file (fn s => s) []
   handle exn => (TextIO.closeIn file handle _ => (); raise exn)
   end

   fun getCleanLines fileName = 
   let val file = TextIO.openIn fileName
   in
      getLines' file trim []
   handle exn => (TextIO.closeIn file handle _ => (); raise exn)
   end

   fun putLines' file lines =
      case lines of 
         [] => TextIO.closeOut file
       | line :: lines => 
            (TextIO.output (file, line ^ "\n"); putLines' file lines) 
   
   fun putLines lines fileName = 
   let val file = TextIO.openOut fileName
   in 
      putLines' file []
   handle exn => (TextIO.closeOut file handle _ => (); raise exn)
   end

end
