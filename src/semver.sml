signature SEMVER =
sig
    eqtype semver     (* v0.2.4beta, v1.2.3, etc... *)
    type t = semver
    type constraint (* v1, v1.2, v2.3.6, v3.1.6, etc... *)

    exception InvalidVersion

    val constrFromString : string -> constraint
    val constrToString : constraint -> string
    val compareConstr : constraint * constraint -> order

    val fromString : string -> semver
    val major : semver -> constraint
    val minor : semver -> constraint
    val exact : semver -> constraint
    val toString : semver -> string
    val eq : semver * semver -> bool
    val compare : semver * semver -> order
    val satisfies : constraint -> semver -> bool
    val < : semver * semver -> bool
    val <= : semver * semver -> bool
    val >= : semver * semver -> bool
    val > : semver * semver -> bool
    val allPaths : semver -> string list

    (* intelligentSelect is a way of resolving a partially-specified semantic
     * version which makes sense to Rob at the time.
     *
     * It will prefer tags with special versions over tags with 
     * no versions (so `intelligentSelect NONE [ v2.0.0beta, v1.9.3 ]' will 
     * return `SOME (v1.9.3, "1")') but will prefer nothing to something (so 
     * `intelligentSelect (SOME v2) [ 2.0.0beta, 1.9.3 ]' will return 
     * `SOME (2.0.0beta, 2)')
     *
     * The returned constraint is equal to the given constraint if an initial
     * constraint was given, and is the major version of the returned semvar
     * if no initial constraint was given. *)
    val intelligentSelect :
       constraint option -> semver list -> (constraint * semver) option
end

structure SemVer:> SEMVER =
struct
    type semver = int * int * int * string option
    type t = semver
    type constraint = int * int option * int option * string option

    exception InvalidVersion

    fun compareConstr ((maj1, min1, pat1, s1), (maj2, min2, pat2, s2)) = 
       case (Int.compare (maj1, maj2), min1, min2) of
          (LESS, _, _) => LESS
        | (GREATER, _, _) => GREATER
        | (EQUAL, NONE, NONE) => EQUAL
        | (EQUAL, NONE, SOME _) => LESS
        | (EQUAL, SOME _, NONE) => GREATER
        | (EQUAL, SOME min1, SOME min2) => 
            (case (Int.compare (min1, min2), pat1, pat2) of
                (LESS, _, _) => LESS
              | (GREATER, _, _) => GREATER
              | (EQUAL, NONE, NONE) => EQUAL
              | (EQUAL, NONE, SOME _) => LESS
              | (EQUAL, SOME _, NONE) => GREATER
              | (EQUAL, SOME pat1, SOME pat2) => 
                  (case (Int.compare (pat1, pat2), s1, s2) of
                      (LESS, _, _) => LESS
                    | (GREATER, _, _) => GREATER
                    | (EQUAL, NONE, NONE) => EQUAL
                    | (EQUAL, NONE, SOME _) => GREATER
                    | (EQUAL, SOME _, NONE) => LESS
                    | (EQUAL, SOME s1, SOME s2) => String.compare (s1, s2)))


    fun eq (x: semver, y) = x = y

    fun major (major, _, _, _) = (major, NONE, NONE, NONE)
    fun minor (major, minor, _, _) = (major, SOME minor, NONE, NONE)
    fun exact (major, minor, patch, special) =
       (major, SOME minor, SOME patch, special)

    fun fromString' s =
    let
        fun fail () = raise Fail ("`" ^ s ^ "` not a valid semantic version")

        val s' = 
           case String.tokens Char.isSpace s of 
              [ s ] => 
                 if String.sub (s,0) = #"v" 
                 then String.extract (s, 1, NONE)
                 else s
            | _ => fail ()
            
        val f = String.fields (fn #"." => true | _ => false) s'

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

    fun constrFromString s = fromString' s

    fun fromString s = 
       case fromString' s of
          (major, SOME minor, SOME patch, special) => 
             (major, minor, patch, special)
        | _ => raise Fail ("`" ^ s ^ "` is an incomplete semantic version")

    val ts = Int.toString

    fun toString (ma,mi,pa,s) = 
        ts ma ^ "." ^ ts mi ^ "." ^ ts pa ^
        (if s = NONE then "" else valOf s)

    fun constrToString (major, NONE, _, _) = ts major
      | constrToString (major, SOME minor, NONE, _) = ts major ^ "." ^ ts minor
      | constrToString (major, SOME minor, SOME patch, NONE) =
           ts major ^ "." ^ ts minor ^ "." ^ ts patch
      | constrToString (major, SOME minor, SOME patch, SOME special) =
           ts major ^ "." ^ ts minor ^ "." ^ ts patch ^ special

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

   (* Does a version number meet the specification? *)
   fun satisfies spec (ver: semver) =
      case spec of
         (major, NONE, _, _) =>
            (#1 ver = major)
       | (major, SOME minor, NONE, _) =>
            (#1 ver = major andalso #2 ver = minor)
       | (major, SOME minor, SOME patch, NONE) => 
            (#1 ver = major andalso #2 ver = minor andalso #3 ver = patch)
       | (major, SOME minor, SOME patch, SOME special) => 
            (#1 ver = major
             andalso #2 ver = minor
             andalso #3 ver = patch
             andalso isSome (#4 ver) 
             andalso String.isPrefix special (valOf (#4 ver)))

    (** Enumerate the various paths that this version could give rise to.
        e.g., for version 1.6.2beta1, we could potentially have these paths:
        v1, v1.6, v1.6.2beta1 *)
    fun allPaths (v as (ma,mi,pa,ps)) =
        ["v" ^ Int.toString ma,
         "v" ^ Int.toString ma ^ "." ^ Int.toString mi,
         "v" ^ toString v]


    fun intelligentSelect spec vers = 
       let
          val satisfies =
             case spec of 
                NONE => (fn _ => true)
              | SOME spec => satisfies spec

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
          case (process NONE vers, spec) of 
             (NONE, _) => NONE
           | (SOME ver, NONE) => SOME (major ver, ver)
           | (SOME ver, SOME spec) => SOME (spec, ver)
       end
end
