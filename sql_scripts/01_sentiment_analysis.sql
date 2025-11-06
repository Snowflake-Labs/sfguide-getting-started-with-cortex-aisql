-- PREREQUISITE: Execute statements in setup.sql
-- This script demonstrates AI_SENTIMENT function for extracting sentiment from text
-- 
-- AI_SENTIMENT returns an OBJECT with categories array containing sentiment values:
-- - positive, negative, neutral, mixed, or unknown
-- See: https://docs.snowflake.com/en/sql-reference/functions/ai_sentiment

USE AISQL_DB.AISQL_SCHEMA;
USE WAREHOUSE AISQL_WH;

-- ============================================================================
-- AI_SENTIMENT: Extract Sentiment from Text
-- ============================================================================

-- Example 1: Basic sentiment analysis on customer emails
-- AI_SENTIMENT returns an OBJECT with overall sentiment in categories[0]
SELECT 
    ticket_id,
    user_id,
    SUBSTR(content, 1, 150) as content_preview,
    AI_SENTIMENT(content) as sentiment_result,
    AI_SENTIMENT(content)['categories'][0]['sentiment']::STRING as overall_sentiment,
    created_at
FROM emails
ORDER BY created_at DESC
LIMIT 20;

-- ============================================================================
-- Example 2: Create a comprehensive sentiment table
-- ============================================================================

CREATE OR REPLACE TABLE email_sentiment AS
SELECT 
    ticket_id,
    user_id,
    content,
    AI_SENTIMENT(content) as sentiment_result,
    AI_SENTIMENT(content)['categories'][0]['sentiment']::STRING as overall_sentiment,
    created_at
FROM emails;

-- View sentiment distribution
SELECT 
    overall_sentiment,
    COUNT(*) as ticket_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage
FROM email_sentiment
GROUP BY overall_sentiment
ORDER BY ticket_count DESC;

-- ============================================================================
-- Example 3: Sentiment analysis on transcribed voicemails
-- ============================================================================

-- First, ensure voicemails table exists (from audio.sql)
-- Then analyze sentiment of transcribed audio

CREATE OR REPLACE TABLE voicemail_sentiment AS
SELECT 
    relative_path as voicemail_id,
    user_id,
    AI_TRANSCRIBE(audio_file)['text'] as transcribed_text,
    AI_SENTIMENT(AI_TRANSCRIBE(audio_file)['text']) as sentiment_result,
    AI_SENTIMENT(AI_TRANSCRIBE(audio_file)['text'])['categories'][0]['sentiment']::STRING as overall_sentiment,
    created_at
FROM voicemails;

-- View voicemail sentiment
SELECT 
    voicemail_id,
    SUBSTR(transcribed_text, 1, 100) as text_preview,
    overall_sentiment
FROM voicemail_sentiment
ORDER BY created_at DESC
LIMIT 10;

-- ============================================================================
-- Example 4: Compare sentiment across all data sources
-- ============================================================================

CREATE OR REPLACE TABLE unified_sentiment AS
SELECT 
    'Email' as source,
    ticket_id::STRING as identifier,
    user_id,
    content as text_content,
    overall_sentiment,
    created_at
FROM email_sentiment
UNION ALL
SELECT 
    'Voicemail' as source,
    voicemail_id as identifier,
    user_id,
    transcribed_text as text_content,
    overall_sentiment,
    created_at
FROM voicemail_sentiment;

-- Aggregate sentiment by source
SELECT 
    source,
    COUNT(*) as total_items,
    COUNT(CASE WHEN overall_sentiment = 'positive' THEN 1 END) as positive_count,
    COUNT(CASE WHEN overall_sentiment = 'neutral' THEN 1 END) as neutral_count,
    COUNT(CASE WHEN overall_sentiment = 'negative' THEN 1 END) as negative_count,
    COUNT(CASE WHEN overall_sentiment = 'mixed' THEN 1 END) as mixed_count
FROM unified_sentiment
GROUP BY source;

-- ============================================================================
-- Example 5: Sentiment trends over time
-- ============================================================================

SELECT 
    DATE_TRUNC('day', created_at) as date,
    source,
    overall_sentiment,
    COUNT(*) as daily_count
FROM unified_sentiment
GROUP BY DATE_TRUNC('day', created_at), source, overall_sentiment
ORDER BY date DESC, source, overall_sentiment;

-- ============================================================================
-- Example 6: Identify users with consistently negative sentiment
-- ============================================================================

SELECT 
    user_id,
    COUNT(*) as total_interactions,
    COUNT(CASE WHEN overall_sentiment = 'negative' THEN 1 END) as negative_count,
    COUNT(CASE WHEN overall_sentiment = 'positive' THEN 1 END) as positive_count,
    ROUND(COUNT(CASE WHEN overall_sentiment = 'negative' THEN 1 END) * 100.0 / COUNT(*), 1) as negative_percentage
FROM unified_sentiment
GROUP BY user_id
HAVING COUNT(*) >= 2 AND COUNT(CASE WHEN overall_sentiment = 'negative' THEN 1 END) > COUNT(CASE WHEN overall_sentiment = 'positive' THEN 1 END)
ORDER BY negative_percentage DESC
LIMIT 20;

-- ============================================================================
-- Example 7: Sentiment with custom categories (aspects)
-- ============================================================================

-- AI_SENTIMENT can analyze sentiment for specific categories/aspects
SELECT 
    ticket_id,
    SUBSTR(content, 1, 100) as content_preview,
    AI_SENTIMENT(content, ARRAY_CONSTRUCT('cost', 'quality', 'service')) as detailed_sentiment
FROM emails
LIMIT 10;

-- ============================================================================
-- Example 8: Filter by sentiment
-- ============================================================================

-- Find all negative feedback
SELECT 
    ticket_id,
    user_id,
    SUBSTR(content, 1, 200) as content_preview,
    overall_sentiment
FROM email_sentiment
WHERE overall_sentiment = 'negative'
ORDER BY created_at DESC
LIMIT 10;

-- Find all positive feedback
SELECT 
    ticket_id,
    user_id,
    SUBSTR(content, 1, 200) as content_preview,
    overall_sentiment
FROM email_sentiment
WHERE overall_sentiment = 'positive'
ORDER BY created_at DESC
LIMIT 10;

-- ============================================================================
-- Example 9: Weekly sentiment report
-- ============================================================================

SELECT 
    DATE_TRUNC('week', created_at) as week,
    COUNT(*) as total_interactions,
    COUNT(CASE WHEN overall_sentiment = 'positive' THEN 1 END) as positive_count,
    COUNT(CASE WHEN overall_sentiment = 'neutral' THEN 1 END) as neutral_count,
    COUNT(CASE WHEN overall_sentiment = 'negative' THEN 1 END) as negative_count,
    COUNT(CASE WHEN overall_sentiment = 'mixed' THEN 1 END) as mixed_count,
    ROUND(COUNT(CASE WHEN overall_sentiment = 'negative' THEN 1 END) * 100.0 / COUNT(*), 1) as negative_percentage
FROM unified_sentiment
GROUP BY DATE_TRUNC('week', created_at)
ORDER BY week DESC;

-- ============================================================================
-- Example 10: Sentiment-based prioritization
-- ============================================================================

-- Create a priority score based on sentiment
CREATE OR REPLACE TABLE prioritized_tickets AS
SELECT 
    ticket_id,
    user_id,
    SUBSTR(content, 1, 150) as content_preview,
    overall_sentiment,
    CASE 
        WHEN overall_sentiment = 'negative' THEN 'High'
        WHEN overall_sentiment = 'mixed' THEN 'Medium'
        WHEN overall_sentiment = 'neutral' THEN 'Medium'
        WHEN overall_sentiment = 'positive' THEN 'Low'
        ELSE 'Low'
    END as priority,
    created_at
FROM email_sentiment;

-- View priority distribution
SELECT 
    priority,
    overall_sentiment,
    COUNT(*) as ticket_count
FROM prioritized_tickets
GROUP BY priority, overall_sentiment
ORDER BY 
    CASE priority
        WHEN 'High' THEN 1
        WHEN 'Medium' THEN 2
        WHEN 'Low' THEN 3
    END,
    overall_sentiment;

