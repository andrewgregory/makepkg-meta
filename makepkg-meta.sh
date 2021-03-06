#!/usr/bin/bash

PKGNAME=''
PKGDESC=''
PKGVER=0
UPDATE=1
DUMPPKGBUILD=0
DUMPPKGINFO=0
DEPENDS=()
ADDDEPENDS=()
RMDEPENDS=()
PKGGROUPS=('meta')
ADDGROUPS=()
RMGROUPS=()

error() {
    printf "$@" >&2
    exit 1
}

usage () {
    cat <<USAGE
Usage:
     makepkg-meta <PKGNAME> [options]
     makepkg-meta (--help|--version)

Options:
    -a, --add-depends=<dependencies>
        Comma-separated list of package dependencies. Dependencies are added
        to the depends list AFTER checking for existing dependencies. May
        be specified multiple times.

    -r, --rm-depends=<dependencies>
        Comma-separates list of dependencies to be removed from the depends
        list AFTER loading existing dependencies. May be specified
        multiple times.

    --depends=<dependencies>
        Comma-separated list of package dependencies. May be specified
        multiple times.  Overrides dependencies loaded from an existing
        package.

    --description=<pkgdesc>
        Specify the package description.  Overrides the description loaded from
        an existing package.

    --add-groups=<groups>
        Comma-separated list of package groups. Groups are added to the
        group list <after> loading existing groups. May be specified
        multiple times.

    --rm-groups=<groups>
        Comma-separates list of groups to be removed from the group list
        <after> loading existing groups. May be specified multiple times.

    --groups=<groups>
        Comma-separated list of package groups. May be specified multiple
        times. Packages are automatically in the "meta" group.  Overrides
        groups loaded from an existing package.

    --no-update
        Do not search for an existing package to load information.

    --pkgbuild
        Write the PKGBUILD to stdout without installing it.

    --pkginfo
        Write PKGINFO data to stdout without installing it.

    --help
        Display brief help information.

    --version
        Display version information.
USAGE
}


version() {
    echo "makepkg-meta 2.0"
}

dump_pkgbuild() {
    cat <<PKGBUILD
# Generated by makepkg-meta
pkgname=$PKGNAME
pkgdesc='$PKGDESC'
pkgver=$PKGVER
pkgrel=1
arch=('any')
depends=(${DEPENDS[@]})
groups=(${PKGGROUPS[@]})
PKGBUILD
}

dump_pkginfo() {
    echo "# Generated by makepkg-meta"
    echo "pkgname = $PKGNAME"
    [[ $PKGDESC ]] && echo "pkgdesc = $PKGDESC"
    echo "pkgver = $PKGVER-1"
    echo "arch = any"
    [[ $DEPENDS ]]   && printf "depend = %s\n" "${DEPENDS[@]}"
    [[ $PKGGROUPS ]] && printf "group = %s\n" "${PKGGROUPS[@]}"
}

load_pkg_data() {
    pacman -Q "$PKGNAME" &> /dev/null || return
    [[ $PKGVER != 0 ]] || PKGVER=`LC_ALL=C pacman -Qi "$PKGNAME" \
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
             --options 'a:,r:' \
             --long 'help,version,no-update,description:' \
             --long 'pkgbuild,pkginfo' \
             --long 'depends:,add-depends:,rm-depends:' \
             --long 'groups:,add-groups:,rm-groups:' \
             -- "$@"`
[[ $? != 0 ]] && exit 1
eval set -- "$OPTS"
while true; do
    case "$1" in
        --description)     shift; PKGDESC=$1 ;;
        --depends)         shift; IFS=, read -ra d <<<"$1"; DEPENDS+=("${d[@]}"); unset d ;;
        -a|--add-depends)  shift; IFS=, read -ra d <<<"$1"; ADDDEPENDS+=("${d[@]}"); unset d ;;
        -r|--rm-depends)   shift; IFS=, read -ra d <<<"$1"; RMDEPENDS+=("${d[@]}"); unset d ;;
        --groups)          shift; IFS=, read -ra d <<<"$1"; PKGGROUPS+=("${d[@]}"); unset d ;;
        --add-groups)      shift; IFS=, read -ra d <<<"$1"; ADDGROUPS+=("${d[@]}"); unset d ;;
        --rm-groups)       shift; IFS=, read -ra d <<<"$1"; RMGROUPS+=("${d[@]}"); unset d ;;
        --no-update)       UPDATE=0 ;;
        --pkgbuild)        DUMPPKGBUILD=1 ;;
        --pkginfo)         DUMPPKGINFO=1 ;;
        --help)            usage; exit 0 ;;
        --version)         version; exit 0 ;;
        --)                shift; break ;;
    esac
    shift
done

PKGNAME="$1"
[[ -z $PKGNAME ]] && error "pkgname may not be empty\n"
[[ $UPDATE == 1 ]] && load_pkg_data

(( PKGVER++ ))

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

DEPENDS+=("${ADDDEPENDS[@]}")
PKGGROUPS+=("${ADDGROUPS[@]}")

if [[ $DUMPPKGBUILD == 1 ]]; then
    dump_pkgbuild
    exit 0
fi

if [[ $DUMPPKGINFO == 1 ]]; then
    dump_pkginfo
    exit 0
fi

TMPDIR="/tmp/makepkg-meta.$$"
PKGINFO="$TMPDIR/.PKGINFO"
PKGFILE="$TMPDIR/pkg"

mkdir "$TMPDIR"
dump_pkginfo > "$PKGINFO"

bsdtar -c -C "$TMPDIR" -f "$PKGFILE" .PKGINFO
sudo pacman -U "$PKGFILE"

rm "$PKGFILE" "$PKGINFO"
rmdir "$TMPDIR"
