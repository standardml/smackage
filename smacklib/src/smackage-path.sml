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

(** Deal with filesystem elements in a sensible way. *)
structure SmackagePath =
struct
    (** Return the full filesystem path to a package.
        XXX: Hard coded for local testing.  FIXME HAX HAX HAX.
    *)
    fun getPackageDir pkg = "/Users/gdpe/.smackage/" ^ pkg

    (** Retrieve a list of currently installed versions of pkg.
        We do this by listing the directory, and ignoring everything
        that's not a valid semantic version.  This ignores the symlinks
        like v1 and v1.6, and only gets the full versions like v1.6.2
    *)
    fun installedVersions pkg =
    let
        val pkgDir = getPackageDir pkg
        val dh = OS.FileSys.openDir pkgDir
        fun untilNone () = 
        let
            val v = OS.FileSys.readDir dh
        in
            if v = NONE then [] else (valOf v) :: untilNone ()
        end
        val values = untilNone () 
        val _ = OS.FileSys.closeDir dh
    in
        List.mapPartial (fn x => SOME (SemVer.fromString x) handle _ => NONE) values
    end 

    fun createPackagePaths (pkg,ver) =
    let
        val newPaths = map (fn x => pkg ^ "/" ^ x) (SemVer.allPaths ver)
        
    in
        newPaths
    end
end

