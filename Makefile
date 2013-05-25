PREFIX    ?= /usr/local
DESTDIR   ?=
MANPREFIX ?= ${PREFIX}/share/man

RELEASE = `bash makepkg-meta.sh --version`

all: makepkg-meta.sh doc
	install -m755 makepkg-meta.sh makepkg-meta

doc: README.pod
	pod2man README.pod makepkg-meta.1 --center='makepkg-meta' \
		--name='MAKEPKG-META' --release="${RELEASE}"

install: all
	install -D -m755 makepkg-meta    ${DESTDIR}${PREFIX}/bin/makepkg-meta
	install -D -m644 makepkg-meta.1  ${DESTDIR}${MANPREFIX}/man1/makepkg-meta.1
