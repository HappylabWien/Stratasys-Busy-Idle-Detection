#!/bin/bash
printerIP=192.168.1.32

pin=17

timeout=60

gpio -g mode $pin out #set Pin to output
gpio -g write $pin 0 #set pin to low (idle) at startup

function setBusy {
	gpio -g write $pin 1
}

function setIdle {
	gpio -g write $pin 0
}

while true
do

	returnCode=$(ruby /home/pi/BusyIdleScript/status_daemon_bst768.rb $printerIP | grep -m 1 "modelerStatus")

#	if [ "$returnCode" == "-modelerStatus {off}" ]; then
#		echo "off"
#		setIdle	
#	fi

	if [ "$returnCode" == "	-modelerStatus {Building}" ]; then
		setBusy
		echo "building"
	fi

	if [ "$returnCode" == "	-modelerStatus {Idle}" ]; then
		setIdle
		echo "idle"
	fi

	if [ "$returnCode" == "	-modelerStatus {Part Done}" ]; then
		setIdle
		echo "part done"
	fi
	sleep $timeout
done
