(******************************************************************************
 Smackage SML Package System
 
 Copyright (c) 2011, Gian Perrone <gdpe at itu dot dk>
 All rights reserved.

 Redistribution and use in source and binary forms, with or without 
 modification, are permitted provided that the following conditions are met:

 Redistributions of source code must retain the above copyright notice, this 
 list of conditions and the following disclaimer.

 Redistributions in binary form must reproduce the above copyright notice, 
 this list of conditions and the following disclaimer in the documentation 
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
 INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
 CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
 ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
******************************************************************************)

(** Stateful configuration, hopefully with sensible defaults *)
structure Configure =
struct
   val smackHome = ref "<dummy>"

   val smackSources: string list ref = ref [] 

   (** Attempt to ascertain the smackage home directory.
       Resolved in this order:

       SMACKAGE_HOME environment variable
       ~/.smackage/
       /usr/local/smackage/
       /opt/smackage/
   *)
   fun initSmackHome () = 
      let
         fun tryDir (SOME s) = ((OS.FileSys.openDir s; true) handle _ => false)
           | tryDir NONE = false
         val envHome = OS.Process.getEnv "SMACKAGE_HOME"
         val envHome' = 
            case OS.Process.getEnv "HOME" of 
               NONE => NONE
             | SOME home =>
                  SOME (OS.Path.joinDirFile { dir = home, file = ".smackage" })
      in
         if tryDir envHome then smackHome := valOf envHome else
         if tryDir envHome' then smackHome := valOf envHome' else
         if tryDir (SOME "/usr/local/smackage") 
            then smackHome := "/usr/local/smackage" else
         if tryDir (SOME "/opt/smackage") 
            then smackHome := "/opt/smackage" else
         raise Fail "Cannot find smackage home. Try setting SMACKAGE_HOME"
      end

   fun initSourcesLocal () = 
      let
         val sourcesLocal =
            OS.Path.joinDirFile { dir = !smackHome, file = "sources.local" }
         fun create () = 
            let
               val () = 
                  print "NOTICE: `sources.local` doesn't exist in\
                        \ $(SMACKAGE_HOME), trying to create it.\n"
               val file = TextIO.openOut sourcesLocal
            in
               ( TextIO.output 
                    (file, "rob-toy git git://github.com/robsimmons/toy.git")
               ; TextIO.closeOut file)
            end
      in
         if not (OS.FileSys.access (sourcesLocal, []))
           then create () else
         if not (OS.FileSys.access (sourcesLocal, [ OS.FileSys.A_READ
                                                  , OS.FileSys.A_WRITE ]))
           then raise Fail "Can't read/write to sources.local (run as sudo?)" 
         else ()
      end handle exn => 
             ( print "Error checking `sources.local` file.\n"
             ; raise exn)

   fun readConfigFile () = 
      let
         val config = OS.Path.joinDirFile { dir = !smackHome, file = "config" }

         fun defaults () = 
            ( smackSources := [ "sources.local" ] )

         fun loop file = 
            case Option.map 
                    (String.tokens Char.isSpace) 
                    (TextIO.inputLine file) of 
               NONE => TextIO.closeIn file
             | SOME [] => loop file
             | SOME [ "source", file ] => 
                  ( smackSources := !smackSources @ [ file ])
             | SOME s => 
                  raise Fail ( "Bad configuration line: " 
                             ^ String.concatWith " " s )
      in 
         if not (OS.FileSys.access (config, []))
           then defaults () else
         if not (OS.FileSys.access (config, [ OS.FileSys.A_READ ]))
           then raise Fail "Config file exists but can't be read"
         else loop (TextIO.openIn config) 
      end

   fun init () =
      ( initSmackHome ()
      ; initSourcesLocal ()
      ; readConfigFile ())
        
(*
   fun readConfig () = 
      let
         val config = 
            OS.FileSys.joinDirPath { dir = smackHome, file = "config" } 
      in
         if OS.FileSys.access (config, [ OS.FileSys.A_READ ])
         then 
         else ()
      end
*)
end
