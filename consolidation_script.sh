set -o nounset
set -o errexit
set -o pipefail

PASSWORD="XXXXXXXXXX" 
MYSQLSOURCE="/usr/bin/mysql -uapp_xxxx -p${PASSWORD} --quick --force dbname1"
MYSQLDEST="/usr/bin/mysql -uapp_xxxx -p${PASSWORD} -hserver1 dbname2"
SOURCES="server1 server2"
DUMP_DIR="/opt/dumps/entitlements/"
DUMP_TS=$(date +%Y%m%d-%H%M%S)

for source in $SOURCES 
do
  # Get max and min id of event logs to consolidate
  MAXID=$($MYSQLSOURCE -h$source -Bse"SELECT IFNULL((SELECT MAX(id) FROM table1),9223372036854775806)")
  MINID=$($MYSQLSOURCE -h$source -Bse"SELECT IFNULL((SELECT maxid + 1   FROM consolidation ORDER BY consolidation_id DESC LIMIT 1),0)")
  #Check if there are new events to consolidate
  if [ $MAXID -ge $MINID ] && [ $MAXID -ne 9223372036854775806 ]; then
     # Get source host name
     SOURCEHOSTNAME=$($MYSQLSOURCE -h$source -Bse"SELECT @@hostname;")
     # Create consolidation batch id:
     CONSOLIDATIONID=$($MYSQLDEST -Bse"INSERT INTO consolidation_global VALUES (0,'$SOURCEHOSTNAME',0,0,0,null);SELECT LAST_INSERT_ID();")
     # Get events and update record count statistics
     $MYSQLSOURCE -h$source -Bse"SET tx_isolation = 'READ-COMMITTED';
                                 START TRANSACTION;
                                 REPLACE INTO consolidation
                                 SELECT $CONSOLIDATIONID,
                                        min(e.id),
                                        max(e.id),
                                        count(*)
                                   FROM table1 e
                                   LEFT JOIN table3 ed 
                                     ON e.id=ed.permission_event_id
                                  WHERE e.id between $MINID and $MAXID;
     
                                 SELECT 0,
                                        e.unique_token,
                                        e.entry_timestamp,
                                        e.user_domain,
                                        e.user_name,
                                        e.listing_flow_id,
                                        e.permitted_global,
                                        e.application,
                                        e.legal_entity,
                                        e.desk,
                                        e.market,
                                        ed.entitlement_key,
                                        ed.permitted_local,
                                        ed.reason,
                                        ed.additional_fields,
                                        $CONSOLIDATIONID
                                   FROM table1 e
                                   LEFT JOIN table2 ed ON e.id=ed.permission_event_id
                                  WHERE e.id between $MINID and $MAXID;
   
                                  COMMIT;
     " > $DUMP_DIR/logs-$source-$DUMP_TS &&
   
     # Load events into consolidated database
     CONSOLIDATEDROWS=$($MYSQLDEST -Bse"LOAD DATA LOCAL INFILE '$DUMP_DIR/logs-$source-$DUMP_TS' 
                                       INTO TABLE consolidated_tabl1 FIELDS OPTIONALLY ENCLOSED BY '\"';SELECT ROW_COUNT();") 
     gzip $DUMP_DIR/logs-$source-$DUMP_TS
     # Update record count statisticts on consolidated database
     $MYSQLDEST -Bse"UPDATE consolidation_global SET minid=$MINID, maxid=$MAXID,rows_num=$CONSOLIDATEDROWS WHERE consolidation_id=$CONSOLIDATIONID;"
  fi
done
