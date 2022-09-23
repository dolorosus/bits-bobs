#!/bin/bash
#
#

#
# Just in case COLORS.sh couldn't be found...
#
TICK="[ok]"
CROSS="[X] "
INFO="[i]"
WARN="[w]"
QST="[?]"
IDENT="$   "

msgok() {
    echo -e "${TICK} ${1}"
}
msg() {
    echo -e "${INFO} ${1}"
}
msgwarn() {
    echo -e "${WARN} ${1}"
}
msgfail() {
    echo -e "${CROSS} ${1}" >&2
}

errexit() {
    echo "${myname}: Trying to restart containers"
    execCmd "docker container start ${dbcont}" || exit 40
    execCmd "docker container start ${appcont}" || exit 45
    exit 60
}

execCmd() {

    local cmd="${1:-ERROR}"

    [ "${cmd}" = "ERROR" ] && {
        echo "execCmd called without argument"
        return 1
    }

    #msg "${cmd}"
    ${cmd} || {
        msgfail "${cmd} failed!"
        return 1
    }
    msgok "${cmd}"
    return 0
}
# =================== Main ==================================================

#
#  adapt this to to needs
#
#
# this requieres to expose a suvolume to the nextcloud STACKNAME
# and a path to hold the snapshots
#
# E.g. :
#

#

#
#
#  Pointing to the subvol in your docker-compose script:
#
# ...
#    volumes:
#     - /mnt/USB64/nextcloud/db:/var/lib/mysql
# ...
#    volumes:
#     - /mnt/USB64/nextcloud/html:/var/www/html
#

# For btrfs-snapshot-rotation.sh take a look to https://github.com/dolorosus/RaspiBackup
#

export MYANME=${0##*/}
export ORGNAME=$(readlink -f "${0}")

colors=${ORGNAME%%${ORGNAME##*/}}COLORS.sh
[ -f ${colors} ] && . ${colors}

SNAPSCRIPT=${ORGNAME%%${ORGNAME##*/}}/btrfs-snapshot-rotation.sh
[ -x "${SNAPSCRIPT}" ] || {
    msgfail "Script ${SNAPSCRIPT} not found or not executable"
    exit 99
}

STACKNAME="nextcloud"

srcvol="/mnt/USB64"
srcpath="${srcvol}/${STACKNAME}"


snappath="${srcvol}/.snapshots/NEXTCLOUDBCK"
snapname=$(date "+%F--%H-%M-%S")
mark="manual"
versions=28

dstvol="/Downloads"
dstpath="Nextcloudbck"

bckname="${STACKNAME}-${snapname}.tar.xz"

export XZ_DEFAULTS="--threads=4 -6"

# ------------------ Here we go ----------------------------------------------
exec &> >(tee "${0%%.sh}.out")

trap errexit SIGINT SIGTERM

dbcont=$(docker container ls | grep ${STACKNAME}-db | cut -d\  -f1)
[ -z "${dbcont}" ] && errexit "DB container cannot be found. Is it up?" 5

appcont=$(docker container ls | grep ${STACKNAME}-app | cut -d\  -f1)
[ -z "${appcont}" ] && errexit "APP container cannot be found. Is it up?" 6

execCmd "docker container stop ${appcont}" || exit 10
execCmd "docker container stop ${dbcont}" || exit 15

execCmd "${SNAPSCRIPT} ${srcpath} ${snappath} ${mark} ${versions} ${snapname}" || exit 20

execCmd "docker container start ${dbcont}" || exit 35
execCmd "docker container start ${appcont}" || exit 30

#
# take a copy to another volume
#
execCmd "cd ${snappath}/${snapname}@${mark}"
execCmd "find ${dstvol}/${dstpath}  -maxdepth 0 -name ${STACKNAME}-\*.tar.xz  -type f -mtime +7 -delete"
execCmd "tar --xz -cvf  ${dstvol}/${dstpath}/${bckname} * " || exit 20
