type pos = int
type svalue = Tokens.svalue
type ('a,'b) token = ('a,'b) Tokens.token
type lexresult = (svalue,pos) token

fun eof() = Tokens.EOF(0,0)

val tliteral = ref ""
val tlstart = ref 0

val lineNum = ErrorMsg.lineNum
val linePos = ErrorMsg.linePos 

fun err(p1,p2) = ErrorMsg.error p1

%%
%header (functor LopeLexFun(structure Tokens : Lope_TOKENS));

%s LOPE LINECOMMENT COMMENT STRINGLIT;

digits=[0-9]+;
real=([0-9]+"."[0-9]*)|([0-9]*"."[0-9]+);
ident=[a-zA-Z_][a-zA-Z0-9_'\.]*;
siteident=\$[a-zA-Z_][a-zA-Z0-9_'\.]*;
stringlit="\""([^\"]*)"\"";
ws=[\ \t];
eol=[\n\r];
%%
<INITIAL>{ws}*		=> (YYBEGIN LOPE; continue());

<LOPE>"{"		=> (Debug.debug 5 "LBR\n"; Tokens.LBR(yypos,yypos+1));
<LOPE>"}"		=> (Debug.debug 5 "RBR\n"; Tokens.RBR(yypos,yypos+1));
<LOPE>"("		=> (Debug.debug 5 "LPAR\n"; Tokens.LPAR(yypos,yypos+1));
<LOPE>")"		=> (Debug.debug 5 "RPAR\n"; Tokens.RPAR(yypos,yypos+1));
<LOPE>":"		=> (Debug.debug 5 "COLON\n"; Tokens.COLON(yypos,yypos+1));
<LOPE>";"		=> (Debug.debug 5 "SEMI\n"; Tokens.SEMI(yypos,yypos+1));
<LOPE>","		=> (Debug.debug 5 "COMMA\n"; Tokens.COMMA(yypos,yypos+1));
<LOPE>"_"		=> (Debug.debug 5 "WILDCARD\n"; Tokens.WILDCARD(yypos,yypos+1));
<LOPE>"(*"		=> (YYBEGIN COMMENT; continue());
<LOPE>"*"		=> (Debug.debug 5 "STAR\n"; Tokens.STAR(yypos,yypos+1));
<LOPE>"+"		=> (Debug.debug 5 "PLUS\n"; Tokens.PLUS(yypos,yypos+1));
<LOPE>"-"		=> (Debug.debug 5 "MINUS\n"; Tokens.MINUS(yypos,yypos+1));
<LOPE>"/"		=> (Debug.debug 5 "DIV\n"; Tokens.DIV(yypos,yypos+1));
<LOPE>"^"		=> (Debug.debug 5 "CONCAT\n"; Tokens.CONCAT(yypos,yypos+1));
<LOPE>"reaction" => (Tokens.REACTION(yypos, yypos+8));
<LOPE>"redex" => (Tokens.REDEX(yypos, yypos+5));
<LOPE>"reactum" => (Tokens.REACTUM(yypos, yypos+7));
<LOPE>"link" => (Tokens.LINK(yypos, yypos+4));
<LOPE>"type" => (Tokens.TYPE(yypos, yypos+4));
<LOPE>"val" => (Tokens.VAL(yypos, yypos+3));
<LOPE>"<->" => (Tokens.ILINK(yypos, yypos+3));
<LOPE>"<" => (Tokens.LT(yypos, yypos+1));
<LOPE>">" => (Tokens.GT(yypos, yypos+1));
<LOPE>"=" => (Tokens.EQ(yypos, yypos+1));
<LOPE>{digits} => (Tokens.INT (valOf (Int.fromString yytext), yypos,yypos + size yytext));
<LOPE>"\""		=> (YYBEGIN STRINGLIT; tlstart := yypos; tliteral := ""; continue());
<LOPE>{digits} => (Tokens.INT (valOf (Int.fromString yytext), yypos,yypos + size yytext));
<LOPE>{ident}	=> (Debug.debug 5 "IDENT\n"; Tokens.IDENT(yytext,yypos,yypos+size yytext));
<LOPE>{siteident} => (Debug.debug 5 "SITEIDENT\n"; Tokens.SITEIDENT(yytext,yypos,yypos+size yytext));

<COMMENT>"*)"		=> (YYBEGIN LOPE; continue());
<COMMENT>{eol}		=> (lineNum := !lineNum+1; linePos := yypos :: !linePos; continue());
<COMMENT>.		=> (Debug.debug 5 "COMMENT\n"; continue());

<STRINGLIT>"\"" => (YYBEGIN LOPE; Tokens.STRING(!tliteral,!tlstart,!tlstart + size (!tliteral)));
<STRINGLIT>{eol} => (Tokens.ERROR(!tlstart,yypos));
<STRINGLIT>. => (tliteral := !tliteral ^ yytext; continue());

<LOPE>{eol}		=> (Debug.debug 5 "EOL\n"; lineNum := !lineNum+1; linePos := yypos :: !linePos; continue());
<LOPE>{ws}*		=> (Debug.debug 5 "WS\n"; continue());
<LOPE>.			=> (Debug.debug 5 "ERROR\n"; Tokens.ERROR(yypos,yypos+size yytext));

