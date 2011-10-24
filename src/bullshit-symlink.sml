(* This is a fake "symlink" implementation that works by copying the directory
 * tree. We need this on windows. Currently, we rely on unix utilities being
 * in the path, though. *)
structure Symlink =
struct
  (* This scares me a lot. *)
  fun remove s = 
      if not (OS.Process.isSuccess (OS.Process.system ("rm -rf " ^ s)))
      then raise Fail "removing old version directory failed" else ()

  fun copyDir dst src =
      let
         val print = fn _ => () (* comment this to debug *) 
         val () = print ("Current directory: " ^ OS.FileSys.getDir () ^ "\n")
         val line = "cp -r " ^ src ^ " " ^ dst 
         val () = print ("COPY: " ^ line ^ "\n")
      in
         if not (OS.Process.isSuccess (OS.Process.system line))
         then raise Fail "copying version failed" else ()
      end

  fun replaceOrCreateSymlink target link =
      let
          (* Delete the old directory if it exists *)
          val e = OS.FileSys.isDir link handle _ => false
          val _ = if e then remove link else ()

          (* Create the new one *)
          val _ = copyDir link target
      in
          ()
      end
      handle (Fail s) => (print (s ^ "\n"); raise Fail s)
end
