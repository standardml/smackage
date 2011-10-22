signature SEMVER =
sig
    eqtype semver
    type constraint

    exception InvalidVersion

    val fromString : string -> semver
    val toString : semver -> string
    val compare : semver * semver -> order
    val satisfies : semver * constraint -> bool
    val < : semver * semver -> bool
    val <= : semver * semver -> bool
    val >= : semver * semver -> bool
    val > : semver * semver -> bool
    val allPaths : semver -> string list
end

structure SemVer : SEMVER =
struct
    type semver = int * int * int * string option
    type constraint = string

    exception InvalidVersion

    fun fromString s =
    let
        val s' = if String.sub (s,0) = #"v" 
                    then String.extract (s, 1, NONE)
                    else s
        val f = String.fields (fn #"." => true | _ => false) s'

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

    (** Accepts a version and a version constraint of the form:
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

    (** Enumerate the various paths that this version could give rise to.
        e.g., for version 1.6.2beta1, we could potentially have these paths:
        v1, v1.6, v1.6.2beta1 *)
    fun allPaths (v as (ma,mi,pa,ps)) =
        ["v" ^ Int.toString ma,
         "v" ^ Int.toString ma ^ "." ^ Int.toString mi,
         "v" ^ toString v]

end
