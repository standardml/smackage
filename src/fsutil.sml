structure FSUtil:>
sig
   (* Write a series of lines to a file. Adds a newline to every string. *)
   val putLines: string -> string list -> unit

   (* ...Lines: Get the raw list of lines. *)
   (* ...CleanLines: Also trim leading whitespace, newlines, #comments. *)
   (* ...Stanzas: Also split up into empty-line separated segments. *)

   (* Read from a TextIO stream. *)
   val getLines: TextIO.instream -> string list
   val getCleanLines: TextIO.instream -> string list
   val getStanzas: TextIO.instream -> string list list

   (* Read from a system call. *)
   val systemLines: string -> string list
   val systemCleanLines: string -> string list
   val systemStanzas: string -> string list list
end = 
struct
   fun putLines fileName lines = 
   let 
      val file = TextIO.openOut fileName
      fun loop lines =
         case lines of 
            [] => TextIO.closeOut file
          | line :: lines => 
               (TextIO.output (file, line ^ "\n"); loop lines) 
   in 
      loop lines
   handle exn => (TextIO.closeOut file handle _ => (); raise exn)
   end

   fun trim s =
   let
       fun trimStart (#" "::t) = trimStart t
         | trimStart (#"\t"::t) = trimStart t
         | trimStart l = l

       fun trimEnd (#"#"::t) accum = rev accum
         | trimEnd (#"\n"::t) accum = rev accum
         | trimEnd (h::t) accum = trimEnd t (h :: accum)
         | trimEnd [] accum = rev accum
   in
       String.implode (trimEnd (trimStart (String.explode s)) [])
   end

   fun getLines' trimmer splitter file = 
   let 
      fun loop accum stanzas = 
         case TextIO.inputLine file of 
            NONE => 
               if null accum
               then (rev stanzas before TextIO.closeIn file)
               else (rev (rev accum :: stanzas) before TextIO.closeIn file)
          | SOME s => 
               if splitter s 
               then (if null accum
                     then loop accum stanzas
                     else loop [] (rev accum :: stanzas))
               else loop (trimmer s :: accum) stanzas
   in
      loop [] []
   handle exn => (TextIO.closeIn file handle _ => (); raise exn)
   end

   fun isEmpty [] = true
     | isEmpty (c :: cs) = if Char.isSpace c then isEmpty cs else false

   val getLines = hd o getLines' (fn x => x) (fn _ => false)
   val getCleanLines = hd o getLines' trim (fn _ => false)
   val getStanzas = getLines' trim (null o (String.tokens Char.isSpace))

   fun systemLines' reader cmd =
   let 
      val tmpName = OS.FileSys.tmpName ()
      val cmd' = (cmd ^ " > " ^ tmpName)
      (* val () = print ("Running: `" ^ cmd' ^ "`\n") *)
      val () = 
         if OS.Process.isSuccess (OS.Process.system cmd')
         then () else raise Fail ("System call failed: `" ^ cmd' ^ "'")
      val cleanup = fn () => OS.FileSys.remove tmpName
   in         
      (reader (TextIO.openIn tmpName) before cleanup ())
      handle exn => (cleanup () handle _ => (); raise exn)
   end

   val systemLines = systemLines' getLines
   val systemCleanLines = systemLines' getCleanLines
   val systemStanzas = systemLines' getStanzas

end
