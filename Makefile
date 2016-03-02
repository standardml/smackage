BIN=bin
TARGET=$(BIN)/smackage

MLTON=mlton

SMLNJ=sml

POLYML=polyml
POLYML_LDFLAGS= -lpolymain -lpolyml

MLKIT=mlkit

SMLSHARP=smlsharp
SMLSHARP_MODULES_=$(wildcard src/*.smi)  $(wildcard util/*.smi)
SMLSHARP_MODULES=$(SMLSHARP_MODULES_:.smi=.sml)
SMLSHARP_CFLAGS=-O2
SMLSHARP_LDFLAGS=
smlsharp_sources:=$(SMLSHARP_MODULES)
smlsharp_objects:=$(smlsharp_sources:.sml=.o)

all:
	@echo "== Smackage Installation =="
	@echo "Run 'make mlton', 'make smlnj', 'make polyml', 'make mlkit' or 'make smlsharp' on Linux/Unix/OSX."
	@echo "Run 'make win+smlnj' or 'make win+mlton' on Windows."
	@echo "In Smackage, then run 'make install' to install."
	false

mlton:
	$(MLTON) -output $(TARGET) smack.mlb

win+mlton:
	$(MLTON) -output $(TARGET) smack-nonposix.mlb

smlnj:
	$(SMLNJ) src/go-nj.sml
	bin/.mkexec `which sml` `pwd` smackage

win+smlnj:
	$(SMLNJ) src/go-nj-nonposix.sml
	bin/.mkexec-win `which sml` `pwd` smackage

polyml:
	$(POLYML) < src/poly_build.sml
	$(CC) -o $(BIN)/smackage $(BIN)/polyml-smackage.o $(POLYML_LDFLAGS)

mlkit:
	$(MLKIT) -o $(BIN)/smackage smack.mlb

smlsharp: $(smlsharp_objects)
	$(SMLSHARP) $(SMLSHARP_LDFLAGS) $(SMLSHARP_FLAGS) -o $(TARGET) src/go.smi

%.o: %.sml
	$(SMLSHARP) $(SMLSHARP_CFLAGS) $(SMLSHARP_FLAGS) -c -o $@ $<

clean:
	rm -f $(BIN)/smackage
	rm -f $(smlsharp_objects)

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
	mkdir -p $(DESTDIR)/bin
	rm -f $(DESTDIR)/bin/smackage.new
	cp $(BIN)/smackage $(DESTDIR)/bin/smackage.new
	mv $(DESTDIR)/bin/smackage.new $(DESTDIR)/bin/smackage

.PHONY: clean mlton smlnj polyml mlkit smlsharp
