-- PREREQUISITE: Execute statements in setup.sql

USE DASH_DB.DASH_SCHEMA;
USE WAREHOUSE DASH_WH_S;

-- Audio Files table
create or replace table VOICEMAILS as
select to_file(file_url) audio_file, 
    DATEADD(SECOND, UNIFORM(0, 13046400, RANDOM()),
    TO_TIMESTAMP('2025-01-01 00:00:00')) as created_at,
    UNIFORM(0, 200, RANDOM()) as user_id,
    * from directory(@DASH_DB.DASH_SCHEMA.DASH_AUDIO_FILES);