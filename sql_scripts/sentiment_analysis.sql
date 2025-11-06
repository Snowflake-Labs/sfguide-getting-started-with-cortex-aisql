-- PREREQUISITE: Execute statements in setup.sql
-- This script demonstrates AI_SENTIMENT function for extracting sentiment scores from text

USE AISQL_DB.AISQL_SCHEMA;
USE WAREHOUSE AISQL_WH;

-- ============================================================================
-- AI_SENTIMENT: Extract Sentiment Scores from Text
-- ============================================================================

-- Example 1: Basic sentiment analysis on customer emails
-- Sentiment scores range from -1 (most negative) to 1 (most positive)
SELECT 
    ticket_id,
    user_id,
    SUBSTR(content, 1, 150) as content_preview,
    AI_SENTIMENT(content) as sentiment_score,
    CASE 
        WHEN AI_SENTIMENT(content) > 0.3 THEN 'Positive'
        WHEN AI_SENTIMENT(content) < -0.3 THEN 'Negative'
        ELSE 'Neutral'
    END as sentiment_category,
    created_at
FROM emails
ORDER BY sentiment_score DESC
LIMIT 20;

-- ============================================================================
-- Example 2: Create a comprehensive sentiment table
-- ============================================================================

CREATE OR REPLACE TABLE email_sentiment AS
SELECT 
    ticket_id,
    user_id,
    content,
    AI_SENTIMENT(content) as sentiment_score,
    CASE 
        WHEN AI_SENTIMENT(content) > 0.3 THEN 'Positive'
        WHEN AI_SENTIMENT(content) < -0.3 THEN 'Negative'
        ELSE 'Neutral'
    END as sentiment_category,
    created_at
FROM emails;

-- View sentiment distribution
SELECT 
    sentiment_category,
    COUNT(*) as ticket_count,
    ROUND(AVG(sentiment_score), 3) as avg_sentiment,
    ROUND(MIN(sentiment_score), 3) as min_sentiment,
    ROUND(MAX(sentiment_score), 3) as max_sentiment
FROM email_sentiment
GROUP BY sentiment_category
ORDER BY avg_sentiment DESC;

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
    AI_SENTIMENT(AI_TRANSCRIBE(audio_file)['text']) as sentiment_score,
    CASE 
        WHEN AI_SENTIMENT(AI_TRANSCRIBE(audio_file)['text']) > 0.3 THEN 'Positive'
        WHEN AI_SENTIMENT(AI_TRANSCRIBE(audio_file)['text']) < -0.3 THEN 'Negative'
        ELSE 'Neutral'
    END as sentiment_category,
    created_at
FROM voicemails;

-- View voicemail sentiment
SELECT 
    voicemail_id,
    SUBSTR(transcribed_text, 1, 100) as text_preview,
    sentiment_score,
    sentiment_category
FROM voicemail_sentiment
ORDER BY sentiment_score
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
    sentiment_score,
    sentiment_category,
    created_at
FROM email_sentiment
UNION ALL
SELECT 
    'Voicemail' as source,
    voicemail_id as identifier,
    user_id,
    transcribed_text as text_content,
    sentiment_score,
    sentiment_category,
    created_at
FROM voicemail_sentiment;

-- Aggregate sentiment by source
SELECT 
    source,
    COUNT(*) as total_items,
    ROUND(AVG(sentiment_score), 3) as avg_sentiment,
    COUNT(CASE WHEN sentiment_category = 'Positive' THEN 1 END) as positive_count,
    COUNT(CASE WHEN sentiment_category = 'Neutral' THEN 1 END) as neutral_count,
    COUNT(CASE WHEN sentiment_category = 'Negative' THEN 1 END) as negative_count
FROM unified_sentiment
GROUP BY source;

-- ============================================================================
-- Example 5: Sentiment trends over time
-- ============================================================================

SELECT 
    DATE_TRUNC('day', created_at) as date,
    source,
    ROUND(AVG(sentiment_score), 3) as avg_daily_sentiment,
    COUNT(*) as daily_ticket_count
FROM unified_sentiment
GROUP BY DATE_TRUNC('day', created_at), source
ORDER BY date DESC, source;

-- ============================================================================
-- Example 6: Identify users with consistently negative sentiment
-- ============================================================================

SELECT 
    user_id,
    COUNT(*) as total_interactions,
    ROUND(AVG(sentiment_score), 3) as avg_sentiment,
    COUNT(CASE WHEN sentiment_category = 'Negative' THEN 1 END) as negative_count,
    ROUND(COUNT(CASE WHEN sentiment_category = 'Negative' THEN 1 END) * 100.0 / COUNT(*), 1) as negative_percentage
FROM unified_sentiment
GROUP BY user_id
HAVING COUNT(*) >= 2 AND AVG(sentiment_score) < -0.2
ORDER BY avg_sentiment
LIMIT 20;

-- ============================================================================
-- Example 7: Sentiment by issue type (using extraction)
-- ============================================================================

WITH issue_sentiment AS (
    SELECT 
        ticket_id,
        user_id,
        content,
        sentiment_score,
        sentiment_category,
        AI_EXTRACT(content, 'What is the main category of this issue: billing, technical, event, or general inquiry?') as issue_type
    FROM email_sentiment
)
SELECT 
    issue_type,
    COUNT(*) as ticket_count,
    ROUND(AVG(sentiment_score), 3) as avg_sentiment,
    COUNT(CASE WHEN sentiment_category = 'Positive' THEN 1 END) as positive_count,
    COUNT(CASE WHEN sentiment_category = 'Negative' THEN 1 END) as negative_count
FROM issue_sentiment
WHERE issue_type IS NOT NULL
GROUP BY issue_type
ORDER BY avg_sentiment;

-- ============================================================================
-- Example 8: Most negative and most positive feedback
-- ============================================================================

-- Most negative emails
SELECT 
    'Most Negative' as category,
    ticket_id,
    user_id,
    SUBSTR(content, 1, 200) as content_preview,
    sentiment_score
FROM email_sentiment
ORDER BY sentiment_score ASC
LIMIT 5;

-- Most positive emails
SELECT 
    'Most Positive' as category,
    ticket_id,
    user_id,
    SUBSTR(content, 1, 200) as content_preview,
    sentiment_score
FROM email_sentiment
ORDER BY sentiment_score DESC
LIMIT 5;

-- ============================================================================
-- Example 9: Sentiment correlation with response time
-- ============================================================================

-- Analyze if sentiment affects how quickly issues are addressed
WITH response_metrics AS (
    SELECT 
        e.ticket_id,
        e.sentiment_score,
        e.sentiment_category,
        e.created_at,
        -- Simulated response time (in real scenario, join with response table)
        UNIFORM(1, 72, RANDOM()) as response_hours
    FROM email_sentiment e
)
SELECT 
    sentiment_category,
    COUNT(*) as ticket_count,
    ROUND(AVG(response_hours), 1) as avg_response_hours,
    ROUND(MIN(response_hours), 1) as min_response_hours,
    ROUND(MAX(response_hours), 1) as max_response_hours
FROM response_metrics
GROUP BY sentiment_category
ORDER BY avg_response_hours;

-- ============================================================================
-- Example 10: Sentiment analysis on solution center articles
-- ============================================================================

-- Analyze the tone of solution articles
SELECT 
    article_id,
    title,
    SUBSTR(solution, 1, 100) as solution_preview,
    AI_SENTIMENT(solution) as solution_sentiment,
    CASE 
        WHEN AI_SENTIMENT(solution) > 0.2 THEN 'Helpful/Positive'
        WHEN AI_SENTIMENT(solution) < -0.2 THEN 'Concerning'
        ELSE 'Neutral/Professional'
    END as tone,
    tags
FROM solution_center_articles
ORDER BY AI_SENTIMENT(solution) DESC
LIMIT 10;

-- ============================================================================
-- Example 11: Weekly sentiment report
-- ============================================================================

SELECT 
    DATE_TRUNC('week', created_at) as week,
    COUNT(*) as total_interactions,
    ROUND(AVG(sentiment_score), 3) as avg_sentiment,
    COUNT(CASE WHEN sentiment_category = 'Positive' THEN 1 END) as positive_count,
    COUNT(CASE WHEN sentiment_category = 'Neutral' THEN 1 END) as neutral_count,
    COUNT(CASE WHEN sentiment_category = 'Negative' THEN 1 END) as negative_count,
    ROUND(COUNT(CASE WHEN sentiment_category = 'Negative' THEN 1 END) * 100.0 / COUNT(*), 1) as negative_percentage
FROM unified_sentiment
GROUP BY DATE_TRUNC('week', created_at)
ORDER BY week DESC;

-- ============================================================================
-- Example 12: Sentiment-based prioritization
-- ============================================================================

-- Create a priority score combining sentiment and other factors
CREATE OR REPLACE TABLE prioritized_tickets AS
SELECT 
    ticket_id,
    user_id,
    SUBSTR(content, 1, 150) as content_preview,
    sentiment_score,
    sentiment_category,
    CASE 
        WHEN sentiment_score < -0.5 THEN 'Critical'
        WHEN sentiment_score < -0.2 THEN 'High'
        WHEN sentiment_score < 0.2 THEN 'Medium'
        ELSE 'Low'
    END as priority,
    created_at
FROM email_sentiment;

-- View priority distribution
SELECT 
    priority,
    COUNT(*) as ticket_count,
    ROUND(AVG(sentiment_score), 3) as avg_sentiment
FROM prioritized_tickets
GROUP BY priority
ORDER BY 
    CASE priority
        WHEN 'Critical' THEN 1
        WHEN 'High' THEN 2
        WHEN 'Medium' THEN 3
        WHEN 'Low' THEN 4
    END;

