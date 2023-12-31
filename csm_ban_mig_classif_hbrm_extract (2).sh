#! /bin/ksh

#*************************************************************************
# Script Name :: csm_ban_mig_classif_hbrm_extract.sh
# Purpose     :: Get Effective ban from BAN_MIG_CLASSIFICATION  and 
#             :: corresponding param_value from ADDITIONAL_PARAMS 
#             :: based on param_name and create CSV a file, split it based 
#             :: configurable ban count variable and Encrypt those files
#             :: using GPG algorithm.
# Supervisor  :: Roohie Ali
# Written By  :: Abhinav Prasad
# Date        :: 09/12/2022
#*************************************************************************
##########################################################################
# Changes History:
#----------+--------------+-----------------------------------------------
# Date     |      By      |  Changes/New features
#----------+--------------+-----------------------------------------------
#          |              | 
#----------+--------------+-----------------------------------------------


##########################################################################
# Definition of Functions
##########################################################################

Exit_Program ()
{
   STATUS=$1 
      echo "\nExit with STATUS = $STATUS from $CURR_PROG at: "; date
      exit $STATUS
}

export TLG_CSM_ROOT_DIR=$TLG_CSM_ROOT/interface/output

if [ ! -d ${TLG_CSM_ROOT_DIR} ]
then
     echo "ERROR: Output Directory is not present. Please check with Infra!!"
     Exit_Program -1
fi


DeleteOrigFile()
{
   ORIG_FILE=$1
      echo "Deleting Original file $ORIG_FILE"
      rm -f $ORIG_FILE 
      echo "Deleted!"
}


EncryptOutputFiles()
{
    HBRM_GPG_KEY=$1
    FILES_TO_ENC="DSD708_HBRM_${DATE_TIME}*"

      for f in $FILES_TO_ENC
      do           
            #remove trailing white spaces
            eval `sed -i 's/[[:space:]]*$//' $f`
            if [ $? -eq 0 ]
            then
                 echo "trailing white spaces removed successfully in $f"
            else
                 echo "failed to remove trailing white spaces in $f"
                 Exit_Program -1
            fi

            
            #redirecting checksum of .csv to a .txt file
            touch DSD708_HBRM_${DATE_TIME}_FILES_CHECKSUM.txt
            
            echo `sha256sum $f` >> DSD708_HBRM_${DATE_TIME}_FILES_CHECKSUM.txt
            if [ $? -eq 0 ]
            then
                 echo "checksum for $f successfully appended in DSD708_HBRM_${DATE_TIME}_FILES_CHECKSUM.txt"
            else
                 echo "failed to append checksum for $f in DSD708_HBRM_${DATE_TIME}_FILES_CHECKSUM.txt"
                 Exit_Program -1
            fi


            #encrypt file
            eval `gpg --always-trust -e -r $HBRM_GPG_KEY $f`
               if [ $? -eq 0 ]
               then
                    FOUND_ANY_ENCY_FILE=`find . -name $f.gpg | wc -l`
                    echo "FOUND_ANY_ENCY_FILE : $FOUND_ANY_ENCY_FILE"
                    if [ $FOUND_ANY_ENCY_FILE -gt 0 ]
                    then  
                         echo "$f encrypted successfully"
                    else
                         echo "$f encryption failed as the public-key may not be present on this env"
                         DeleteOrigFile $f
                    fi          
               else
                  echo "$f encryption failed in unknown circumstances"
                  DeleteOrigFile $f
                  Exit_Program -1
               fi
       done
}



#########################################################################
# Main script
#########################################################################


if [ "$#" -eq 0 ]
then
     print "\nInvalid number of positional parameters passed"
     print "\nDB connect string not passed after : $0"
     print "\nDB String DB connect string example format : <SSTAPP13/SSTAPP13@DEVDB101>"
     Exit_Program -1
fi

if [ "$#" -eq 1 ]
then
     print "\nDB String : $1"
fi

if [ "$#" -gt 1 ]
then
     print "\nWrong number of positional parameters passed"
     Exit_Program -1
fi


export CURR_PROG=$0

CONN_STR=`echo $1`

export USER=`echo ${CONN_STR} | sed -e s/'\/'/' '/g | awk '{print $1}'`
export INST=`echo ${CONN_STR} | sed -e s/'@'/' '/g | awk '{print $2}'`

export SYSDATE=`date -u +%Y%m%d`
export SYSTIME=`date +%H%M%S`
export DATE_TIME=${SYSDATE}_${SYSTIME}

export HBRM_SPLIT_BAN_COUNT=5

echo "\nCONN_STR is : $CONN_STR"

ONLINE_DATE=`sqlplus -s ${CONN_STR} <<!
set pagesize 0
set heading off
set linesize 200

whenever sqlerror exit 3

select trim(to_char(LOGICAL_DATE,'YYYYMMDD'))
from logical_date
where EXPIRATION_DATE is null
and LOGICAL_DATE_TYPE='O';
!`
 
echo "\nONLINE_DATE = ${ONLINE_DATE}"

if [ "${ONLINE_DATE}" == "" ]
then
     echo -e "Online Date is not present in table LOGICAL_DATE."
     Exit_Program -1
fi

#################################################################################
# Check if any old Temporary Table exist already then Drop it 
#################################################################################

TABLE_COUNT=`sqlplus -s ${CONN_STR} <<!
set pagesize 0
set heading off
set linesize 200

whenever sqlerror exit 3

select count(*) from tab where tname = 'TEMP_BAN_HBRM_DTS';
!`

echo "\nTABLE_COUNT = ${TABLE_COUNT}"

if [ "${TABLE_COUNT}" -gt 0 ]
then
     echo "FOUND OLD TABLE IN DB : NEED TO DROP THE TABLE"
    
     sqlplus ${CONN_STR} <<!
     set echo off
     set timing on
     set time on
     set termout off
     set head on
     set feed off

     spool $TLG_CSM_ROOT/interface/output/drop_temp_table_before_${USER}_${INST}_${DATE_TIME}.log

     prompt DROP TABLE TEMP_BAN_HBRM_DTS

     DROP TABLE TEMP_BAN_HBRM_DTS;

     exit
!

     if [ `grep ORA- $TLG_CSM_ROOT/interface/output/drop_temp_table_before_${USER}_${INST}_${DATE_TIME}.log | wc -l` -gt 0 ]
     then
           echo "ERROR IN DROPPING THE OLD TABLE : TEMP_BAN_HBRM_DTS" 
           grep ORA- $TLG_CSM_ROOT/interface/output/drop_temp_table_before_${USER}_${INST}_${DATE_TIME}.log

     fi


fi


#####################################################################################
# Creating new Temporary Table TEMP_BAN_HBRM_DTS
#####################################################################################

sqlplus ${CONN_STR} <<!
set echo on
set timing on
set time on
set termout on
set head on
set feed on

whenever sqlerror exit 3

spool $TLG_CSM_ROOT/interface/output/cre_temp_tabs_${USER}_${INST}_${DATE_TIME}.log

prompt CREATE TABLE TEMP_BAN_HBRM_DTS

CREATE TABLE TEMP_BAN_HBRM_DTS
( BAN NUMBER(9) NOT NULL,
  HBRM_PRM_VALUE VARCHAR2(100) NOT NULL
);

exit
!

if [ `grep ORA- $TLG_CSM_ROOT/interface/output/cre_temp_tabs_${USER}_${INST}_${DATE_TIME}.log | wc -l` -gt 0 ]
then
      echo "Error While Creating Temporary Table!"
      grep ORA- $TLG_CSM_ROOT/interface/output/cre_temp_tabs_${USER}_${INST}_${DATE_TIME}.log
      Exit_Program -1

fi

######################################################################################
# Inserting records into new Temporary Table TEMP_BAN_HBRM_DTS 
######################################################################################

sqlplus ${CONN_STR} <<!
set pagesize 0
set echo on
set timing on
set time on
set head on
set feed on
set verify on
set serveroutput on size 1000000

SPOOL $TLG_CSM_ROOT/interface/output/insert_log_${USER}_${INST}_${DATE_TIME}.log

whenever sqlerror exit 3

prompt Populating TEMP_BAN_HBRM_DTS

INSERT
INTO TEMP_BAN_HBRM_DTS tbhd
SELECT DISTINCT
       bmc.ban, ap.param_value
       FROM BAN_MIG_CLASSIFICATION bmc, ADDITIONAL_PARAMS ap
       WHERE ap.param_name = 'EXPT_HBRM'
       AND ap.customer_id = bmc.ban
       AND bmc.effective_date <= TO_DATE('${ONLINE_DATE}','YYYYMMDD')
       AND  NVL(bmc.expiration_date, TO_DATE('47001231', 'YYYYMMDD')) > TO_DATE('${ONLINE_DATE}','YYYYMMDD');

       commit;
EXIT;
!

if [ `grep ORA- $TLG_CSM_ROOT/interface/output/insert_log_${USER}_${INST}_${DATE_TIME}.log | wc -l ` -gt 0 ]
then

      echo "\nERROR in populating the TEMP_BAN_HBRM_DTS table:\n"
      grep ORA- $TLG_CSM_ROOT/interface/output/insert_log_${USER}_${INST}_${DATE_TIME}.log
      Exit_Program -1

fi


#######################################################################################
# Getting RowCount of entries inside the TEMP_BAN_HBRM_DTS
#######################################################################################

ROW_COUNT=`sqlplus -s ${CONN_STR} <<!
set pagesize 0
set heading off
set linesize 200

whenever sqlerror exit 3

select count(*) from
TEMP_BAN_HBRM_DTS;
!`

echo "\nROW_COUNT = ${ROW_COUNT}"

#######################################################################################
# If Row Count is less than value of HBRM_SPLIT_BAN_COUNT variable then create only 
# one CSV File
#######################################################################################

if [ ${ROW_COUNT} -le $HBRM_SPLIT_BAN_COUNT ]
then

     TOTAL_FILE_COUNT=1
     echo "\nTOTAL_FILE_COUNT = ${TOTAL_FILE_COUNT}"

     SPOOL_FILE_NAME="DSD708_HBRM_${DATE_TIME}_01_OUTPUT.csv"

     TMP_CSV_FILE="$TLG_CSM_ROOT/interface/output/cre_temp_csv_${USER}_${INST}_${DATE_TIME}.csv"

     sqlplus -s ${CONN_STR} >> ${TMP_CSV_FILE} << !
     set heading off;
     set feedback off;
     set pagesize 0;

     spool $TLG_CSM_ROOT/interface/output/$SPOOL_FILE_NAME;

     SELECT 'MassRequestReason,ColumnIndex,DataIndex' FROM dual
     union all
     SELECT 'Customer Request,3,4' FROM dual
     union all
     SELECT 'BAN ID,Valid Value' FROM dual
     union all
     SELECT BAN ||','||HBRM_PRM_VALUE
     FROM TEMP_BAN_HBRM_DTS;

     spool off;
     quit;
!


     # If spool file is still empty, then just exit, otherwise, continue processing
     if [[ ! -f "$TLG_CSM_ROOT/interface/output/$SPOOL_FILE_NAME" ]]  then
           echo "failed to spool file or file is still empty therefore exiting"
           Exit_Program -1
     fi

     cd $TLG_CSM_ROOT/interface/output/
     rm -f cre_temp_csv_${USER}_${INST}_${DATE_TIME}.csv

fi


##########################################################################################
# If Row Count is greater than value of HBRM_SPLIT_BAN_COUNT variable then create multiple
# CSV Files based on pre-determined value of HBRM_SPLIT_BAN_COUNT
##########################################################################################

if [ ${ROW_COUNT} -gt $HBRM_SPLIT_BAN_COUNT ]
then

      TOTAL_FILE_COUNT=`echo $(($ROW_COUNT/$HBRM_SPLIT_BAN_COUNT))`

      UPDATED_FILE_COUNT=`echo $(($ROW_COUNT%$HBRM_SPLIT_BAN_COUNT))`

      if [ ${UPDATED_FILE_COUNT} -gt 0 ]
      then

           ADD_ONE_MORE_FILE=1

           TOTAL_FILE_COUNT=`echo $(($TOTAL_FILE_COUNT + $ADD_ONE_MORE_FILE))`
      fi

      echo "\nTOTAL_FILE_COUNT = ${TOTAL_FILE_COUNT}"

      SPOOL_FILE_NAME="MSD708_HBRM_${DATE_TIME}_${TOTAL_FILE_COUNT}_OUTPUT.csv"

      TMP_CSV_FILE="$TLG_CSM_ROOT/interface/output/cre_temp_csv_${USER}_${INST}_${DATE_TIME}.csv"

      sqlplus -s ${CONN_STR} >> ${TMP_CSV_FILE} << !
      set heading off;
      set feedback off;
      set pagesize 0;

      spool $TLG_CSM_ROOT/interface/output/$SPOOL_FILE_NAME;

      SELECT 'MassRequestReason,ColumnIndex,DataIndex' FROM dual
      union all
      SELECT 'Customer Request,3,4' FROM dual
      union all
      SELECT 'BAN ID,Valid Value' FROM dual
      union all
      SELECT BAN ||','||HBRM_PRM_VALUE
      FROM TEMP_BAN_HBRM_DTS; 

      spool off;
      quit;
!

      # If spool file is still empty, then just exit, otherwise, continue processing
      if [[ ! -f "$TLG_CSM_ROOT/interface/output/$SPOOL_FILE_NAME" ]]  then
            echo "failed to spool file or file is still empty therefore exiting"
            Exit_Program -1
      fi

      cd "$TLG_CSM_ROOT/interface/output"

      chmod 777 ${SPOOL_FILE_NAME} 

#     ll ${SPOOL_FILE_NAME}

      POOL_FILE_NAME="LSD708_HBRM_${DATE_TIME}_${TOTAL_FILE_COUNT}_OUTPUT.csv"

      touch ${POOL_FILE_NAME}

      chmod 777 ${POOL_FILE_NAME}

      tail -n +4 "$SPOOL_FILE_NAME" > ${POOL_FILE_NAME}

      split --lines=${HBRM_SPLIT_BAN_COUNT} --numeric-suffixes=1 --suffix-length=2 --additional-suffix=_OUTPUT.csv ${POOL_FILE_NAME} DSD708_HBRM_${DATE_TIME}_ 

      for file in DSD708_HBRM_${DATE_TIME}_*
      do
          head -n 3 "$SPOOL_FILE_NAME" > with_header_tmp
          cat "$file" >> with_header_tmp
          mv -f with_header_tmp "$file"
      done

      rm -f LSD708_HBRM_${DATE_TIME}_*
      rm -f MSD708_HBRM_${DATE_TIME}_*
      rm -f cre_temp_csv_${USER}_${INST}_${DATE_TIME}.csv 

fi

###########################################################################################
# Check if Encryption Key is present in environment or not
##########################################################################################

export ENCRYPTION_KEY=`echo $D1_HBRM_ENC_KEY`
if [ "$ENCRYPTION_KEY" = "" ]
then
     echo "ERROR: D1_HBRM_ENC_KEY environment variable is NULL .Please check with Infra!!"
     rm -f DSD708_HBRM_*
     Exit_Program -1
fi

echo  "\nencryption key is $ENCRYPTION_KEY"


##########################################################################################
# Getting count of CSV files to be sent for encryption & calling EncryptOutputFiles()
##########################################################################################

countCSVFiles=`ls -1 DSD708_HBRM_${DATE_TIME}* | wc -l`

echo "\ncountCSVFiles : ${countCSVFiles}"
if [ $countCSVFiles -eq 0 ]
then
     echo "No CSV file/s Found"
     Exit_Program -1
else
     echo "${countCSVFiles} CSV file/s Found"
     echo "Starting Encryption process..."
     EncryptOutputFiles $ENCRYPTION_KEY
fi


Exit_Program 0









