#!/bin/bash



TICK="[ok]"
CROSS="[X] "
INFO="[i]"
WARN="[w]"
QST="[?]"
IDENT="$   "

msgok () { 
    echo -e "${TICK} ${1}" 
}
msg () { 
    echo -e "${INFO} ${1}" 
}
msgwarn () { 
    echo -e "${WARN} ${1}" 
}
msgfail () { 
    echo -e "${CROSS} ${1}" >&2 
}

colors=${0%%${0##*/}}COLORS.sh
[ -f ${colors} ] && source ${colors}

errexit () {
    echo    "Errexit: Trying to restart containers"
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
# ------------------------- Main -------------------------------------------

exec &> >(tee  "${0}.out")

trap errexit SIGINT SIGTERM

export XZ_DEFAULTS="--threads=4 -6"
export STACKNAME=nextcloud
export bckdir=/Downloads/Nextcloudbck

bckname=${STACKNAME}_$( date +'%Y%M%d_%H%m%S').tar.xz
dbcont=$(docker container ls|grep ${STACKNAME}-db|cut -d\  -f1)
appcont=$(docker container ls|grep ${STACKNAME}-app|cut -d\  -f1)

execCmd "cd /mnt/USB64/" || exit 99
execCmd "find ${bckdir}  -maxdepth 0 -name ${STACKNAME}_\*.tar.xz  -type f -mtime +7 -delete"
execCmd "docker container stop ${appcont}" || exit 10
execCmd "docker container stop ${dbcont}" || exit 15

execCmd "tar --xz -cvf ${bckdir}/${bckname} nextcloud" ||exit 20

execCmd "docker container start ${dbcont}" || exit 35
execCmd "docker container start ${appcont}" || exit 30
