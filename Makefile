PC=ppc386
PCFLAGS=-Scgmi -O3Gp3 -FE. -al -Xs $(PCEXTRAFLAGS)
INSTALLTARGETS=c2ctl
INSTALLDIR=/usr/local/sbin

.PHONY : all clean distclean install arch

all: $(INSTALLTARGETS)

%: %.pas $(UNITSRCS)
	$(PC) $(PCFLAGS) $(UNITS) $<

clean :
	rm -f *.o *.s

distclean : clean
	rm -f $(INSTALLTARGETS);

install : $(INSTALLTARGETS)
	install -s $(INSTALLTARGETS) $(INSTALLDIR)

arch : $(INSTALLTARGETS) clean
	tar -cC .. c2ctl | bzip2 -9 > ../c2ctl.tar.bz2
