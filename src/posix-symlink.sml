structure Symlink =
struct
  fun replaceOrCreateSymlink dst link =
      let
          (* Delete the old link if it exists *)
          val e = OS.FileSys.isLink link handle _ => false
          val _ = 
              (if e then OS.FileSys.remove link else ())
              handle _ => ()

          (* Create the new one *)
          val _ = Posix.FileSys.symlink {old = dst, new = link}
      in
          ()
      end
end
