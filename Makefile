TEMPDIR := $(shell mktemp -d)
TOOLSDIR := /usr/local/bin
AS := $(TOOLSDIR)/ca65
LD := $(TOOLSDIR)/ld65
ASFLAGS := -g 
SRCDIR := src
CONFIGNAME := ldscripts/nes.ld
OBJNAME := main.o
MAPNAME := map.txt
LABELSNAME := labels.txt
LISTNAME := listing.txt
LDFLAGS := -Ln $(LABELSNAME)

TOPLEVEL := main.asm

EXECUTABLE := main.nes

.PHONY: all build $(EXECUTABLE)

build: $(EXECUTABLE)

all: $(EXECUTABLE)

clean:
	rm -f main.nes main.o $(LISTNAME) $(LABELSNAME) $(MAPNAME)

$(EXECUTABLE):
	$(AS) $(SRCDIR)/$(TOPLEVEL) $(ASFLAGS) -v -I $(SRCDIR) -l $(LISTNAME) -o $(OBJNAME) --feature force_range
	$(LD) $(LDFLAGS) -C $(CONFIGNAME) -o $(EXECUTABLE) -m $(MAPNAME) -vm $(OBJNAME)

run: $(EXECUTABLE)
	java -jar tools/nintaco/Nintaco.jar ./$(EXECUTABLE)
	# wine tools/fceux/fceux.exe \$(EXECUTABLE)

.PHONY: edit-tiles
edit-tiles:
	wine tools/nesst/NESst.exe ./$(EXECUTABLE)
	# wine tools/yy-chr20120407_en/yychr.exe

	
debug: $(EXECUTABLE)
	wine tools/fceuxw/fceux.exe ./$(EXECUTABLE)


tools:
	mkdir tools

# FCEUX
tools/fceux: tools
	- mkdir tools/fceux

tools/fceux/fceux.exe: tools/fceux
	curl http://sourceforge.net/projects/fceultra/files/Binaries/2.2.3/fceux-2.2.3-win32.zip/download -L -o $(TEMPDIR)/fceux.zip
	cd $< && unzip $(TEMPDIR)/fceux.zip

# nintaco
tools/nintaco: tools
	- mkdir tools/nintaco

tools/nintaco/Nintaco.jar: tools/nintaco
	curl https://nintaco.com/Nintaco_bin_2019-02-10.zip -L -o $(TEMPDIR)/nintaco.zip
	open $(TEMPDIR)
	cd $< && unzip $(TEMPDIR)/nintaco.zip

# NESST
tools/nesst: tools
	- mkdir tools/nesst

tools/nesst/nesst.exe: tools/nesst
	curl https://shiru.untergrund.net/files/nesst.zip -L -o $(TEMPDIR)/nesst.zip
	open $(TEMPDIR)
	cd $< && unzip $(TEMPDIR)/nesst.zip
	open tools


.PHONY: bootstrap
bootstrap: tools/fceux/fceux.exe tools/nesst/nesst.exe

.PHONY: clean-tools
clean-tools:
	rm -rf tools
