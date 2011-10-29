
functor ListDict (structure Key : sig type t val compare: t * t -> order end)
   :> DICT where type key = Key.t
   =
   struct

      type key = Key.t
      type 'a dict = (key * 'a) list

      exception Absent

      val empty = []

      val isEmpty = null

      fun singleton key x = [(key, x)]

      fun insert l key x =
         (case l of
             [] => [(key, x)]
           | (key', y) :: rest =>
                (case Key.compare (key, key') of
                    LESS =>
                       (key, x) :: l
                  | EQUAL =>
                       (key, x) :: rest
                  | GREATER =>
                       (key', y) :: insert rest key x))

      fun remove l key =
         (case l of
             [] => []
           | (key', y) :: rest =>
                (case Key.compare (key, key') of
                    LESS => l
                  | EQUAL => rest
                  | GREATER =>
                       (key', y) :: remove rest key))

      fun operate l key absentf presentf =
         (case l of
             [] =>
                let
                   val x = absentf ()
                in
                   (NONE, x, [(key, x)])
                end
           | (key', y) :: rest =>
                (case Key.compare (key, key') of
                    LESS =>
                       let
                          val x = absentf ()
                       in
                          (NONE, x, (key, x) :: l)
                       end
                  | EQUAL =>
                       let
                          val x = presentf y
                       in
                          (SOME y, x, (key, x) :: rest)
                       end
                  | GREATER =>
                       let
                          val (ante, post, rest') = operate rest key absentf presentf
                       in
                          (ante, post, (key', y) :: rest')
                       end))

      fun insertMerge dict key x f =
         #3 (operate dict key (fn () => x) f)

      fun find l key =
         (case l of
             [] => 
                NONE
           | (key', x) :: rest =>
                (case Key.compare (key, key') of
                    LESS =>
                       NONE
                  | EQUAL =>
                       SOME x
                  | GREATER =>
                       find rest key))

      fun lookup l key =
         (case l of
             [] => 
                raise Absent
           | (key', x) :: rest =>
                (case Key.compare (key, key') of
                    LESS =>
                       raise Absent
                  | EQUAL =>
                       x
                  | GREATER =>
                       lookup rest key))

      fun member l key =
         (case l of
             [] =>
                false
           | (key', _) :: rest =>
                (case Key.compare (key, key') of
                    LESS =>
                       false
                  | EQUAL =>
                       true
                  | GREATER =>
                       member rest key))

      val size = length

      fun union l1 l2 f =
         (case (l1, l2) of
             ([], _) =>
                l2
           | (_, []) => 
                l1
           | ((entry1 as (key1, x1)) :: rest1, (entry2 as (key2, x2)) :: rest2) =>
                (case Key.compare (key1, key2) of
                    LESS =>
                       entry1 :: union rest1 l2 f
                  | GREATER =>
                       entry2 :: union l1 rest2 f
                  | EQUAL =>
                       (key1, f (key1, x1, x2)) :: union rest1 rest2 f))

      fun toList l = l

      fun domain l = List.map (fn (key, _) => key) l

      fun map f l = List.map (fn (key, x) => (key, f x)) l

      fun foldl f base l = List.foldl (fn ((key, x), y) => f (key, x, y)) base l

      fun foldr f base l = List.foldr (fn ((key, x), y) => f (key, x, y)) base l

      val app = List.app

   end
