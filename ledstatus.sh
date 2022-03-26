#!/bin/bash

LED=/sys/class/leds/led1
LCK=/run/ledstatus

mkdir ${LCK} || exit 1
trap "rmdir ${LCK};exit" 15
#
# LED timeinterval 
#
maxon_ms=5000
maxon_s=$((${maxon_ms}/1000))
sleepint=$((${maxon_s}*2))

echo timer>${LED}/trigger
echo 1 > ${LED}/brightness
#
# Temperature min=40 max=80
#
min_temp=40
max_temp=80
temp_fac=$((${maxon_ms}/(${max_temp}-${min_temp})))
#
# Load min=0, max=6
#
min_load=0
max_load=600
load_fac=$((${maxon_ms}/(${max_load}-${min_load})))

loadavg() {

    local load
    local dummy
   
    read load dummy</proc/loadavg
    load=${load/0./}
    load=${load/./}
    
    [[ ${load} -lt ${min_load} ]] && load=${min_load}
    [[ ${load} -gt ${max_load} ]] && load=${max_load}
    on=$(((${load}-${min_load})*$load_fac))
    
    return
}


tempavg() {

    local temp
    temp=$(($(cat /sys/class/thermal/thermal_zone*/temp)/1000))

    [[ ${temp} -lt ${min_temp} ]] && temp=${min_temp}
    [[ ${temp} -gt ${max_temp} ]] && temp=${max_temp}
    on=$(((${temp}-${min_temp})*$temp_fac))
    
   return
}


init() {
    on=75
    off=75
    echo ${on}>/${LED}/delay_on
    echo ${off}>/${LED}/delay_off
    sleep 5
}


main() {
    init
    while true
    do
       tempavg
       echo ${on}>${LED}/delay_on
       echo $((${maxon_ms}-${on}))>${LED}/delay_off
       sleep ${sleepint}
    done
}

main
