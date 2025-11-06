-- PREREQUISITE: Execute statements in setup.sql and images.sql
-- This script demonstrates AI_PARSE_DOCUMENT function for extracting text and layout from documents

USE AISQL_DB.AISQL_SCHEMA;
USE WAREHOUSE AISQL_WH;

-- ============================================================================
-- AI_PARSE_DOCUMENT: Extract Text from Images using OCR
-- ============================================================================

-- Example 1: Basic OCR - Extract text from screenshot images
SELECT 
    relative_path,
    user_id,
    AI_PARSE_DOCUMENT(img_file, {'mode': 'OCR'}) as extracted_text,
    created_at
FROM images
WHERE relative_path LIKE 'screenshot%'
LIMIT 5;

-- ============================================================================
-- Example 2: Create a table with parsed documents
-- ============================================================================

CREATE OR REPLACE TABLE parsed_screenshots AS
SELECT 
    relative_path,
    user_id,
    img_file,
    AI_PARSE_DOCUMENT(img_file, {'mode': 'OCR'}) as extracted_text,
    LENGTH(AI_PARSE_DOCUMENT(img_file, {'mode': 'OCR'})) as text_length,
    created_at
FROM images
WHERE relative_path LIKE 'screenshot%';

-- View parsed documents
SELECT 
    relative_path,
    SUBSTR(extracted_text, 1, 200) as text_preview,
    text_length
FROM parsed_screenshots
LIMIT 10;

-- ============================================================================
-- Example 3: Parse documents with LAYOUT mode
-- ============================================================================

-- LAYOUT mode preserves document structure and formatting
CREATE OR REPLACE TABLE parsed_with_layout AS
SELECT 
    relative_path,
    user_id,
    img_file,
    AI_PARSE_DOCUMENT(img_file, {'mode': 'LAYOUT'}) as layout_data,
    created_at
FROM images
WHERE relative_path LIKE 'screenshot%'
LIMIT 10;

-- View layout data
SELECT 
    relative_path,
    SUBSTR(layout_data, 1, 300) as layout_preview
FROM parsed_with_layout
LIMIT 5;

-- ============================================================================
-- Example 4: Extract and analyze error messages from screenshots
-- ============================================================================

CREATE OR REPLACE TABLE screenshot_analysis AS
SELECT 
    relative_path,
    user_id,
    extracted_text,
    AI_EXTRACT(extracted_text, 'What error message or issue is shown in this screenshot?') as error_message,
    AI_EXTRACT(extracted_text, 'What component or feature is affected?') as affected_component,
    AI_SENTIMENT(extracted_text) as text_sentiment,
    created_at
FROM parsed_screenshots;

-- View screenshot analysis
SELECT 
    relative_path,
    SUBSTR(extracted_text, 1, 150) as text_preview,
    error_message,
    affected_component,
    text_sentiment
FROM screenshot_analysis
LIMIT 10;

-- ============================================================================
-- Example 5: Parse all image types (not just screenshots)
-- ============================================================================

CREATE OR REPLACE TABLE all_parsed_images AS
SELECT 
    relative_path,
    user_id,
    img_file,
    AI_PARSE_DOCUMENT(img_file, {'mode': 'OCR'}) as extracted_text,
    CASE 
        WHEN relative_path LIKE 'screenshot%' THEN 'Screenshot'
        WHEN relative_path LIKE '%before%' THEN 'Before Image'
        WHEN relative_path LIKE '%after%' THEN 'After Image'
        WHEN relative_path LIKE '%metrics%' THEN 'Metrics Image'
        ELSE 'Other'
    END as image_type,
    created_at
FROM images;

-- View parsed images by type
SELECT 
    image_type,
    COUNT(*) as image_count,
    AVG(LENGTH(extracted_text)) as avg_text_length
FROM all_parsed_images
GROUP BY image_type
ORDER BY image_count DESC;

-- ============================================================================
-- Example 6: Compare OCR extraction with AI_COMPLETE image understanding
-- ============================================================================

CREATE OR REPLACE TABLE ocr_vs_vision AS
SELECT 
    relative_path,
    user_id,
    AI_PARSE_DOCUMENT(img_file, {'mode': 'OCR'}) as ocr_text,
    AI_COMPLETE('pixtral-large', 
        PROMPT('Describe what you see in this image and extract any visible text.', img_file)) as vision_description,
    created_at
FROM images
WHERE relative_path LIKE 'screenshot%'
LIMIT 10;

-- View comparison
SELECT 
    relative_path,
    SUBSTR(ocr_text, 1, 150) as ocr_preview,
    SUBSTR(vision_description, 1, 150) as vision_preview
FROM ocr_vs_vision
LIMIT 5;

-- ============================================================================
-- Example 7: Search for specific text in parsed documents
-- ============================================================================

-- Find screenshots containing error-related text
SELECT 
    relative_path,
    user_id,
    SUBSTR(extracted_text, 1, 200) as text_preview,
    created_at
FROM parsed_screenshots
WHERE LOWER(extracted_text) LIKE '%error%'
    OR LOWER(extracted_text) LIKE '%failed%'
    OR LOWER(extracted_text) LIKE '%warning%'
    OR LOWER(extracted_text) LIKE '%problem%'
LIMIT 10;

-- ============================================================================
-- Example 8: Extract structured data from parsed documents
-- ============================================================================

CREATE OR REPLACE TABLE structured_screenshot_data AS
SELECT 
    relative_path,
    user_id,
    extracted_text,
    AI_EXTRACT(extracted_text, 'Extract any dates mentioned in the text.') as dates_found,
    AI_EXTRACT(extracted_text, 'Extract any numbers or metrics shown.') as metrics_found,
    AI_EXTRACT(extracted_text, 'Extract any button or link text visible.') as ui_elements,
    AI_EXTRACT(extracted_text, 'What action was the user trying to perform?') as user_action,
    created_at
FROM parsed_screenshots;

-- View structured data
SELECT 
    relative_path,
    SUBSTR(extracted_text, 1, 100) as text_preview,
    dates_found,
    metrics_found,
    ui_elements,
    user_action
FROM structured_screenshot_data
LIMIT 10;

-- ============================================================================
-- Example 9: Create searchable document index
-- ============================================================================

CREATE OR REPLACE TABLE searchable_image_index AS
SELECT 
    relative_path,
    user_id,
    extracted_text,
    AI_EMBED('snowflake-arctic-embed-m-v1.5', extracted_text) as text_embedding,
    SNOWFLAKE.CORTEX.SUMMARIZE(extracted_text) as text_summary,
    created_at
FROM parsed_screenshots
WHERE LENGTH(extracted_text) > 10;

-- Semantic search on parsed documents
WITH query AS (
    SELECT AI_EMBED('snowflake-arctic-embed-m-v1.5', 
        'payment processing error') as query_embedding
)
SELECT 
    s.relative_path,
    SUBSTR(s.extracted_text, 1, 150) as text_preview,
    s.text_summary,
    AI_SIMILARITY(s.text_embedding, q.query_embedding) as relevance_score
FROM searchable_image_index s
CROSS JOIN query q
ORDER BY relevance_score DESC
LIMIT 10;

-- ============================================================================
-- Example 10: Classify parsed documents by content type
-- ============================================================================

CREATE OR REPLACE TABLE classified_screenshots AS
SELECT 
    relative_path,
    user_id,
    extracted_text,
    AI_CLASSIFY(
        PROMPT('Classify the type of screenshot based on this text: {0}', extracted_text),
        ARRAY_CONSTRUCT('Error Message', 'Form/Input', 'Dashboard', 'Settings', 'Payment', 'General UI')
    )['labels'][0] as screenshot_category,
    created_at
FROM parsed_screenshots
WHERE LENGTH(extracted_text) > 20;

-- View classification results
SELECT 
    screenshot_category,
    COUNT(*) as count,
    ARRAY_AGG(relative_path) as screenshots
FROM classified_screenshots
GROUP BY screenshot_category
ORDER BY count DESC;

-- ============================================================================
-- Example 11: Multi-language OCR
-- ============================================================================

-- Parse documents and detect/translate non-English text
CREATE OR REPLACE TABLE multilingual_parsing AS
SELECT 
    relative_path,
    user_id,
    extracted_text as original_text,
    AI_EXTRACT(extracted_text, 'What language is this text in?') as detected_language,
    CASE 
        WHEN AI_EXTRACT(extracted_text, 'Is this text in English? Answer yes or no.') ILIKE '%no%'
        THEN AI_TRANSLATE(extracted_text, 'auto', 'en')
        ELSE extracted_text
    END as english_text,
    created_at
FROM parsed_screenshots
WHERE LENGTH(extracted_text) > 20
LIMIT 10;

-- View multilingual results
SELECT 
    relative_path,
    detected_language,
    SUBSTR(original_text, 1, 100) as original_preview,
    SUBSTR(english_text, 1, 100) as english_preview
FROM multilingual_parsing
LIMIT 5;

-- ============================================================================
-- Example 12: Aggregate insights from parsed documents
-- ============================================================================

-- Get overall summary of issues found in screenshots
SELECT 
    COUNT(*) as total_screenshots,
    COUNT(DISTINCT user_id) as unique_users,
    AI_SUMMARIZE_AGG(extracted_text) as overall_screenshot_insights
FROM parsed_screenshots
WHERE LENGTH(extracted_text) > 20;

-- ============================================================================
-- Example 13: Track document parsing quality
-- ============================================================================

CREATE OR REPLACE TABLE parsing_quality_metrics AS
SELECT 
    relative_path,
    user_id,
    LENGTH(extracted_text) as text_length,
    CASE 
        WHEN LENGTH(extracted_text) = 0 THEN 'No Text'
        WHEN LENGTH(extracted_text) < 50 THEN 'Low'
        WHEN LENGTH(extracted_text) < 200 THEN 'Medium'
        ELSE 'High'
    END as text_density,
    CASE 
        WHEN extracted_text LIKE '%[unreadable]%' OR extracted_text LIKE '%???%' THEN 'Poor'
        WHEN LENGTH(extracted_text) > 100 THEN 'Good'
        ELSE 'Fair'
    END as ocr_quality,
    created_at
FROM parsed_screenshots;

-- View quality metrics
SELECT 
    text_density,
    ocr_quality,
    COUNT(*) as screenshot_count,
    ROUND(AVG(text_length), 0) as avg_text_length
FROM parsing_quality_metrics
GROUP BY text_density, ocr_quality
ORDER BY screenshot_count DESC;

-- ============================================================================
-- Example 14: Create unified view of images and text
-- ============================================================================

CREATE OR REPLACE TABLE unified_image_analysis AS
SELECT 
    i.relative_path,
    i.user_id,
    i.img_file,
    p.extracted_text as ocr_text,
    AI_COMPLETE('pixtral-large', 
        PROMPT('Describe this image in detail, including any visible text, UI elements, and apparent issues.', i.img_file)
    ) as visual_analysis,
    AI_COMPLETE('claude-3-7-sonnet',
        PROMPT('Based on this extracted text from a screenshot, what is the main issue or purpose? Text: {0}', p.extracted_text)
    ) as text_analysis,
    i.created_at
FROM images i
LEFT JOIN parsed_screenshots p ON i.relative_path = p.relative_path
WHERE i.relative_path LIKE 'screenshot%'
LIMIT 10;

-- View unified analysis
SELECT 
    relative_path,
    SUBSTR(ocr_text, 1, 100) as ocr_preview,
    SUBSTR(visual_analysis, 1, 150) as visual_preview,
    SUBSTR(text_analysis, 1, 150) as text_analysis_preview
FROM unified_image_analysis
LIMIT 5;

-- ============================================================================
-- Example 15: Document parsing for compliance and auditing
-- ============================================================================

-- Extract and log all text from images for compliance
CREATE OR REPLACE TABLE compliance_image_log AS
SELECT 
    relative_path,
    user_id,
    extracted_text,
    AI_FILTER(PROMPT('Does this text contain any sensitive information like credit card numbers, SSN, or passwords? {0}', extracted_text)) as contains_sensitive_data,
    AI_EXTRACT(extracted_text, 'List any personally identifiable information (PII) found.') as pii_found,
    created_at,
    CURRENT_TIMESTAMP() as processed_at
FROM parsed_screenshots;

-- View compliance log
SELECT 
    relative_path,
    contains_sensitive_data,
    pii_found,
    created_at
FROM compliance_image_log
WHERE contains_sensitive_data = TRUE OR pii_found IS NOT NULL
LIMIT 10;

