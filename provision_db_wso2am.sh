#!/bin/bash

DB_ENGIN='&CF_DB_NAME'
DB_ENGINE_VERSION='&CF_DB_VERSION'

WSO2_PRODUCT_VERSION='&PRODUCT_VERSION'

TESTGRID_DIR=/opt/testgrid/workspace
# CloudFormation properties
CFN_PROP_FILE="${TESTGRID_DIR}/cfn-props.properties"
PRODUCT_PACK_NAME=$(grep -w "REMOTE_PACK_NAME" ${CFN_PROP_FILE} | cut -d"=" -f2)

DB_SCRIPT_PATH=/opt/testgrid/workspace/dbscripts

function log_info(){
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')]: $1"
}

if [[ $DB_ENGIN = "mysql" ]]; then
    log_info "Mysql DB is selected! Running mysql scripts for apim $WSO2_PRODUCT_VERSION"
    # create databases
    log_info "[Mysql] Droping Databases if exist"
    mysql -u &CF_DB_USERNAME -p&CF_DB_PASSWORD -h &CF_DB_HOST -P &CF_DB_PORT -e "DROP DATABASE IF EXISTS WSO2AM_COMMON_DB"
    mysql -u &CF_DB_USERNAME -p&CF_DB_PASSWORD -h &CF_DB_HOST -P &CF_DB_PORT -e "DROP DATABASE IF EXISTS WSO2AM_APIMGT_DB"
    mysql -u &CF_DB_USERNAME -p&CF_DB_PASSWORD -h &CF_DB_HOST -P &CF_DB_PORT -e "DROP DATABASE IF EXISTS WSO2AM_STAT_DB"

    log_info "[Mysql] Creating Databases"
    mysql -u &CF_DB_USERNAME -p&CF_DB_PASSWORD -h &CF_DB_HOST -P &CF_DB_PORT -e "CREATE DATABASE WSO2AM_COMMON_DB"
    mysql -u &CF_DB_USERNAME -p&CF_DB_PASSWORD -h &CF_DB_HOST -P &CF_DB_PORT -e "CREATE DATABASE WSO2AM_APIMGT_DB"
    mysql -u &CF_DB_USERNAME -p&CF_DB_PASSWORD -h &CF_DB_HOST -P &CF_DB_PORT -e "CREATE DATABASE WSO2AM_STAT_DB"

    log_info "[Mysql] Povisioning WSO2AM_APIMGT_DB"
    mysql -u &CF_DB_USERNAME -p&CF_DB_PASSWORD -h &CF_DB_HOST -P &CF_DB_PORT -D WSO2AM_APIMGT_DB <  $DB_SCRIPT_PATH/apimgt/mysql.sql
    log_info "[Mysql] Povisioning WSO2AM_COMMON_DB"
    mysql -u &CF_DB_USERNAME -p&CF_DB_PASSWORD -h &CF_DB_HOST -P &CF_DB_PORT -D WSO2AM_COMMON_DB <  $DB_SCRIPT_PATH/mysql.sql

elif [[ $DB_ENGIN = "postgres" ]]; then  

    log_info "Postgresql DB is selected! Running Postgresql scripts for apim $WSO2_PRODUCT_VERSION"
    export PGPASSWORD="&CF_DB_PASSWORD"
    
    log_info "[Postgres] Droping Databases if exist"
    psql -U &CF_DB_USERNAME -h &CF_DB_HOST -p &CF_DB_PORT -d postgres -c "DROP DATABASE IF EXISTS \"WSO2AM_COMMON_DB\""
    psql -U &CF_DB_USERNAME -h &CF_DB_HOST -p &CF_DB_PORT -d postgres -c "DROP DATABASE IF EXISTS \"WSO2AM_APIMGT_DB\""
    psql -U &CF_DB_USERNAME -h &CF_DB_HOST -p &CF_DB_PORT -d postgres -c "DROP DATABASE IF EXISTS \"WSO2AM_STAT_DB\""

    log_info "[Postgres] Creating databases"
    psql -U &CF_DB_USERNAME -h &CF_DB_HOST -p &CF_DB_PORT -d postgres -c "CREATE DATABASE \"WSO2AM_COMMON_DB\""
    psql -U &CF_DB_USERNAME -h &CF_DB_HOST -p &CF_DB_PORT -d postgres -c "CREATE DATABASE \"WSO2AM_APIMGT_DB\""
    psql -U &CF_DB_USERNAME -h &CF_DB_HOST -p &CF_DB_PORT -d postgres -c "CREATE DATABASE \"WSO2AM_STAT_DB\""

    log_info "[Postgres] Provisioning database WSO2AM_APIMGT_DB"
    psql -U &CF_DB_USERNAME -h &CF_DB_HOST -p &CF_DB_PORT -d WSO2AM_APIMGT_DB -f $DB_SCRIPT_PATH/apimgt/postgresql.sql
    log_info "[Postgres] Provisioning database WSO2AM_COMMON_DB"
    psql -U &CF_DB_USERNAME -h &CF_DB_HOST -p &CF_DB_PORT -d WSO2AM_COMMON_DB -f $DB_SCRIPT_PATH/postgresql.sql

elif [[ $DB_ENGIN =~ "oracle-se" ]]; then
	
    export ORACLE_HOME=/usr/lib/oracle/12.2/client64/
    export PATH=$PATH:/usr/lib/oracle/12.2/client64/bin/
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$ORACLE_HOME/lib:$ORACLE_HOME

    log_info "Oracle DB is selected! Running Oracle scripts for apim $WSO2_PRODUCT_VERSION"
    # Create users to the required DB
    echo "DECLARE USER_EXIST INTEGER;"$'\n'"BEGIN SELECT COUNT(*) INTO USER_EXIST FROM dba_users WHERE username='WSO2AM_APIMGT_DB';"$'\n'"IF (USER_EXIST > 0) THEN EXECUTE IMMEDIATE 'DROP USER WSO2AM_APIMGT_DB CASCADE';"$'\n'"END IF;"$'\n'"END;"$'\n'"/" > apim_oracle_user.sql
    echo "DECLARE USER_EXIST INTEGER;"$'\n'"BEGIN SELECT COUNT(*) INTO USER_EXIST FROM dba_users WHERE username='WSO2AM_COMMON_DB';"$'\n'"IF (USER_EXIST > 0) THEN EXECUTE IMMEDIATE 'DROP USER WSO2AM_COMMON_DB CASCADE';"$'\n'"END IF;"$'\n'"END;"$'\n'"/" >> apim_oracle_user.sql
    echo "DECLARE USER_EXIST INTEGER;"$'\n'"BEGIN SELECT COUNT(*) INTO USER_EXIST FROM dba_users WHERE username='WSO2AM_STAT_DB';"$'\n'"IF (USER_EXIST > 0) THEN EXECUTE IMMEDIATE 'DROP USER WSO2AM_STAT_DB CASCADE';"$'\n'"END IF;"$'\n'"END;"$'\n'"/" >> apim_oracle_user.sql
    echo "CREATE USER WSO2AM_COMMON_DB IDENTIFIED BY &CF_DB_PASSWORD;"$'\n'"GRANT CONNECT, RESOURCE, DBA TO WSO2AM_COMMON_DB;"$'\n'"GRANT UNLIMITED TABLESPACE TO WSO2AM_COMMON_DB;" >> apim_oracle_user.sql
    echo "CREATE USER WSO2AM_APIMGT_DB IDENTIFIED BY &CF_DB_PASSWORD;"$'\n'"GRANT CONNECT, RESOURCE, DBA TO WSO2AM_APIMGT_DB;"$'\n'"GRANT UNLIMITED TABLESPACE TO WSO2AM_APIMGT_DB;" >> apim_oracle_user.sql
    echo "CREATE USER WSO2AM_STAT_DB IDENTIFIED BY &CF_DB_PASSWORD;"$'\n'"GRANT CONNECT, RESOURCE, DBA TO WSO2AM_STAT_DB;"$'\n'"GRANT UNLIMITED TABLESPACE TO WSO2AM_STAT_DB;" >> apim_oracle_user.sql
    echo "ALTER SYSTEM SET open_cursors = 3000 SCOPE=BOTH;">> apim_oracle_user.sql
    # Create the tables
    log_info "[Oracle] Creating Users"
    echo exit | sqlplus64 '&CF_DB_USERNAME/&CF_DB_PASSWORD@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(Host=&CF_DB_HOST)(Port=&CF_DB_PORT))(CONNECT_DATA=(SID=WSO2AMDB)))' @apim_oracle_user.sql
    log_info "[Oracle] Creating Tables"
    echo exit | sqlplus64 'WSO2AM_COMMON_DB/&CF_DB_PASSWORD@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(Host=&CF_DB_HOST)(Port=&CF_DB_PORT))(CONNECT_DATA=(SID=WSO2AMDB)))' @$DB_SCRIPT_PATH/oracle.sql
    echo exit | sqlplus64 'WSO2AM_APIMGT_DB/&CF_DB_PASSWORD@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(Host=&CF_DB_HOST)(Port=&CF_DB_PORT))(CONNECT_DATA=(SID=WSO2AMDB)))' @$DB_SCRIPT_PATH/apimgt/oracle.sql

elif [[ $DB_ENGIN =~ "sqlserver-se" ]]; then
    log_info "SQL Server DB Engine is selected! Running MSSql scripts for apim $WSO2_PRODUCT_VERSION"

    log_info "[SQLServer] Droping Databases if exist"
    sqlcmd -S &CF_DB_HOST -U &CF_DB_USERNAME -P &CF_DB_PASSWORD -Q "DROP DATABASE IF EXISTS WSO2AM_COMMON_DB"
    sqlcmd -S &CF_DB_HOST -U &CF_DB_USERNAME -P &CF_DB_PASSWORD -Q "DROP DATABASE IF EXISTS WSO2AM_APIMGT_DB"

    log_info "[SQLServer] Creating Databases"
    sqlcmd -S &CF_DB_HOST -U &CF_DB_USERNAME -P &CF_DB_PASSWORD -Q "CREATE DATABASE WSO2AM_COMMON_DB"
    sqlcmd -S &CF_DB_HOST -U &CF_DB_USERNAME -P &CF_DB_PASSWORD -Q "CREATE DATABASE WSO2AM_APIMGT_DB"

    log_info "[SQLServer] Provisioning database WSO2AM_APIMGT_DB"
    sqlcmd -S &CF_DB_HOST -U &CF_DB_USERNAME -P &CF_DB_PASSWORD -d WSO2AM_APIMGT_DB -i $DB_SCRIPT_PATH/apimgt/mssql.sql
    log_info "[SQLServer] Provisioning database WSO2AM_COMMON_DB"
    sqlcmd -S &CF_DB_HOST -U &CF_DB_USERNAME -P &CF_DB_PASSWORD -d WSO2AM_COMMON_DB -i $DB_SCRIPT_PATH/mssql.sql
    log_info "[SQLServer] Tuning databases"
    sqlcmd -S &CF_DB_HOST -U &CF_DB_USERNAME -P &CF_DB_PASSWORD -Q "ALTER DATABASE WSO2AM_APIMGT_DB  SET ALLOW_SNAPSHOT_ISOLATION ON"
    sqlcmd -S &CF_DB_HOST -U &CF_DB_USERNAME -P &CF_DB_PASSWORD -Q "ALTER DATABASE WSO2AM_APIMGT_DB SET READ_COMMITTED_SNAPSHOT ON WITH ROLLBACK IMMEDIATE"
    sqlcmd -S &CF_DB_HOST -U &CF_DB_USERNAME -P &CF_DB_PASSWORD -Q "ALTER DATABASE WSO2AM_COMMON_DB  SET ALLOW_SNAPSHOT_ISOLATION ON"
    sqlcmd -S &CF_DB_HOST -U &CF_DB_USERNAME -P &CF_DB_PASSWORD -Q "ALTER DATABASE WSO2AM_COMMON_DB SET READ_COMMITTED_SNAPSHOT ON WITH ROLLBACK IMMEDIATE"

fi
