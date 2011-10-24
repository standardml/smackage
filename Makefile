BIN=bin

all:
	echo "Run 'make mlton', 'make smlnj' or 'make polyml'"
	false

mlton:
	mlton -output $(BIN)/smack smack.mlb

win+mlton:
	mlton -output $(BIN)/smack smack-nonposix.mlb

smlnj:
	sml smack.cm # FIXME: This is wrong, I know.

polyml:
	polyml < src/poly_build.sml
	gcc -o smack smack-poly.o -lpolymain -lpolyml

clean:
	rm -f $(BIN)/smack

.PHONY: clean mlton smlnj polyml
