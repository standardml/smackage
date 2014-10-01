BIN=bin

all:
	@echo "== Smackage Installation =="
	@echo "Run 'make mlton', 'make smlnj', 'make polyml', or 'make mlkit' on Linux/Unix/OSX."
	@echo "Run 'make win+smlnj' or 'make win+mlton' on Windows."
	@echo "In Smackage, then run 'make install' to install."
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

mlkit:
	mlkit -o $(BIN)/smackage smack.mlb

clean:
	rm -f $(BIN)/smackage

smackage-install:
	@echo "NOTICE: This is probably not the command you meant to run."
	@echo "If you are invoking this makefile through smackage by"
	@echo "running `smackage make smackage smackage-install', then in the"
	@echo "future you should run `smackage make smackage install' instead."
	@echo ""
	@echo "This version still works if you want to run `make' directly"
	@echo "instead of invoking it indirectly (`smackage make smackage')."
	@echo "However, the latter option is suggested."
	rm -f ../../../bin/smackage.new
	cp $(BIN)/smackage ../../../bin/smackage.new
	mv ../../../bin/smackage.new ../../../bin/smackage

install:
	rm -f $(DESTDIR)/bin/smackage.new
	cp $(BIN)/smackage $(DESTDIR)/bin/smackage.new
	mv $(DESTDIR)/bin/smackage.new $(DESTDIR)/bin/smackage

.PHONY: clean mlton smlnj polyml mlkit
