#!/usr/bin/env bash
#
######################################################################################
######################################################################################
## NJarpscan local network Script
## Desc: Scan Network for matching MAC or IP adresses 
## and ( start | stop ) Daemons or run Scripts if matchs.
######################################################################################
######################################################################################
# path & script name & mod debug ( full verbose ):
SCRIPTPATH=$(dirname ${0})
# Script name without extention:
SCRIPTNAME=$(basename ${0%.*})
# Debug mod:
Sdebug=0
# Only Root User ( must be set to 1 for arp-scan ):
SbeROOT=1

CONFIGFILE="/etc/${SCRIPTNAME}/${SCRIPTNAME}.conf"
LOGFILE="/var/log/${SCRIPTNAME}.log"
SCANFILE="/var/log/${SCRIPTNAME}.scan"

######################################
## DEFAULT CONFIG ( modify the configuration $CONFIGFILE instead of replacing the default located below )
######################################
# default Tempo (en seconde):
Tempo_IF_UP=600
Tempo_IF_DOWN=120
###################
# default Directory location for scripts:
SCRIPTSDIR_IF_UP="/etc/${SCRIPTNAME}/if-up.d"
SCRIPTSDIR_IF_DOWN="/etc/${SCRIPTNAME}/if-down.d"
#####################################
# Arp-Scan options:
##ARPSCAN_OPTIONS="--interface=eth0 --localnet"
ARPSCAN_OPTIONS="--localnet"
######################################
## END DEFAULT CONFIG 
######################################
# Test if in terminal :
[[ -t 1 ]] && SinTerm=1
#####################################
# Test ROOT UID:
msg_beroot="< ! > Must be root to run this script < ! >"
ROOT_UID=0 # Only users with $UID 0 have root privileges.
E_NOTROOT=67 # Non-root exit error.
# Run as root, of course.
if ((SbeROOT)) && [ "$UID" -ne "$ROOT_UID" ] ; then
	((SinTerm)) && echo "$msg_beroot"
	exit $E_NOTROOT
fi
#####################################
# CONFIG FILE:
# read conf file 
if [ -r $CONFIGFILE ]; then
	. $CONFIGFILE
else
	((SinTerm)) && echo "config file missing: $SCRIPTNAME.conf"
	exit 1
fi
# log options:
LOG_enable_date=1
LOG_date_format="+%b %d %T"
LOG_Header="${HOSTNAME} ${SCRIPTNAME}[$$]:"
LOG_max_lines=200
######################################################################################
######################################################################################
##############       ________  ___   ______________________  _   __    ###############
##############      / ____/ / / / | / / ____/_  __/  _/ __ \/ | / /    ###############
##############     / /_  / / / /  |/ / /     / /  / // / / /  |/ /     ###############
##############    / __/ / /_/ / /|  / /___  / / _/ // /_/ / /|  /      ###############
##############   /_/    \____/_/ |_/\____/ /_/ /___/\____/_/ |_/       ###############
##############                                                         ###############
######################################################################################
######################################################################################
#
# Log fct
fct__dateform() {
((LOG_enable_date)) && date "$LOG_date_format" || return
}
log__type() {
  local type=$1 ; shift
  echo $(fct__dateform) ${LOG_Header} "${type}:" $@ >> ${LOGFILE}
}
log__init() {
  log__type "INIT" $@
}
log__info() {
  log__type "INFO" $@
}
log__warning() {
  log__type "WARNING" $@
}
log__error() {
  log__type "ERROR" $@
}
log__daemon() {
  log__type "DAEMON" $@
}
log__script() {
  log__type "SCRIPT" $@
}
log__debug() {
  log__type "DEBUG" $@
}
log__exit() {
  log__type "EXIT" $@
}
# Log tail 
log__tail() {
  TMP=$(tail -n ${LOG_max_lines} ${LOGFILE} 2>/dev/null) && echo "${TMP}" > ${LOGFILE}
}
######################################################################################
######################################################################################
# timing en second  (Positional parameters $1) ex : fct__SLEEP_sec 8
fct__SLEEP_sec() {
local a
for ((a=1; a <=$1 ; a++)) ; do sleep 1 ; done 
}
######################################
# timing en minute  ( Positional parameters $1) ex : fct__SLEEP_min 2
fct__SLEEP_min () {
local a min
min=$(( 60 * $1 ))
for ((a=1; a <=$min ; a++)) ; do sleep 1 ; done 
}
######################################################################################
######################################################################################
# compare element $1 to the array $2 
fct__ContainsElement () {
  local e
  for e in "${@:2}"; do [[ "${e%.service}" == "${1%.service}" ]] && return 0; done
  return 1
}
######################################
# check config file : array & scripts files & count jobs
fct__CHECK_ERROR_CONFIG () {
	local id imac maccount scount file

	if (( ${#PCMAC[@]} > 0 )) ; then
		for imac in "${PCMAC[@]}" ; do [[ -n $imac ]] && ((++maccount)) ; done ;
	fi		


	if (( ${#DSTART_IF_UP[@]} > 0 )) ; then
		for id in "${DSTART_IF_UP[@]}" ; do
			if [[ -n $id ]] ; then
				fct__ContainsElement "${id%.service}" "${DSTART_IF_DOWN[@]}" && \
					{ 
					log__error "${id%.service} cannot be in arrays DSTART_IF_UP and DSTART_IF_DOWN."
					log__error "Check your config file! Exiting." ; exit 1 
					}
				fct__ContainsElement "${id%.service}" "${DSTOP_IF_UP[@]}" && \
					{ 
					log__error "${id%.service} cannot be in arrays DSTART_IF_UP and DSTOP_IF_UP."
					log__error "Check your config file! Exiting." ; exit 1 
					}
				((++scount))	
			fi
		done	
		unset id
	fi

	if (( ${#DSTART_IF_DOWN[@]} > 0 )) ; then
		for id in "${DSTART_IF_DOWN[@]}" ; do
			if [[ -n $id ]] ; then
				fct__ContainsElement "${id%.service}" "${DSTART_IF_UP[@]}" && \
					{
					log__error "${id%.service} cannot be in arrays DSTART_IF_DOWN and DSTART_IF_UP."
					log__error "Check your config file! Exiting." ; exit 1 
					}
				fct__ContainsElement "${id%.service}" "${DSTOP_IF_DOWN[@]}" && \
					{
					log__error "${id%.service} cannot be in arrays DSTART_IF_DOWN and DSTOP_IF_DOWN."
					log__error "Check your config file! Exiting." ; exit 1
					}
				((++scount))	
			fi
		done	
		unset id
	fi

	if [ -d "${SCRIPTSDIR_IF_UP}" ] ; then
		for file in ${SCRIPTSDIR_IF_UP%/}/*; do [[ -x "$file" ]] && ((++scount)) ; done ; unset file
	fi

	if [ -d "${SCRIPTSDIR_IF_DOWN}" ] ; then
		for file in ${SCRIPTSDIR_IF_DOWN%/}/*; do [[ -x "$file" ]] && ((++scount)) ; done ; unset file
	fi
	
	((Tempo_IF_UP)) && [[ ${Tempo_IF_UP} =~ ^[+]?[0-9]+$ ]] || { log__error "<Tempo_IF_UP> must be an integer! Check your config file! Exiting." ; exit 1 ;}
	((Tempo_IF_DOWN)) && [[ ${Tempo_IF_DOWN} =~ ^[+]?[0-9]+$ ]] || { log__error "<Tempo_IF_DOWN> must be an integer! Check your config file! Exiting." ; exit 1 ;}
	
	((maccount)) || { log__error "MAC or IP adresses not found in the config file! Exiting." ; exit 1 ;}
	((scount)) || { log__error "No Daemons service or Scripts found in the config file! Exiting." ; exit 1 ;}

	log__init "CONFIG file Check : OK"
}
######################################################################################
######################################################################################
# arp-scan command
fct__ARPSCMD() {	
	#arp-scan command ( and create the log njaprscan.scan )
	ARPSCMD=$( ( date && ${XARPSCAN} ${ARPSCAN_OPTIONS} ) | tee ${SCANFILE} )
	sleep 1
}
######################################
# grep $ARPSCMD
fct__ARPSCMD_GrepI () {
$(echo -e "$ARPSCMD" | grep -q $i) && { (( ++icount )) ; ((Sdebug)) && log__debug "Found ADRESSE : ${i}" ;}
}
######################################
# Compare mac adresses array & $ARPSCAN scan ( $ARPSCMD )
# if change ( $PCcount != $PCMACmem ) => run: fct_Start ($PCcount > 0) else run: fct_Stop ($PCcount = 0)
fct__PCMAC_TASK () {
local i icount

if (( ${#PCMAC[@]} > 0 )) ; then
	icount=0
	for i in "${PCMAC[@]}" ; do [[ -n $i ]] && fct__ARPSCMD_GrepI ; done
	PCcount=${icount}
	# PC MAC adresses counter memory $PCMACmem :
	if [[ $PCcount != $PCMACmem ]] ; then
		log__info "MAC or IP adresses count : ${PCcount}" 
		PCMACmem=${PCcount}
		((++DDmem))
	fi
	[[ $PCcount > 0 ]] && { fct__PC_TESTPID_START ; HOSTS_UP=${PCcount} ; unset DDmem ;} || { fct__PC_STOP ; unset HOSTS_UP ; unset DDmem ;}
	unset i
	unset icount
fi
}
######################################################################################
######################################################################################
fct__PC_TESTPID_START () {
local iserv file filon idup idon

if (( ${#DSTART_IF_UP[@]} > 0 )) ; then
	for idup in "${DSTART_IF_UP[@]}" ; do
		if [[ -n $idup ]] ; then
			SYSTEST=$( ${XSYSTCTL} is-failed ${idup} )
						
			case "$SYSTEST" in

				active)		log_msg="${idup%.service} is already running."
							{ ((Sinit)) && log__init ${log_msg} ;} || { ((Sdebug)) && log__debug ${log_msg} ;}				
						;;
				inactive)	log__daemon "Starting : ${idup%.service}"
							((++idon))
							( ${XSYSTCTL} start ${idup} )&							
						;;
				unknown)	((DDmem)) && log__warning "daemon : ${idup%.service} not set or enabled in systemd!" 
						;;
				failed)		((DDmem)) && log__warning "daemon : ${idup%.service} seems to be failed!" 
						;;
			esac
			
		fi
	done
	((idon)) && sleep 1
	unset SYSTEST
	unset idup idon
fi

if (( ${#DSTOP_IF_UP[@]} > 0 )) ; then
	for idup in "${DSTOP_IF_UP[@]}" ; do
		if [[ -n $idup ]] ; then
			SYSTEST=$( ${XSYSTCTL} is-failed ${idup} )
						
			case "$SYSTEST" in

				active)		log__daemon "Stopping : ${idup%.service}"
							((++idon))
							( ${XSYSTCTL} stop ${idup} )&					
						;;
				inactive)	log_msg="${idup%.service} is already stopped."
							{ ((Sinit)) && log__init ${log_msg} ;} || { ((Sdebug)) && log__debug ${log_msg} ;}					
						;;
				unknown)	((DDmem)) && log__warning "daemon : ${idup%.service} not set or enabled in systemd!" 
						;;
				failed)		((DDmem)) && log__warning "daemon : ${idup%.service} seems to be failed!" 
						;;
			esac
		fi
	done
	((idon)) && sleep 1
	unset SYSTEST
	unset idup idon
fi
    
if [[ -z $HOSTS_UP ]] ; then  
	if [ -d "${SCRIPTSDIR_IF_UP}" ] ; then		
	  for file in ${SCRIPTSDIR_IF_UP%/}/*; do
		  if [ -x "$file" ]; then			
			((++filon))
			# execute script as job:
			log__script "Executing : ${file}"
			( $file )& 			
		  fi
	  done
	  ((filon)) && sleep 1
	  unset file filon
	fi    
fi

# Njtempo after services start (seconds):
NjTempo=${Tempo_IF_UP}

}
######################################################################################
######################################################################################
fct__PC_STOP () {
local iserv file filon iddown idon

if (( ${#DSTOP_IF_DOWN[@]} > 0 )) ; then
	for iddown in "${DSTOP_IF_DOWN[@]}" ; do
		if [[ -n $iddown ]] ; then
			SYSTEST=$( ${XSYSTCTL} is-failed ${iddown} )
						
			case "$SYSTEST" in

				inactive)	log_msg="${iddown%.service} is already stopped."
							{ ((Sinit)) && log__init ${log_msg} ;} || { ((Sdebug)) && log__debug ${log_msg} ;}
						;;
				active)		log__daemon "Stoping : ${iddown%.service}"
							((++idon))
							( ${XSYSTCTL} stop ${iddown} )&							
						;;
				unknown)	((DDmem)) && log__warning "daemon: ${iddown%.service} not set or enabled in systemd!" 
						;;
				failed)		((DDmem)) && log__warning "daemon: ${iddown%.service} seems to be failed!" 
						;;
			esac
		fi
	done
	((idon)) && sleep 1
	unset SYSTEST
	unset iddown idon
fi

if (( ${#DSTART_IF_DOWN[@]} > 0 )) ; then
	for iddown in "${DSTART_IF_DOWN[@]}" ; do
		if [[ -n $iddown ]] ; then
			SYSTEST=$( ${XSYSTCTL} is-failed ${iddown} )
						
			case "$SYSTEST" in

				active)		log_msg="${iddown%.service} is already running."
							{ ((Sinit)) && log__init ${log_msg} ;} || { ((Sdebug)) && log__debug ${log_msg} ;}				
						;;
				inactive)	log__daemon "Starting : ${iddown%.service}"
							((++idon))
							( ${XSYSTCTL} start ${iddown} )&							
						;;
				unknown)	((DDmem)) && log__warning "daemon: ${iddown%.service} not set or enabled in systemd!" 
						;;
				failed)		((DDmem)) && log__warning "daemon: ${iddown%.service} seems to be failed!" 
						;;
			esac
		fi
	done
	((idon)) && sleep 1
	unset SYSTEST
	unset iddown idon
fi

if [[ -n ${HOSTS_UP} ]] ; then
	if [ -d "${SCRIPTSDIR_IF_DOWN}" ]; then     	
	  for file in ${SCRIPTSDIR_IF_DOWN%/}/*; do
		  if [ -x "$file" ]; then
			
			((++filon))
			# execute script as job:
			log__script "Executing : ${file}"
			( $file )&
		  fi
	  done
	  ((filon)) && sleep 1
	  unset file filon
	fi    
fi  

# Njtempo after stoping services:
NjTempo=${Tempo_IF_DOWN}

}
######################################################################################
######################################################################################
fct__TIMERSET() {
# seconds since 1970-01-01 00:00:00 UTC.
  let $1=$( date +%s ) 
}
######################################################################################
######################################################################################
# functions for trap signals:
clean__up() { 
  log__tail
  return
}
error__exit() {
  ((SinTerm)) && echo "${SCRIPTNAME}: ${1:-\"Unknown Error\"}" >&2
  clean__up
  exit 1
}
graceful__exit() {
  ((SinTerm)) && echo "$SCRIPTNAME: Program terminated" >&2
  clean__up
  exit
}
signal__exit() { 
# Handle trapped signals:
  case $1 in
    SIGINT)
	  log__exit "Program interrupted by user."
      error__exit "Program interrupted by user." ;;
    SIGTERM)
	  log__exit "$SCRIPTNAME: Program terminated."      
      graceful__exit ;;
    *)
	  log__exit "Terminating on unknown signal."
      error__exit "Terminating on unknown signal." ;;
  esac
}

######################################################################################
######################################################################################
##############			    __  ______    _____   __		##############
##############			   /  |/  /   |  /  _/ | / /		##############
##############			  / /|_/ / /| |  / //  |/ / 		##############
##############			 / /  / / ___ |_/ // /|  /  		##############
##############			/_/  /_/_/  |_/___/_/ |_/   		##############
##############								##############
######################################################################################
######################################################################################
# MAIN
######################################################################################
# Trap signals
trap "signal__exit SIGTERM" SIGTERM SIGHUP
trap "signal__exit SIGINT"  SIGINT SIGQUIT 
######################################################################################
# Init System Test
# Only with systemd :
( pidof /lib/systemd/systemd >/dev/null ) || { log__error "Init system must be: \"systemd\" ! Exiting." ; exit 1 ;}
##( pidof /sbin/init >/dev/null ) || exit 1

# System Uptime in seconds:
NjUPT=$(printf '%.0f\n' $( awk '{print $1 ;}' /proc/uptime ) )
######################################################################################
# Log INIT
log__init "####################################################"
log__init "############### INIT $SCRIPTNAME log "
log__init "####################################################"
# Test if arp-scan is installed:
XARPSCAN=$(command -v "arp-scan")
[[ -x "${XARPSCAN}" ]] || { log__error "Install Arp-Scan Package First! Exiting." ; exit 1 ;}
((SbeROOT)) || { log__error "Arp-Scan command need root SUID privilege! set SbeROOT=1 . Exiting." ; exit 1 ;}
# Test systemctl command:
XSYSTCTL=$(command -v "systemctl")
[[ -x "${XSYSTCTL}" ]] || { log__error "Systemd : <systemctl command> missing?! Exiting." ; exit 1 ;}

# check config file array & scripts files & count jobs.
fct__CHECK_ERROR_CONFIG
# Tempo d'attente d'initialisation ( lors du boot du system )
# si uptime < 120sec : on rajoute du tps pour l'init du script
(( NjUPT < 120 )) && { NjTboot=15 ;} || { NjTboot=0 ;}
(( NjUPT < 120 )) && log__init "Loading at Boot : script begin in ${NjTboot}s"

fct__SLEEP_sec $NjTboot

# init var HOSTS_UP ; if we don't want (re)running scripts in the  SCRIPTSDIR_IF_UP directory , after manually restarting Njarpscan : then set HOSTS_UP , else unset . 
(( NjUPT < 120 )) || HOSTS_UP=1
# init var SInit ( always 1 for Initialisation)
((Sinit)) || Sinit=1
######################################################################################
######################################################################################
# infinite loop:
while :
do
	# timer set :
	fct__TIMERSET NjTSnow
	
	if (( NjTSnow >= NjTests )) ; then
		
		fct__ARPSCMD
		fct__PCMAC_TASK
		# fct__CELLMAC_TASK a créer				
		((Sdebug)) && log__debug "Idle Time : sleeping  ${NjTempo}s" 
		# log tail( $LOG_max_lines ) :
		log__tail
		# increment NjTests ( timestamp + $NjTempo )
		NjTests=$(( $NjTSnow + $NjTempo ))			
	fi
	
	fct__SLEEP_sec 2
	unset Sinit
done
######################################################################################
######################################################################################
# Script END
exit 0 
