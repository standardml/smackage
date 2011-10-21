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

signature SEMVER =
sig
    eqtype semver

    exception InvalidVersion

    val fromString : string -> semver
    val toString : semver -> string
    val compare : semver * semver -> order
    val satisfies : semver * string -> bool
    val < : semver * semver -> bool
    val <= : semver * semver -> bool
    val >= : semver * semver -> bool
    val > : semver * semver -> bool
end

structure SemVer : SEMVER =
struct
    type semver = int * int * int * string option

    exception InvalidVersion

    fun fromString s =
    let
        val f = String.fields (fn #"." => true | _ => false) s
        val _ = if length f <> 3 then raise InvalidVersion else ()

        fun vtoi i = 
            case Int.fromString i of NONE => raise InvalidVersion | SOME v => v

        val major = vtoi (List.nth (f,0))
        val minor = vtoi (List.nth (f,1))
        
        fun until [] = []
          | until (h::t) = if Char.isDigit h then h :: until t else []

        val patch' = List.nth (f,2)
        val patch'' = String.implode (until (String.explode patch'))
        val str = if patch'' = patch' then NONE 
                    else SOME (String.extract (patch', size patch'', NONE))
        val patch = vtoi patch''

    in
        (major, minor, patch, str)
    end

    fun toString (ma,mi,pa,s) =
        Int.toString ma ^ "." ^
        Int.toString mi ^ "." ^
        Int.toString pa ^
        (if s = NONE then "" else valOf s)

    fun compare ((ma,mi,pa,st),(ma',mi',pa',st')) = 
        if ma < ma' then LESS else
        if ma > ma' then GREATER else
        if mi < mi' then LESS else
        if mi > mi' then GREATER else
        if pa < pa' then LESS else
        if pa > pa' then GREATER else
        (case (st,st') of
            (NONE,NONE) => EQUAL
          | (SOME _,NONE) => LESS
          | (NONE,SOME _) => GREATER
          | (SOME a, SOME b) => 
                if a = b then EQUAL else
                if String.<(a,b) then LESS else GREATER)

    fun a < b = compare (a,b) = LESS
    fun a <= b = compare (a,b) <> GREATER
    fun a >= b = compare (a,b) <> LESS
    fun a > b = compare (a,b) = GREATER

    (** Accepts a version and a version spec of the form:
      X.Y.Z   (exactly this version)
      < X.Y.Z
      > X.Y.Z
      <= X.Y.Z
      >= X.Y.Z
      <> X.Y.Z (not this version) *)
    fun satisfies (v, spec) =
    let
        val f = String.fields (fn #" " => true | _ => false) spec
        val (cmd,v') = 
            if (length f <> 1 andalso length f <> 2) then raise InvalidVersion
                else if length f = 1 then ("=",fromString (hd f)) else
                    (List.nth (f,0), fromString (List.nth (f,1)))
    in
        case cmd of
            "=" => v = v'
          | "<" => v < v'
          | ">" => v > v'
          | "<=" => v <= v'
          | ">=" => v >= v'
          | "<>" => v <> v'
          | _ => raise InvalidVersion
    end

end
