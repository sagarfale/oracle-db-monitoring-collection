#!/bin/bash
########################################################################################################
# Name          : ora-file-system-monitoring.sh
# Author        : Sagar Fale
# Date          : 29/12/2022
#
# Description:  - This script will check if DB is up and running
#
# Usage         : ora-file-system-monitoring.sh - v2
#
#               This script needs to be executed from target database server as user oracle.
#
# Modifications :
#
# When         Who               What
# ==========   ===========    ================================================================
# 29/12/2022   Sagar Fale     Initial draft version
# 31/12/2022   Sagar Fale     adding db down logic
########################################################################################################

ORATAB=/tmp/oratab
HOSTNAME=`hostname`
mkdir -p /home/oracle/scripts/log/
HOST=`hostname | awk -F\. '{print $1}'`
tlog=`date "+ora_filesystem_log-%d%b%Y_%H%M".log`
script_base=/home/oracle/scripts
logfile=`echo /home/oracle/scripts/log/${tlog}`
> ${logfile}
date >> ${logfile}
echo "" >> ${logfile}

MAIL_LIST=   ## specify th email id for notifications


cd ${script_base}

 sendemail_notify()
   {
      (
         echo "Subject: ${tempvalue}"
         echo "TO: $MAIL_LIST"
         echo "FROM: test@test.com"
         echo "MIME-Version: 1.0"
         echo "Content-Type: text/html"
         echo "Content-Disposition: inline"
      )  | /usr/sbin/sendmail $MAIL_LIST
}

 sendemail_notify_t()
   {
      (
         echo "Subject: ${tempvalue}"
         echo "TO: $MAIL_LIST"
         echo "FROM: test@test.com"
         echo "MIME-Version: 1.0"
         echo "Content-Type: text/html"
         echo "Content-Disposition: inline"
         cat $a
      )  | /usr/sbin/sendmail $MAIL_LIST -t
}


df -hPT | egrep 'ext4|xfs' |fgrep -v '/boot' | awk '{ print $7"_:_" $6}' > /tmp/disk_usage.info
VALUE=90
for line in `cat /tmp/disk_usage.info`
do
        FILESYSTEM=$(echo "$line" | awk -F"_:_" '{ print $1 }')
        DISK_USAGE=$(echo "$line" | awk -F"_:_" '{ print $2 }' | cut -d'%' -f1 )
        #echo -n "$FILESYSTEM " ; echo "$DISK_USAGE"
        if [ $DISK_USAGE -ge $VALUE ];
        then
        echo "checking $FILESYSTEM : $DISK_USAGE"
        tempvalue="Notify --> Hostname: $HOSTNAME File system Alert"
        df -h  > ${script_base}/file-system-usage.temp
        sh ${script_base}/con-text-html.sh
        a=${script_base}/file-system-usage.html
        sendemail_notify_t ${a};
        elif [ $DISK_USAGE -lt $VALUE ]; then
           echo ""
        fi
done

### housekeeping of logs 
find /home/oracle/scripts/log -name "*.log" -type f -mtime +5 -exec rm {} \;