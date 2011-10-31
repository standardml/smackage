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
	bin/.mkexec-win `which sml` `pwd` smackage

polyml:
	polyml < src/poly_build.sml
	gcc -o $(BIN)/smackage $(BIN)/polyml-smackage.o -lpolymain -lpolyml

clean:
	rm -f $(BIN)/smackage

smackage-install:
	echo "NOTICE: in the future, just use 'install', not 'smackage-install'"
	rm -f ../../../bin/smackage.new
	cp $(BIN)/smackage ../../../bin/smackage.new
	mv ../../../bin/smackage.new ../../../bin/smackage

install:
	rm -f $(DESTDIR)/bin/smackage.new
	cp $(BIN)/smackage $(DESTDIR)/bin/smackage.new
	mv $(DESTDIR)/bin/smackage.new $(DESTDIR)/bin/smackage

.PHONY: clean mlton smlnj polyml
