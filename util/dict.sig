
signature DICT =
   sig

      type key
      type 'a dict

      exception Absent

      val empty : 'a dict
      val singleton : key -> 'a -> 'a dict
      val insert : 'a dict -> key -> 'a -> 'a dict
      val remove : 'a dict -> key -> 'a dict
      val find : 'a dict -> key -> 'a option
      val lookup : 'a dict -> key -> 'a
      val union : 'a dict -> 'a dict -> (key * 'a * 'a -> 'a) -> 'a dict

      val operate : 'a dict -> key -> (unit -> 'a) -> ('a -> 'a) -> 'a option * 'a * 'a dict
      val insertMerge : 'a dict -> key -> 'a -> ('a -> 'a) -> 'a dict

      val isEmpty : 'a dict -> bool
      val member : 'a dict -> key -> bool
      val size : 'a dict -> int

      val toList : 'a dict -> (key * 'a) list
      val domain : 'a dict -> key list
      val map : ('a -> 'b) -> 'a dict -> 'b dict
      val foldl : (key * 'a * 'b -> 'b) -> 'b -> 'a dict -> 'b
      val foldr : (key * 'a * 'b -> 'b) -> 'b -> 'a dict -> 'b
      val app : (key * 'a -> unit) -> 'a dict -> unit

   end
