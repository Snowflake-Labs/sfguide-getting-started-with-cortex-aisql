-- PREREQUISITE: Execute statements in setup.sql

USE AISQL_DB.AISQL_SCHEMA;
USE WAREHOUSE AISQL_WH;

-- Image Files table
create or replace table IMAGES as
select to_file(file_url) img_file, 
    DATEADD(SECOND, UNIFORM(0, 13046400, RANDOM()),
    TO_TIMESTAMP('2025-01-01 00:00:00')) as created_at,
    UNIFORM(0, 200, RANDOM()) as user_id,
    * from directory(@AISQL_DB.AISQL_SCHEMA.AISQL_IMAGE_FILES);
