#!/bin/bash
# Version 1.2.4

CONF=$1
source $CONF

for TASK in "${TASKS[@]}"
do
CONTENT=`cat $LOG | grep "task" | grep "\[$TASK\]" | tail -1`
if [ -z "${CONTENT}" ]; then
	CONTENT=`cat $LOGROTATED | grep "task" | grep "\[$TASK\]" | tail -1`
fi
INTEGRITY=`cat $LOG | grep "integrity check" | grep "\[$TASK\]" | tail -1`
if [ -z "${INTEGRITY}" ]; then
	INTEGRITY=`cat $LOGROTATED | grep "integrity check" | grep "\[$TASK\]" | tail -1`
fi
TASKID=`cat $SYSLOG | grep "task" | grep "\[$TASK\]" | tail -1 | sed -n "s/^.*img_backup: (\s*\([0-9]*\).*$/\1/p"`
if [ -z "${TASKID}" ]; then
	RUNTIME="0"
	BKPSIZE="0"
	LASTBKPSIZE="0"
	else
	RUNTIME=`cat $SYSLOG | grep "task" | grep "\[$TASK\]" | tail -1 | sed -n "s/^.*Time spent: \[\s*\([0-9]*\).*$/\1/p"`
	BKPSIZE=`cat $SYSLOG | grep "img_backup" | grep "$TASKID" | grep "Storage Statistics" | tail -1 | sed -n "s/^.*: TargetSize(KB):\[\s*\([0-9]*\).*$/\1/p"`
	LASTBKPSIZE=`cat $SYSLOG | grep "img_backup" | grep "$TASKID" | grep "Storage Statistics" | tail -1 | sed -n "s/^.*LastBackupTargetSize(KB):\[\s*\([0-9]*\).*$/\1/p"`
fi
TIME=`cat $LOG | grep "task" | grep "\[$TASK\]" | grep -o "[0-9]\{4\}/[0-9]\{2\}/[0-9]\{2\}\ [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}" | tail -1`
if [ -z "${TIME}" ]; then
	TIME=`cat $LOGROTATED | grep "task" | grep "\[$TASK\]" | grep -o "[0-9]\{4\}/[0-9]\{2\}/[0-9]\{2\}\ [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}" | tail -1`
fi
INTTIME=`cat $LOG | grep "Backup integrity check" | grep "\[$TASK\]" | grep -o "[0-9]\{4\}/[0-9]\{2\}/[0-9]\{2\}\ [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}" | tail -1`
if [ -z "${INTTIME}" ]; then
	INTTIME=`cat $LOGROTATED | grep "Backup integrity check" | grep "\[$TASK\]" | grep -o "[0-9]\{4\}/[0-9]\{2\}/[0-9]\{2\}\ [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}" | tail -1`

fi
TIMEEND=`date -d "$TIME" +%s`
TIMEENDISO=`date -d "$TIME" --iso-8601=seconds`
INTTIMEEND=`date -d "$INTTIME" +%s`

if [[ $CONTENT == *"finished successfully"* ]]; then
	STATUS="Finished Successfully"
	elif [[ $CONTENT == *"Failed"* ]]; then
	STATUS="Failed"
	elif [[ $CONTENT == *"created"* ]]; then
	STATUS="Created"
	elif [[ $CONTENT == *"started"* ]]; then
	STATUS="Started"
	elif [[ $CONTENT == *"cancelled"* ]]; then
	STATUS="Cancelled"
	elif [[ $CONTENT == *"suspension complete"* ]]; then
	STATUS="Suspension Complete"
	elif [[ $CONTENT == *"resume backup"* ]]; then
	STATUS="Resume Backup"
	elif [[ $CONTENT == *"partially completed"* ]]; then
	STATUS="Partially Completed"
fi

if [[ $INTEGRITY == *"No error was found"* ]]; then
	INTSTATUS="No Error"
	elif [[ $INTEGRITY == *"has started"* ]]; then
	INTSTATUS="Has Started"
	elif [[ $INTEGRITY == *"target is found broken"* ]]; then
	INTSTATUS="Broken"
	elif [[ $INTEGRITY == *"Failed to run backup integrity check"* ]]; then
	INTSTATUS="Failed"
	else
	INTSTATUS="0"
fi

ACTTIME=`date +%s`
#LASTRUN=$(($ACTTIME - $TIMEEND))
#INTLASTRUN=$(($ACTTIME - $INTTIMEEND))

BKPCHANGE=$(($BKPSIZE - $LASTBKPSIZE))



mqtt_send() { 
  UNIQUE_ID="$(echo -n "$1_$2" | md5sum | cut -c -32 )"
  if [[ $5 != "" ]]; then
    DEVICE_CLASS_JSON="\"device_class\": \"$5\","
  else
    DEVICE_CLASS_JSON=""
  fi

  DISCOVERY_JSON="{\"state_topic\": \"hyperbackup/$1/$3\",\"unique_id\":\"$UNIQUE_ID\",\"force_update\":true,$DEVICE_CLASS_JSON\"name\": \"HyperBackup - $1 - $2\",\"unit_of_measurement\":\"$6\"}"
  mosquitto_pub -h "$MQTT_HOST" -u "$MQTT_USERNAME" -P "$MQTT_PASSWORD" -t "homeassistant/sensor/$UNIQUE_ID/config" -m "$DISCOVERY_JSON" -d -r
  mosquitto_pub -h "$MQTT_HOST" -u "$MQTT_USERNAME" -P "$MQTT_PASSWORD" -t "hyperbackup/$1/$3" -m "$4" -d
}

mqtt_send "$TASK" "Last Backup End Time" "time-end" "$TIMEENDISO" "timestamp" ""
mqtt_send "$TASK" "Backup Status" "backup-status" "$STATUS" "" ""
mqtt_send "$TASK" "Integrity Status" "integrity-status" "$INTSTATUS" "" ""
mqtt_send "$TASK" "Runtime" "runtime" "$RUNTIME" "" "s"
mqtt_send "$TASK" "Size" "size" "$BKPSIZE" "" "KB"
mqtt_send "$TASK" "Size Change" "size-change" "$BKPCHANGE" "" "KB"

done
exit