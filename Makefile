BIN=bin

all:
	echo "Run 'make mlton', 'make smlnj' or 'make polyml'"
	false

mlton:
	mlton -output $(BIN)/smackage smack.mlb

win+mlton:
	mlton -output $(BIN)/smackage smack-nonposix.mlb

smlnj:
	sml src/go-nj.sml
	bin/.mkexec `which sml` `pwd` smackage

win+smlnj:
	sml src/go-nj-nonposix.sml
	bin/.mkexec `which sml` `pwd` smackage

polyml:
	polyml < src/poly_build.sml
	gcc -o $(BIN)/smackage $(BIN)/polyml-smackage.o -lpolymain -lpolyml

clean:
	rm -f $(BIN)/smackage

.PHONY: clean mlton smlnj polyml
