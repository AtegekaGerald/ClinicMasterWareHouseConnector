
USE ClinicMasterMOH;

-- ENABLE CDC FOR THE ENTIRE DATABASE --------------------------------
EXEC sys.sp_cdc_enable_db;
go

--------------- ENABLE CDC FOR EACH TABLE --------------------------------
DECLARE @schema_name NVARCHAR(128);
DECLARE @table_name NVARCHAR(128);
DECLARE @sql NVARCHAR(MAX);
-- Cursor to loop through all user tables that are not yet CDC-enabled
DECLARE cdc_cursor CURSOR FOR
SELECT s.name, t.name
FROM sys.tables t
INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE t.is_ms_shipped = 0
  AND t.type = 'U'
  AND NOT EXISTS (
      SELECT 1 FROM sys.tables tt
      WHERE tt.object_id = t.object_id
      AND t.is_tracked_by_cdc = 1
  );
OPEN cdc_cursor;
FETCH NEXT FROM cdc_cursor INTO @schema_name, @table_name;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = '
        EXEC sys.sp_cdc_enable_table
            @source_schema = N''' + @schema_name + ''',
            @source_name   = N''' + @table_name + ''',
            @role_name     = NULL,
            @supports_net_changes = 0;
    ';
    PRINT 'Enabling CDC on ' + @schema_name + '.' + @table_name;
    EXEC sp_executesql @sql;
    FETCH NEXT FROM cdc_cursor INTO @schema_name, @table_name;
END
CLOSE cdc_cursor;
DEALLOCATE cdc_cursor;