#!/bin/bash

###################
# Start Processes #
###################

## Start Apache2
apachectl -D FOREGROUND &

## Start Nagios Core
/usr/local/nagios/bin/nagios -d /usr/local/nagios/etc/nagios.cfg &

## Give processes time to start
sleep 7

#############################
# Monitor Apache and Nagios #
#############################

## Function to check if a process is running

is_process_running() {
	if pgrep -x "$1" >/dev/null; then
		return 0 # Process is running
	else
		return 1 # Process is not running
	fi
}

## Main function to monitor Apache2 and Nagios processes

monitor_processes() {
	while :
	do
		# Check if Apache2 is running
		if ! is_process_running "apache2"; then
			echo "Apache2 is not running. Exiting."
			exit 1
		fi

		# Check if Nagios is running
		if ! is_process_running "nagios"; then
			echo "Nagios is not running. Exiting."
			exit 1
		fi

		# Sleep for 5 seconds before checking again
		sleep 5
	done
}

## Starting monitoring processes

monitor_processes
