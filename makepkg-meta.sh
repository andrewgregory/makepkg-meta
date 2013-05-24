#!/usr/bin/bash

PKGNAME=''
PKGDESC=''
PKGVER=0
UPDATE=0
DUMP=0
DEPENDS=()
ADDDEPENDS=()
RMDEPENDS=()
PKGGROUPS=()
ADDGROUPS=()
RMGROUPS=()

error() {
    printf "$@" >&2
    exit 1
}

usage () {
    cat <<USAGE
Usage:
     makepkg-meta [options]

Options:
    --name=*pkgname*
        Specify the package name.

    --update=*pkgname*
        Equivalent to --name except if a package named *pkgname* is
        currently installed it will be queried for any fields not explicitly
        provided.

    --description=*pkgdesc*
        Specify the package description.

    --depends=*dependency*
        Comma-separated list of package dependencies. May be specified
        multiple times.

    --add-depends=*dependency*
        Comma-separated list of package dependencies. Dependencies are added
        to the depends list *after* checking for existing dependencies. May
        be specified multiple times.

    --rm-depends=*dependency*
        Comma-separates list of dependencies to be removed from the depends
        list *after* loading existing dependencies. May be specified
        multiple times.

    --groups=*group*
        Comma-separated list of package groups. May be specified multiple
        times. Packages are automatically in the "meta" group.

    --add-groups=*group*
        Comma-separated list of package groups. Groups are added to the
        group list *after* loading existing groups. May be specified
        multiple times.

    --rm-groups=*groups*
        Comma-separates list of groups to be removed from the group list
        *after* loading existing groups. May be specified multiple times.

    --dump
        Write the PKGBUILD to stdout without installing it.

    --help
        Display brief help information.

    --version
        Display version information.
USAGE
}


version() {
    echo "makepkg-meta 1.0"
}

dump_pkgbuild() {
    cat <<PKGBUILD
pkgname=$PKGNAME
pkgdesc='$PKGDESC'
pkgver=$PKGVER
pkgrel=1
arch=('any')
license=('none')
depends=(${DEPENDS[@]})
groups=(${PKGGROUPS[@]})
PKGBUILD
}

load_pkg_data() {
    [[ $PKGVER != 0 ]] ||  PKGVER=`LC_ALL=C pacman -Qi "$PKGNAME" \
        | sed -ne 's/^Version\s*: //p' \
        | awk 'BEGIN {FS="-"} {print $1}'`
    [[ -n $PKGDESC ]] || PKGDESC=`LC_ALL=C pacman -Qi "$PKGNAME" \
        | sed -ne 's/^Description\s*: //p'`
    [[ -n $DEPENDS ]] || DEPENDS=(`LC_ALL=C pacman -Qi "$PKGNAME" \
        | awk 'BEGIN {FS=" : "} $1 ~ /^Depends/ {print $2}' \
        | awk 'BEGIN {RS="  "} {print}'`)
    [[ -n $PKGGROUPS ]] || PKGGROUPS=(`LC_ALL=C pacman -Qi "$PKGNAME" \
        | awk 'BEGIN {FS=" : "} $1 ~ /^Groups/ {print $2}' \
        | awk 'BEGIN {RS="  "} {print}'`)
}

OPTS=`getopt --name makepkg-meta \
             --options '' \
             --long 'help,version,name:,update:,description:,dump' \
             --long 'depends:,add-depends:,rm-depends:' \
             --long 'groups:,add-groups:,rm-groups:' \
             -- "$@"`
[[ $? != 0 ]] && exit 1
eval set -- "$OPTS"
while true; do
    case "$1" in
        --name)        shift; PKGNAME=$1; UPDATE=0 ;;
        --update)      shift; PKGNAME=$1; UPDATE=1 ;;
        --description) shift; PKGDESC=$1 ;;
        --depends)     shift; IFS=, read -ra d <<<"$1"; DEPENDS+=("${d[@]}"); unset d ;;
        --add-depends) shift; IFS=, read -ra d <<<"$1"; ADDDEPENDS+=("${d[@]}"); unset d ;;
        --rm-depends)  shift; IFS=, read -ra d <<<"$1"; RMDEPENDS+=("${d[@]}"); unset d ;;
        --groups)      shift; IFS=, read -ra d <<<"$1"; PKGGROUPS+=("${d[@]}"); unset d ;;
        --add-groups)  shift; IFS=, read -ra d <<<"$1"; ADDGROUPS+=("${d[@]}"); unset d ;;
        --rm-groups)   shift; IFS=, read -ra d <<<"$1"; RMGROUPS+=("${d[@]}"); unset d ;;
        --dump)        DUMP=1 ;;
        --help)        usage; exit 0 ;;
        --version)     version; exit 0 ;;
        --)            shift; break ;;
    esac
    shift
done

[[ -z $PKGNAME ]] && error "pkgname may not be empty\n"
[[ $UPDATE == 1 ]] && load_pkg_data

(( PKGVER++ ))
DEPENDS+=("${ADDDEPENDS[@]}")
PKGGROUPS+=('meta')
PKGGROUPS+=("${ADDGROUPS[@]}")

for d in "${RMDEPENDS[@]}"; do
    i=0
    while (( i < ${#DEPENDS} )); do
        [[ $d == "${DEPENDS[$i]}" ]] && unset DEPENDS[$i]
        (( i++ ))
    done
done

for g in "${RMGROUPS[@]}"; do
    i=0
    while (( i < ${#PKGGROUPS} )); do
        [[ $g == "${PKGGROUPS[$i]}" ]] && unset PKGGROUPS[$i]
        (( i++ ))
    done
done

if [[ $DUMP == 1 ]]; then
    dump_pkgbuild
    exit 0
fi

TMPDIR="/tmp/makepkg-meta.$$"
mkdir $TMPDIR
dump_pkgbuild > $TMPDIR/PKGBUILD
BUILDDIR="$TMPDIR" makepkg -ic -p "$TMPDIR/PKGBUILD"
rm "$TMPDIR/PKGBUILD"
rmdir "$TMPDIR/$PKGNAME"
rmdir "$TMPDIR"
