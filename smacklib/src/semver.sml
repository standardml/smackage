signature SEMVER =
sig
    type semver
    type constraint

    exception InvalidVersion

    val fromString : string -> semver
    val toString : semver -> string
    val eq : semver * semver -> bool
    val compare : semver * semver -> order
    val satisfies : semver * constraint -> bool
    val < : semver * semver -> bool
    val <= : semver * semver -> bool
    val >= : semver * semver -> bool
    val > : semver * semver -> bool
    val allPaths : semver -> string list

    (* intelligentSelect is a way of resolving a partially-specified semantic
     * version which makes sense to Rob at the time.
     *
     * It will prefer tags with special versions over tags with 
     * no versions (so `intelligentSelect NONE [ 2.0.0beta, 1.9.3 ]` will 
     * return `SOME 1.9.3`) but will prefer nothing to something (so 
     * `intelligentSelect (SOME "v2") [ 2.0.0beta, 1.9.3 ]` or 
     * `intelligentSelect (SOME "2") [ 2.0.0beta, 1.9.3 ]` will return 
     * `SOME 2.0.0beta` with the assumption that they meant to do that *)
    val intelligentSelect : string option -> semver list -> semver option
end

structure SemVer : SEMVER =
struct
    type semver = int * int * int * string option
    type constraint = string

    exception InvalidVersion

    fun eq (x: semver, y) = x = y

    fun fromString' s =
    let
        val s' = if String.sub (s,0) = #"v" 
                    then String.extract (s, 1, NONE)
                    else s
        val f = String.fields (fn #"." => true | _ => false) s'

        fun fail () = raise Fail ("`" ^ s ^ "` not a valid semantic version")
        fun vtoi i = 
            case Int.fromString i of 
               NONE => fail ()
             | SOME v => v
    in
        case f of 
           [ major ] => (vtoi major, NONE, NONE, NONE)
         | [ major, minor ] => (vtoi major, SOME (vtoi minor), NONE, NONE)
         | [ major, minor, patch ] =>
           let 
              fun until [] = []
                | until (h::t) = if Char.isDigit h then h :: until t else []
              val patchN = String.implode (until (String.explode patch))
              val special = 
                 if patch = patchN then NONE 
                 else SOME (String.extract (patch, size patchN, NONE))
           in
              (vtoi major, SOME (vtoi minor), SOME (vtoi patchN), special)
           end
         | _ => fail ()
    end

    fun fromString s = 
       case fromString' s of
          (major, SOME minor, SOME patch, special) => 
             (major, minor, patch, special)
        | _ => raise Fail ("`" ^ s ^ "` is an incomplete semantic version")

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
    fun max a b = if b > a then b else a

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


    fun intelligentSelect spec vers = 
       let
          val spec = Option.map fromString' spec

          (* Does a version number meet the specification? *)
          val satisfies = 
             case spec of
                NONE => 
                   (fn _ => true)
              | SOME (major, NONE, _, _) => 
                   (fn ver => #1 ver = major)
              | SOME (major, SOME minor, NONE, _) =>
                   (fn ver => #1 ver = major
                              andalso #2 ver = minor)
              | SOME (major, SOME minor, SOME patch, special) => 
                   (fn ver => #1 ver = major
                              andalso #2 ver = minor
                              andalso #3 ver = patch
                              andalso #4 ver = special)

          fun best NONE ver = 
              if satisfies ver then SOME ver else NONE
            | best (SOME oldBest) ver = 
              if satisfies ver 
              then (case (#4 oldBest, #4 ver) of
                       (NONE, NONE) => SOME (max oldBest ver)
                     | (SOME _, SOME _) => SOME (max oldBest ver)
                     | (_, NONE) => SOME ver
                     | (NONE, _) => SOME oldBest)
              else SOME oldBest

          fun process best [] = best
            | process oldBest (ver :: vers) = process (best oldBest ver) vers
       in
          process NONE vers
       end
end
