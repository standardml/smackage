(* Taken from http://www.tbrk.org/software/poly_smlnj-lib.html for use in
   smackage *)
structure Word31 = Word;
structure Int32 = Int;
structure Unsafe = struct
          structure CharVector = CharVector
          structure Array = Array
	  structure Vector = Vector
      end;
local
val root = "/usr/local/lib/mlton/sml"

val util = [
"ord-key-sig.sml",
"ord-set-sig.sml",
"lib-base-sig.sml",
"lib-base.sml",
"list-set-fn.sml",
"ord-map-sig.sml",
"list-map-fn.sml",
"int-binary-set.sml",
"int-binary-map.sml",
"prime-sizes.sml",
"dynamic-array-sig.sml",
"dynamic-array.sml",
"io-util-sig.sml",
"splaytree-sig.sml",
"splaytree.sml",
"splay-set-fn.sml",
"splay-map-fn.sml",
"ansi-term.sml",
"io-util.sml",
"plist-sig.sml",
"getopt-sig.sml",
"getopt.sml",
"interval-domain-sig.sml",
"interval-set-sig.sml",
"parser-comb-sig.sml",
"atom-sig.sml",
"hash-string.sml",
"atom.sml",
"format-sig.sml",
"real-format.sml",
"fmt-fields.sml",
"format.sml",
"priority-sig.sml",
"hash-key-sig.sml",
"mono-hash-table-sig.sml",
"hash-table-rep.sml",
"int-hash-table.sml",
"bit-array-sig.sml",
"redblack-set-fn.sml",
"atom-redblack-set.sml",
"atom-set.sml",
"redblack-map-fn.sml",
"atom-redblack-map.sml",
"atom-map.sml",
"plist.sml",
"char-map-sig.sml",
"char-map.sml",
"list-xprod-sig.sml",
"graph-scc-sig.sml",
"graph-scc-fn.sml",
"hash-table-fn.sml",
"atom-table.sml",
"list-format-sig.sml",
"list-format.sml",
"bit-vector-sig.sml",
"parser-comb.sml",
"mono-hash2-table-sig.sml",
"interval-set-fn.sml",
"word-redblack-set.sml",
"word-redblack-map.sml",
"int-list-set.sml",
"int-list-map.sml",
"path-util-sig.sml",
"path-util.sml",
"binary-set-fn.sml",
"binary-map-fn.sml",
"random-sig.sml",
"random.sml",
"real-order-stats.sml",
"univariate-stats.sml",
"bit-array.sml",
"mono-array-fn.sml",
"bsearch-fn.sml",
"mono-dynamic-array-sig.sml",
"format-comb-sig.sml",
"format-comb.sml",
"queue-sig.sml",
"fifo-sig.sml",
"fifo.sml",
"queue.sml",
"hash2-table-fn.sml",
"word-hash-table.sml",
"keyword-fn.sml",
"mono-priorityq-sig.sml",
"left-priorityq-fn.sml",
"hash-table-sig.sml",
"hash-table.sml",
"dynamic-array-fn.sml",
"mono-array-sort-sig.sml",
"int-redblack-set.sml",
"int-redblack-map.sml",
"array-sort-sig.sml",
"array-qsort.sml",
"uref-sig.sml",
"simple-uref.sml",
"listsort-sig.sml",
"list-mergesort.sml",
"array-qsort-fn.sml",
"atom-binary-set.sml",
"atom-binary-map.sml",
"utf8-sig.sml",
"utf8.sml",
"uref.sml",
"scan-sig.sml",
"scan.sml",
"rand-sig.sml",
"rand.sml",
"list-xprod.sml",
""]

val controls = [
"controls-sig.sml",
"control-reps.sml",
"controls.sml",
"control-set-sig.sml",
"control-set.sml",
"registry-sig.sml",
"control-util-sig.sml",
"control-util.sml",
"registry.sml",
""]

val hashcons = [
"hash-cons-sig.sml",
"hash-cons.sml",
"hash-cons-set-sig.sml",
"hash-cons-map-sig.sml",
"hash-cons-set.sml",
"hash-cons-map.sml",
"hash-cons-ground-fn.sml",
"hash-cons-string.sml",
"hash-cons-atom.sml",
""]

val html = [
"html-sig.sml",
"html.sml",
"make-html.sml",
"html-defaults.sml",
"html-error-sig.sml",
"check-html-fn.sml",
"html-attr-vals.sml",
"html-attrs-sig.sml",
"html-gram.sig",
"html-elements-fn.sml",
"html-lex.sml",
"html-gram.sml",
"html-attrs-fn.sml",
"html-parser-fn.sml",
"pr-html.sml",
""]

val inet = [
"sock-util-sig.sml",
"sock-util.sml",
"unix-sock-util.sml",
""]

val pp = [
"src/pp-stream-sig.sml",
"src/pp-debug-fn.sml",
"src/pp-device-sig.sml",
"devices/simple-textio-dev.sml",
"src/pp-token-sig.sml",
"src/pp-stream-fn.sml",
"src/pp-desc-sig.sml",
"src/pp-desc-fn.sml",
"devices/string-token.sml",
"devices/textio-pp.sml",
"devices/ansi-term-dev.sml",
"devices/html-dev.sml",
"devices/ansi-term-pp.sml",
""]

val reactive = [
"reactive-sig.sml",
"instruction.sml",
"machine.sml",
"reactive.sml",
""]

val regexp = [
"Glue/match-tree.sml",
"FrontEnd/syntax-sig.sml",
"FrontEnd/syntax.sml",
"BackEnd/engine-sig.sml",
"BackEnd/fsm.sml",
"BackEnd/dfa-engine.sml",
"Glue/regexp-sig.sml",
"FrontEnd/parser-sig.sml",
"Glue/regexp-fn.sml",
"FrontEnd/awk-syntax.sml",
"BackEnd/bt-engine.sml",
""]

val unix = [
"unix-env-sig.sml",
"unix-env.sml",
""]

fun dol ("",_) =()
  | dol (dn,l) =List.app(fn "" => ()
                                | s => use(root^"/smlnj-lib/"^dn^"/"^s)) l
in
val _ = List.app dol [
("Util", util),
("Controls", controls),
("HashCons", hashcons),
("HTML", html),
("INet", inet),
("PP", pp),
("Reactive", reactive),
("RegExp", regexp),
("Unix", unix),
("", [])]
end;
