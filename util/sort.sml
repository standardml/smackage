
signature SORT =
sig
   val sort: ('a * 'a -> order) -> 'a list -> 'a list
end

(* Not totally stupid. We're mostly re-sorting mostly sorted lists, and this
 * implementation should be O(n) in that case. *)
structure InsertionSort:> SORT =
struct 
   fun sort compare =
   let 
      (* Insert takes a reverse-sorted list and inserts x into it. *)
      fun insert x [] = [ x ]
        | insert x (y :: ys) = 
            (case compare (x, y) of
                LESS => y :: insert x ys
              | _ => x :: y :: ys)
      
      fun loop sorted [] = rev sorted
        | loop sorted (x :: unsorted) = loop (insert x sorted) unsorted
   in
      loop [] 
   end
end
