delimiter $$
DROP PROCEDURE IF EXISTS sp_purge_crypto$$
CREATE DEFINER = 'app_purge' PROCEDURE sp_purge_crypto(IN p_table VARCHAR(50))
BEGIN
  DECLARE v_purgedate DATE;
  DECLARE v_batch_size INT DEFAULT 10000;
  DECLARE v_batch_nums, v_out, v_rows_del INT;
  
  IF p_table NOT IN ('table2','table2') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Wrong table name to purge. Please, contact DBA team.';
  END IF;
  
  # try to release lock, if procedure is executed by same session several times and any error appeared
  SELECT RELEASE_LOCK('purge_lock') INTO v_out;
  -- check, if procedure is already running with user-level lock
  IF (SELECT IS_FREE_LOCK('purge_lock')) = 1 THEN
    #In case of error lock is released automatically after connection is closed.
    IF (SELECT GET_LOCK('purge_lock',10)) = 1 THEN
  
      SET v_purgedate=DATE(NOW() - interval 30 day);
  
      # get maxid till which rows will be deleted and amount of rows to delete
      SET @stmt_batch_query = CONCAT('SELECT IFNULL(MIN(id),0) INTO @v_maxid FROM ', p_table,' WHERE timestamp >= ''', v_purgedate,'''');
      PREPARE stmt_batch FROM @stmt_batch_query;
      EXECUTE stmt_batch;
      DEALLOCATE PREPARE stmt_batch; 

      # loop for delete batches
      SET @stmt_del_query = CONCAT('DELETE FROM ', p_table,' WHERE id < ', @v_maxid,' LIMIT ', v_batch_size);
      PREPARE stmt_del FROM @stmt_del_query;
      SELECT @stmt_del_query;
      SET v_rows_del = 1;
      WHILE v_rows_del > 0 AND @v_maxid > 0 DO
          EXECUTE stmt_del;
          SET v_rows_del=ROW_COUNT();
          select CONCAT('Rows deleted: ',v_rows_del) AS Rows_Deleted ;
      END WHILE;
      DEALLOCATE PREPARE stmt_del; 
    
      # free lock
      SELECT RELEASE_LOCK('purge_lock') INTO v_out;
    END IF;
  
  ELSE SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Can not get user lock. Is procedure already running?';
  END IF;
END$$

delimiter ;

