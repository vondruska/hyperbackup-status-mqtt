# hyperbackup-status-mqtt

Bash script to publish Synology's Hyper Backup job status via MQTT.

Based on the amazing work from [WAdama/nas_hb_status](https://github.com/WAdama/nas_hb_status).

The sensor will show the status of the backups, integrity, time passed since the last backup & integrity check, size and changed size of data. The data is collected from */var/log/synolog/synobackup.log* & */var/log/messages*.

Tested on DS 918+ with DSM 6.2.4-25556 and Hyper Backup 2.2.6-1316 

### Prerequistes / Dependencies

* `mosquitto_pub` installed on `PATH`. Can be obtained from Syno Community packages 
* `md5sum` installed. Available by default.

### Installing

Place the script and configuration anywhere that can be run on a cron/Task Scheduler from the Synology UI.

```
wget https://raw.githubusercontent.com/vondruska/nas_hb_status_mqtt/master/nas_hb_status.sh
chmod +x nas_hb_status.sh
```


The configuration file must contain the following entries according to your backup tasks and the path and names of the needed logs:

```
MQTT_USERNAME=username
MQTT_PASSWORD=password
MQTT_HOST=my-mqtt-host.example.com

TASKS=("Backup - No1" "Backup - No2" "Backup - No3")
LOG="/var/log/synolog/synobackup.log"
LOGROTATED="/var/log/synolog/synobackup.log.0"
SYSLOG="/var/log/messages"
```

Schedule the script to run on an interval within the Synology UI:

1. Control Panel > Task Scheduler
1. Create new Scheduled Task > User Defined Script
1. Name as you wish, must be root for access to the logs
1. Set the schedule as you wish. I have mine set a couple times an hour to catch adhoc runs.
1. Run command should something like `/path/to/the/script/nas_hb_status.sh /path/to/you/config.conf`

### Sensors / MQTT

If you're using [Home Assistant](https://home-assistant.io), the script will publish auto discovery information allowing sensors to be created using the format `HyperBackup - {Job Name} - {Sensor Name}`.

All sensor data is published into MQTT with this topic format `hyperbackup/{Job Name}/{Sensor Slug}`.

The sensors available:

| Name | Slug | Meaning | Unit |
|-------------|------|---------|------|
|Last Backup End Time|`time-end`|The time when the backup finished|ISO8601 Timestamp|
|Backup Status|`backup-status`|String value for status. Values include: `Finished Successfully`, `Failed`, `Created`, `Started`, `Cancelled`, `Suspension Complete`, `Resume Backup`, `Partially Completed`| n/a |
|Integrity Status|`integrity-status`|String value for integreity checks. Values include: `No Error`, `Has Started`, `Broken`, `Failed` | n/a 
|Runtime|`runtime`|Amount of time the last backup took|seconds|
|Size|`size`|The size of the backup|KB|
|Size Change|`size-change`|The change in backup size between runs|KB|