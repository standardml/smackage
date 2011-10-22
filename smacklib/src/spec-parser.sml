signature PARSE =
sig
	type lope_control
	type 'a bigraph

	val parse : string -> lope_control bigraph
	val parse_string : string -> lope_control bigraph
end

structure Parse : PARSE =
struct 
  structure LopeLrVals = LopeLrValsFun(structure Token = LrParser.Token)
  structure Lex = LopeLexFun(structure Tokens = LopeLrVals.Tokens)
  structure LopeP = Join(structure ParserData = LopeLrVals.ParserData
			structure Lex=Lex
			structure LrParser = LrParser)

  type lope_control = Bigraph.lope_control
  type 'a bigraph = 'a Bigraph.bigraph

  fun parseerror(s,p1,p2) = ErrorMsg.error p1 s 

  fun parse_string inp = let
	  val _ = (ErrorMsg.reset(); ErrorMsg.fileName := "__internal__")
	  val file = TextIO.openString inp
	  fun get _ = TextIO.input file
	  val _ = Debug.debug 3 ("parse_string: " ^ inp ^ "\n")
	  val lexer = LrParser.Stream.streamify (Lex.makeLexer get)
	  val (bg,_) = LopeP.parse(30,lexer,parseerror,())
	  val _ = Debug.debug 3 ("parsed_string: " ^ inp ^ "\n")
       in 
	  		ParseTree.to_bigraph Bigraph.Empty bg
      end  

  fun parse filename = let
	  val _ = (ErrorMsg.reset(); ErrorMsg.fileName := filename)
	  val file = TextIO.openIn filename
	  fun get _ = TextIO.input file
	  val lexer = LrParser.Stream.streamify (Lex.makeLexer get)
	  val (bg,_) = LopeP.parse(30,lexer,parseerror,())
       in TextIO.closeIn file;
	    	ParseTree.to_bigraph Bigraph.Empty bg
      end  
end


