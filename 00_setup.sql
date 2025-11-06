-- ============================================================================
-- CORTEX AISQL COMPLETE SETUP SCRIPT
-- ============================================================================
-- This script sets up everything needed to run Cortex AISQL demonstrations
-- 
-- PREREQUISITES:
-- - Snowflake account with Cortex AISQL enabled
-- - ACCOUNTADMIN role (or appropriate permissions)
-- - CORTEX_USER database role access
-- 
-- WHAT THIS SCRIPT DOES:
-- 1. Creates database (AISQL_DB), schema (AISQL_SCHEMA), and warehouse (AISQL_WH)
-- 2. Loads email and solution center data from S3
-- 3. Creates stages for images and audio files
-- 4. Creates IMAGES and VOICEMAILS tables (requires files uploaded to stages)
-- 
-- EXECUTION TIME: ~2-3 minutes
-- 
-- NEXT STEPS AFTER RUNNING THIS SCRIPT:
-- 1. Upload image files: PUT file://data/images/* @AISQL_IMAGE_FILES;
-- 2. Upload audio files: PUT file://data/audio/* @AISQL_AUDIO_FILES;
-- 3. Verify data loaded: SELECT COUNT(*) FROM emails; (should return ~50)
-- 4. Explore demos:
--    - Original demo: 03_cortex_aisql_original.ipynb
--    - Extended demos: notebooks/01-05
--    - SQL scripts: sql_scripts/*.sql
-- ============================================================================

use role accountadmin;

-- Create database, schema, and warehouse
CREATE DATABASE IF NOT EXISTS AISQL_DB;
CREATE SCHEMA IF NOT EXISTS AISQL_SCHEMA;
CREATE WAREHOUSE IF NOT EXISTS AISQL_WH WAREHOUSE_SIZE=SMALL;

USE AISQL_DB.AISQL_SCHEMA;
USE WAREHOUSE AISQL_WH;
  
-- ============================================================================
-- STEP 1: Create CSV file format for data loading
-- ============================================================================
create or replace file format csvformat  
  skip_header = 1  
  field_optionally_enclosed_by = '"'  
  type = 'CSV';  

-- ============================================================================
-- STEP 2: Load Emails data from S3
-- ============================================================================
-- This creates a table with ~50 customer support emails
-- Used by: sentiment analysis, extraction, classification, translation demos
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

-- ============================================================================
-- STEP 3: Load Solution Center Articles from S3
-- ============================================================================
-- This creates a table with ~50 solution articles
-- Used by: semantic joins with AI_FILTER, knowledge base demos

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

-- ============================================================================
-- STEP 4: Create stages for image and audio files
-- ============================================================================
-- These stages will store your media files for multimodal analysis
-- 
-- IMPORTANT: You must manually upload files to these stages:
-- 
-- For images (via SnowSQL):
--   PUT file://data/images/* @AISQL_IMAGE_FILES;
-- 
-- For audio (via SnowSQL):
--   PUT file://data/audio/* @AISQL_AUDIO_FILES;
-- 
-- Or use Snowsight UI:
--   Navigate to: Data → Databases → AISQL_DB → Stages → [Select Stage] → Upload
-- ============================================================================

create or replace stage AISQL_IMAGE_FILES 
  encryption = (TYPE = 'SNOWFLAKE_SSE') 
  directory = (ENABLE = true);

create or replace stage AISQL_AUDIO_FILES 
  encryption = (TYPE = 'SNOWFLAKE_SSE') 
  directory = (ENABLE = true);

-- ============================================================================
-- STEP 5: Enable cross-region inference for Cortex AISQL
-- ============================================================================
-- This allows Cortex AISQL functions to use models across regions
-- Required for: All AI functions (AI_COMPLETE, AI_EMBED, etc.)
ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';

-- ============================================================================
-- STEP 6: Create IMAGES table from uploaded files
-- ============================================================================
-- This creates a table with image file references
-- Used by: AI_COMPLETE (vision), AI_PARSE_DOCUMENT (OCR), AI_EMBED (images)
-- 
-- NOTE: This will only work AFTER you upload files to AISQL_IMAGE_FILES stage
-- If no files uploaded yet, this will create an empty table
-- ============================================================================
create or replace table IMAGES as
select 
    to_file(file_url) as img_file,
    DATEADD(SECOND, UNIFORM(0, 13046400, RANDOM()), TO_TIMESTAMP('2025-01-01 00:00:00')) as created_at,
    UNIFORM(0, 200, RANDOM()) as user_id,
    * 
from directory(@AISQL_DB.AISQL_SCHEMA.AISQL_IMAGE_FILES);

-- ============================================================================
-- STEP 7: Create VOICEMAILS table from uploaded files
-- ============================================================================
-- This creates a table with audio file references
-- Used by: AI_TRANSCRIBE, sentiment analysis on transcriptions
-- 
-- NOTE: This will only work AFTER you upload files to AISQL_AUDIO_FILES stage
-- If no files uploaded yet, this will create an empty table
-- ============================================================================
create or replace table VOICEMAILS as
select 
    to_file(file_url) as audio_file,
    DATEADD(SECOND, UNIFORM(0, 13046400, RANDOM()), TO_TIMESTAMP('2025-01-01 00:00:00')) as created_at,
    UNIFORM(0, 200, RANDOM()) as user_id,
    * 
from directory(@AISQL_DB.AISQL_SCHEMA.AISQL_AUDIO_FILES);

-- ============================================================================
-- SETUP COMPLETE! 
-- ============================================================================
-- 
-- VERIFICATION QUERIES:
-- Run these to verify your setup:
-- 
-- SELECT COUNT(*) FROM emails;                      -- Should return ~50
-- SELECT COUNT(*) FROM solution_center_articles;    -- Should return ~50
-- SELECT COUNT(*) FROM images;                      -- Depends on uploaded files
-- SELECT COUNT(*) FROM voicemails;                  -- Depends on uploaded files
-- 
-- LIST @AISQL_IMAGE_FILES;                         -- Check uploaded images
-- LIST @AISQL_AUDIO_FILES;                         -- Check uploaded audio
-- 
-- ============================================================================
-- NEXT STEPS:
-- ============================================================================
-- 
-- 1. If you haven't uploaded media files yet:
--    PUT file://data/images/* @AISQL_IMAGE_FILES;
--    PUT file://data/audio/* @AISQL_AUDIO_FILES;
--    Then re-run STEP 6 and STEP 7 above to populate tables
-- 
-- 2. Explore the demos:
--    - Original quickstart: 03_cortex_aisql_original.ipynb
--    - Extended demos: notebooks/01_text_analytics.ipynb (and 02-05)
--    - SQL examples: sql_scripts/sentiment_analysis.sql (and others)
-- 
-- 3. Try a quick test:
--    SELECT AI_SENTIMENT(content) FROM emails LIMIT 5;
--    SELECT AI_CLASSIFY('Classify this', ARRAY_CONSTRUCT('A','B','C'));
-- 
-- ============================================================================
-- AVAILABLE AISQL FUNCTIONS (All demonstrated in this repo):
-- ============================================================================
-- 
-- Text Analysis:
--   - AI_COMPLETE        Generate text completions
--   - AI_CLASSIFY        Classify into categories
--   - AI_SENTIMENT       Sentiment analysis (-1 to 1)
--   - AI_EXTRACT         Extract structured information
--   - SUMMARIZE          Summarize text
-- 
-- Embeddings & Search:
--   - AI_EMBED           Generate vector embeddings
--   - AI_SIMILARITY      Calculate similarity scores
-- 
-- Aggregation:
--   - AI_AGG             Aggregate insights across rows
--   - AI_SUMMARIZE_AGG   Aggregate summaries
--   - AI_FILTER          Semantic filtering/joins
-- 
-- Multimodal:
--   - AI_COMPLETE        Analyze images (with vision models)
--   - AI_TRANSCRIBE      Transcribe audio/video
--   - AI_PARSE_DOCUMENT  OCR and layout extraction
-- 
-- Translation:
--   - AI_TRANSLATE       Translate between languages
-- 
-- Helpers:
--   - AI_COUNT_TOKENS    Count tokens for cost estimation
--   - PROMPT             Build dynamic prompts
--   - TRY_COMPLETE       Error-safe completion
--   - TO_FILE            Create file references
-- 
-- Safety:
--   - Cortex Guard       Filter unsafe responses
-- 
-- ============================================================================
-- For full documentation, see README.md
-- For execution guide, see EXECUTION_ORDER.md
-- ============================================================================