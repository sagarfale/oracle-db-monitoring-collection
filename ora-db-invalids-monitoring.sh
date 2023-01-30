#!/bin/bash
########################################################################################################
# Name          : ora-db-invalids-monitoring.sh
# Author        : Sagar Fale
# Date          : 29/12/2022
#
# Description:  - This script will check if DB is up and running
#
# Usage         : ora-db-invalids-monitoring.sh
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
tlog=`date "+ora_dbcheck_inavlids-log-%d%b%Y_%H%M".log`
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
### Checking invalids ####

invalid_count=0
invalid_count=`sqlplus -s "/ as sysdba" <<EOF
   set feedback off pause off pagesize 0 heading off verify off linesize 500 term off
   select count(*)  from dba_objects where status = 'INVALID';
   exit
EOF
`
echo "${value1} DB : Count of invalids : ${invalid_count}" >> $logfile

invalid_details=`sqlplus -s "/ as sysdba" <<EOF
   set feedback off pause off pagesize 0 heading on verify off linesize 500 term off
   set pagesize 50000
   set markup html on
   COLUMN object_name FORMAT A30
   spool invalid_details_${value1}.html
   SELECT owner,object_type,object_name,status,LAST_DDL_TIME FROM dba_objects WHERE  status = 'INVALID' ORDER BY owner, object_type, object_name;
   spool off
   set markup html off
   exit
EOF
`
a=${script_base}/invalid_details_${value1}.html


if [ ! -f "${script_base}/previous_invalid_count_${value1}.temp" ]; then
      > "${script_base}/previous_invalid_count_${value1}.temp"
      echo "0" > ${script_base}/previous_invalid_count_${value1}.temp
      echo "invalid file not present for DB ${value1}.." >> ${logfile}

   else 
      previous_count=`cat ${script_base}/previous_invalid_count_${value1}.temp`
      echo "Previous invalid count : ${previous_count}"  >> ${logfile}
      echo "Current invalid count : ${invalid_count}"  >> ${logfile} 
      if [ ${invalid_count} -gt ${previous_count} ] && [ ${invalid_count} > 0 ]
      then  
         tempvalue=`echo "Notify --> Hostname: $HOSTNAME DBNAME: $ORACLE_SID --> Invalids Count has been changed"`
         echo "${tempvalue}" >> ${logfile}
         sendemail_notify_t ${a};
      fi 
fi  
echo ${invalid_count} > ${script_base}/previous_invalid_count_${value1}.temp

## end of DB function 
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