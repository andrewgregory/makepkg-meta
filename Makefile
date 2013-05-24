PREFIX    ?= /usr/local
DESTDIR   ?=
MANPREFIX ?= ${PREFIX}/share/man

all: makepkg-meta.sh doc

doc: README.pod
	pod2man README.pod > makepkg-meta.1

install: all
	install -D -m755 makepkg-meta.sh ${DESTDIR}${PREFIX}/bin/makepkg-meta
	install -D -m644 makepkg-meta.1  ${DESTDIR}${MANPREFIX}/man1/makepkg-meta.1
