-- Run the following statements to create a database, schema, and a table with data loaded from AWS S3.

CREATE DATABASE IF NOT EXISTS DASH_DB;
CREATE SCHEMA IF NOT EXISTS DASH_SCHEMA;
CREATE WAREHOUSE IF NOT EXISTS DASH_WH_S WAREHOUSE_SIZE=SMALL;

USE DASH_DB.DASH_SCHEMA;
USE WAREHOUSE DASH_WH_S;
  
create or replace file format csvformat  
  skip_header = 1  
  field_optionally_enclosed_by = '"'  
  type = 'CSV';  

-- Emails table
create or replace stage emails_data_stage  
  file_format = csvformat  
  url = 's3://sfquickstarts/sfguide_getting_started_with_cortex_aisql/emails/';  
  
create or replace TABLE EMAILS (
	USER_ID NUMBER(38,0),
	TICKET_ID NUMBER(18,0),
	CREATED_AT TIMESTAMP_NTZ(9),
	CONTENT VARCHAR(16777216)
);
  
copy into EMAILS  
  from @emails_data_stage;

-- Solutions Center Articles table

create or replace stage sc_articles_data_stage  
  file_format = csvformat  
  url = 's3://sfquickstarts/sfguide_getting_started_with_cortex_aisql/sc_articles/';  

 create or replace TABLE SOLUTION_CENTER_ARTICLES (
	ARTICLE_ID VARCHAR(16777216),
	TITLE VARCHAR(16777216),
	SOLUTION VARCHAR(16777216),
	TAGS VARCHAR(16777216)
);

copy into SOLUTION_CENTER_ARTICLES  
  from @sc_articles_data_stage;

-- Run the following statement to create a Snowflake managed internal stage to store the sample image files.
 create or replace stage DASH_IMAGE_FILES encryption = (TYPE = 'SNOWFLAKE_SSE') directory = ( ENABLE = true );

-- Run the following statement to create a Snowflake managed internal stage to store the sample audio files.
create or replace stage DASH_AUDIO_FILES encryption = (TYPE = 'SNOWFLAKE_SSE') directory = ( ENABLE = true );

-- Enable cross-region inference
ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';
