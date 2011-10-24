BIN=bin

all:
	echo "Run 'make mlton' or 'make smlnj'"
	false

mlton:
	mlton -output $(BIN)/smack smack.mlb

win+mlton:
	mlton -output $(BIN)/smack smack-nonposix.mlb

smlnj:
	sml src/go-nj.sml
	bin/.mkexec `which sml` `pwd` smack

clean:
	rm -f $(BIN)/smack

.PHONY: clean mlton smlnj
