#!/bin/bash
########################################################################################################
# Name          : ora-db-locks-monitoring.sh
# Author        : Sagar Fale
# Date          : 29/12/2022
#
# Description:  - This script will check if DB is up and running
#
# Usage         : ora-db-locks-monitoring.sh - v2
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
tlog=`date "+ora_db_locks-log-%d%b%Y_%H%M".log`
script_base=/home/oracle/scripts
logfile=`echo /home/oracle/scripts/log/${tlog}`
> ${logfile}
date >> ${logfile}
echo "" >> ${logfile}

MAIL_LIST=   ## specify th email id for notifications

cd ${script_base}

cp /etc/oratab  /tmp/oratab

if [[ ! -r $ORATAB ]]; then
   echo "*** SKIP!! File $ORATAB doesn't exist or accessible to user $USER. Exiting ..."
   exit 0

else
   oracle_sids=$(awk -F: '!/^#/ && !/^[ \t]*$/ {print $1}' /etc/oratab 2> /dev/null);
   if [[ -z "${oracle_sids}" ]]; then
      echo "*** SKIP!! No Oracle sids found in $ORATAB. Exiting ..."
      exit 0
   fi
fi

## copying ortab file 


FILE="/tmp/oratab"

if [[ -r $FILE && -w $FILE ]]; then   
   echo "${FILE} is ok.." 
else   
      echo "Check the permissions on /tmp/ortab file"
      exit 0 
fi


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

cp /etc/oratab /tmp/oratab1
ORATAB=/tmp/oratab1
script_base=/home/oracle/scripts

awk -F\: '/^[a-zA-Z]/ {print $1 ":" $2}' $ORATAB > ${script_base}/db_home_values.temp


while IFS=":" read value1 value2
do
   export ORACLE_SID=${value1}
   export ORACLE_HOME=${value2}
   export PATH=$ORACLE_HOME/bin:$PATH
   export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$PATH
   output=`sqlplus -s "/ as sysdba" <<EOF
   set feedback off pause off pagesize 0 heading off verify off linesize 500 term off
   select open_mode  from v\\$DATABASE;
   exit
EOF
`

### dbfunction 
dbfunctions()
{

#### Checking locks in database  ####
sqlplus -s "/ as sysdba" <<EOF
   set feedback off pause off pagesize 0 verify off linesize 500 term off
   set pages 80
   set head off
   set line 120
   set echo off
   set feed off
   set long 50000
   set pagesize 50000
   set markup html on
   spool blocking_session_info_${value1}.html
   select s1.inst_id,s2.inst_id,s1.username || '@' || s1.machine  || ' ( SID=' || s1.sid || ' )  is blocking '  || s2.username || '@' || s2.machine || ' ( SID=' || s2.sid || ' ) ' AS blocking_status   from gv\$lock l1, gv\$session s1, gv\$lock l2, gv\$session s2
   where s1.sid=l1.sid and s2.sid=l2.sid and s1.inst_id=l1.inst_id and s2.inst_id=l2.inst_id   and l1.BLOCK=1 and l2.request > 0   and l1.id1 = l2.id1   and l2.id2 = l2.id2   order by s1.inst_id;
   spool off
   set markup html off
   exit
EOF
   
   if [ -s ${script_base}/blocking_session_info_${value1}.html  ]; then
           tempvalue=`echo "Notify --> $HOSTNAME $ORACLE_SID Blocking session Info"`
           echo "${tempvalue}" >> ${logfile}
           a=${script_base}/blocking_session_info_${value1}.html
           sendemail_notify_t ${a};
   else
          echo "${value1} DB No Blocking sessions .. Passed " >> ${logfile}
   fi  

### end of DB function 
echo ">>>>>>>>>>>>>>>>>>>>>>>" >> ${logfile}
}

### checking Database ###

   if [ "$output" = "READ WRITE" ] ; then 
       tempvalue=`echo "Notify --> Hostname : $HOSTNAME DBNAME: $ORACLE_SID Up and Running"`
       echo "DB ${value1}is up and running .. passed" >> $logfile
       echo ${tempvalue} >> $logfile
       dbfunctions;
    else
       tempvalue=`echo "Notify --> Hostname : $HOSTNAME DBNAME: $ORACLE_SID Down"`
       echo "DB ${value1}is not up and running .. failed" >> $logfile
       echo ${tempvalue} >> $logfile
       sendemail_notify
   fi

### End of while loop
done <  ${script_base}/db_home_values.temp

### housekeeping of logs 
find /home/oracle/scripts/log -name "*.log" -type f -mtime +5 -exec rm {} \;