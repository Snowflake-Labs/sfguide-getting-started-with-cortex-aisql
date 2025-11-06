-- PREREQUISITE: Execute statements in setup.sql
-- This script demonstrates SUMMARIZE and AI_SUMMARIZE_AGG functions for text summarization

USE AISQL_DB.AISQL_SCHEMA;
USE WAREHOUSE AISQL_WH;

-- ============================================================================
-- SUMMARIZE: Summarize Individual Text Items
-- ============================================================================

-- Example 1: Basic summarization of customer emails
SELECT 
    ticket_id,
    user_id,
    SUBSTR(content, 1, 200) as original_content_preview,
    SNOWFLAKE.CORTEX.SUMMARIZE(content) as summary,
    created_at
FROM emails
LIMIT 10;

-- ============================================================================
-- Example 2: Create a table with summarized emails
-- ============================================================================

CREATE OR REPLACE TABLE summarized_emails AS
SELECT 
    ticket_id,
    user_id,
    content as original_content,
    SNOWFLAKE.CORTEX.SUMMARIZE(content) as summary,
    LENGTH(content) as original_length,
    LENGTH(SNOWFLAKE.CORTEX.SUMMARIZE(content)) as summary_length,
    ROUND((LENGTH(SNOWFLAKE.CORTEX.SUMMARIZE(content)) * 100.0) / LENGTH(content), 1) as compression_ratio,
    created_at
FROM emails;

-- View summarization efficiency
SELECT 
    ticket_id,
    SUBSTR(original_content, 1, 150) as original_preview,
    summary,
    original_length,
    summary_length,
    compression_ratio || '%' as compression_percentage
FROM summarized_emails
ORDER BY original_length DESC
LIMIT 10;

-- ============================================================================
-- Example 3: Summarize solution center articles
-- ============================================================================

CREATE OR REPLACE TABLE summarized_solutions AS
SELECT 
    article_id,
    title,
    solution as full_solution,
    SNOWFLAKE.CORTEX.SUMMARIZE(solution) as solution_summary,
    tags,
    LENGTH(solution) as original_length,
    LENGTH(SNOWFLAKE.CORTEX.SUMMARIZE(solution)) as summary_length
FROM solution_center_articles;

-- View summarized solutions
SELECT 
    article_id,
    title,
    SUBSTR(full_solution, 1, 150) as full_solution_preview,
    solution_summary,
    tags
FROM summarized_solutions
LIMIT 10;

-- ============================================================================
-- AI_SUMMARIZE_AGG: Aggregate Summaries Across Multiple Rows
-- ============================================================================

-- Example 4: Summarize all tickets from a specific user
SELECT 
    user_id,
    COUNT(*) as ticket_count,
    AI_SUMMARIZE_AGG(content) as user_issues_summary
FROM emails
GROUP BY user_id
HAVING COUNT(*) >= 2
ORDER BY ticket_count DESC
LIMIT 10;

-- ============================================================================
-- Example 5: Daily summary of all support tickets
-- ============================================================================

CREATE OR REPLACE TABLE daily_ticket_summaries AS
SELECT 
    DATE_TRUNC('day', created_at) as date,
    COUNT(*) as ticket_count,
    COUNT(DISTINCT user_id) as unique_users,
    AI_SUMMARIZE_AGG(content) as daily_summary
FROM emails
GROUP BY DATE_TRUNC('day', created_at)
ORDER BY date DESC;

-- View daily summaries
SELECT 
    TO_VARCHAR(date, 'YYYY-MM-DD') as date,
    ticket_count,
    unique_users,
    daily_summary
FROM daily_ticket_summaries
LIMIT 10;

-- ============================================================================
-- Example 6: Weekly summary reports
-- ============================================================================

CREATE OR REPLACE TABLE weekly_summaries AS
SELECT 
    DATE_TRUNC('week', created_at) as week,
    COUNT(*) as ticket_count,
    COUNT(DISTINCT user_id) as unique_users,
    AI_SUMMARIZE_AGG(content) as weekly_summary
FROM emails
GROUP BY DATE_TRUNC('week', created_at)
ORDER BY week DESC;

-- View weekly summaries
SELECT 
    TO_VARCHAR(week, 'YYYY-MM-DD') as week_starting,
    ticket_count,
    unique_users,
    weekly_summary
FROM weekly_summaries
LIMIT 5;

-- ============================================================================
-- Example 7: Summarize tickets by sentiment category
-- ============================================================================

-- First ensure email_sentiment table exists (from sentiment_analysis.sql)
CREATE OR REPLACE TABLE sentiment_based_summaries AS
SELECT 
    sentiment_category,
    COUNT(*) as ticket_count,
    AI_SUMMARIZE_AGG(content) as category_summary
FROM email_sentiment
GROUP BY sentiment_category;

-- View sentiment-based summaries
SELECT 
    sentiment_category,
    ticket_count,
    category_summary
FROM sentiment_based_summaries
ORDER BY ticket_count DESC;

-- ============================================================================
-- Example 8: Summarize by extracted issue type
-- ============================================================================

WITH categorized_tickets AS (
    SELECT 
        ticket_id,
        content,
        AI_EXTRACT(content, 'Categorize this issue as: billing, technical, event, or general') as issue_category
    FROM emails
)
SELECT 
    issue_category,
    COUNT(*) as ticket_count,
    AI_SUMMARIZE_AGG(content) as category_issues_summary
FROM categorized_tickets
WHERE issue_category IS NOT NULL
GROUP BY issue_category
ORDER BY ticket_count DESC;

-- ============================================================================
-- Example 9: Executive summary - monthly overview
-- ============================================================================

CREATE OR REPLACE TABLE monthly_executive_summary AS
SELECT 
    DATE_TRUNC('month', created_at) as month,
    COUNT(*) as total_tickets,
    COUNT(DISTINCT user_id) as unique_users,
    AI_SUMMARIZE_AGG(content) as executive_summary
FROM emails
GROUP BY DATE_TRUNC('month', created_at)
ORDER BY month DESC;

-- View executive summaries
SELECT 
    TO_VARCHAR(month, 'MMMM YYYY') as month,
    total_tickets,
    unique_users,
    executive_summary
FROM monthly_executive_summary;

-- ============================================================================
-- Example 10: Summarize voicemail transcriptions
-- ============================================================================

-- Summarize individual voicemail transcriptions
CREATE OR REPLACE TABLE summarized_voicemails AS
SELECT 
    relative_path as voicemail_id,
    user_id,
    AI_TRANSCRIBE(audio_file)['text'] as full_transcription,
    SNOWFLAKE.CORTEX.SUMMARIZE(AI_TRANSCRIBE(audio_file)['text']) as transcription_summary,
    created_at
FROM voicemails;

-- View summarized voicemails
SELECT 
    voicemail_id,
    SUBSTR(full_transcription, 1, 150) as transcription_preview,
    transcription_summary
FROM summarized_voicemails
LIMIT 10;

-- ============================================================================
-- Example 11: Aggregate voicemail summaries by day
-- ============================================================================

SELECT 
    DATE_TRUNC('day', created_at) as date,
    COUNT(*) as voicemail_count,
    AI_SUMMARIZE_AGG(AI_TRANSCRIBE(audio_file)['text']) as daily_voicemail_summary
FROM voicemails
GROUP BY DATE_TRUNC('day', created_at)
ORDER BY date DESC
LIMIT 5;

-- ============================================================================
-- Example 12: Compare SUMMARIZE vs AI_SUMMARIZE_AGG
-- ============================================================================

-- Individual summaries
WITH individual_summaries AS (
    SELECT 
        user_id,
        ticket_id,
        SNOWFLAKE.CORTEX.SUMMARIZE(content) as individual_summary
    FROM emails
    WHERE user_id IN (SELECT user_id FROM emails GROUP BY user_id HAVING COUNT(*) >= 3 LIMIT 5)
)
SELECT 
    user_id,
    LISTAGG(individual_summary, ' | ') WITHIN GROUP (ORDER BY ticket_id) as concatenated_individual_summaries
FROM individual_summaries
GROUP BY user_id;

-- Aggregate summary (more coherent)
SELECT 
    user_id,
    COUNT(*) as ticket_count,
    AI_SUMMARIZE_AGG(content) as aggregate_summary
FROM emails
WHERE user_id IN (SELECT user_id FROM emails GROUP BY user_id HAVING COUNT(*) >= 3 LIMIT 5)
GROUP BY user_id;

-- ============================================================================
-- Example 13: Summarize across all data sources (unified view)
-- ============================================================================

-- Create unified content table
CREATE OR REPLACE TABLE unified_content AS
SELECT 
    'Email' as source,
    ticket_id::STRING as identifier,
    user_id,
    content as text_content,
    created_at
FROM emails
UNION ALL
SELECT 
    'Voicemail' as source,
    relative_path as identifier,
    user_id,
    AI_TRANSCRIBE(audio_file)['text'] as text_content,
    created_at
FROM voicemails;

-- Aggregate summary by source
SELECT 
    source,
    COUNT(*) as item_count,
    AI_SUMMARIZE_AGG(text_content) as source_summary
FROM unified_content
GROUP BY source;

-- ============================================================================
-- Example 14: Summarize high-priority tickets
-- ============================================================================

-- Assuming we have prioritized_tickets from sentiment_analysis.sql
SELECT 
    priority,
    COUNT(*) as ticket_count,
    AI_SUMMARIZE_AGG(content_preview) as priority_summary
FROM prioritized_tickets
GROUP BY priority
ORDER BY 
    CASE priority
        WHEN 'Critical' THEN 1
        WHEN 'High' THEN 2
        WHEN 'Medium' THEN 3
        WHEN 'Low' THEN 4
    END;

-- ============================================================================
-- Example 15: Create executive dashboard data
-- ============================================================================

CREATE OR REPLACE TABLE executive_dashboard AS
WITH overall_stats AS (
    SELECT 
        COUNT(*) as total_tickets,
        COUNT(DISTINCT user_id) as total_users,
        AI_SUMMARIZE_AGG(content) as overall_summary
    FROM emails
),
recent_stats AS (
    SELECT 
        COUNT(*) as recent_tickets,
        AI_SUMMARIZE_AGG(content) as recent_summary
    FROM emails
    WHERE created_at >= DATEADD(day, -7, CURRENT_DATE())
),
sentiment_stats AS (
    SELECT 
        ROUND(AVG(sentiment_score), 3) as avg_sentiment,
        COUNT(CASE WHEN sentiment_category = 'Negative' THEN 1 END) as negative_count
    FROM email_sentiment
)
SELECT 
    o.total_tickets,
    o.total_users,
    r.recent_tickets as last_7_days_tickets,
    s.avg_sentiment,
    s.negative_count,
    o.overall_summary,
    r.recent_summary as last_7_days_summary
FROM overall_stats o
CROSS JOIN recent_stats r
CROSS JOIN sentiment_stats s;

-- View executive dashboard
SELECT * FROM executive_dashboard;

-- ============================================================================
-- Example 16: Summarize by user cohorts
-- ============================================================================

WITH user_cohorts AS (
    SELECT 
        user_id,
        content,
        CASE 
            WHEN user_id < 50 THEN 'Cohort A'
            WHEN user_id < 100 THEN 'Cohort B'
            WHEN user_id < 150 THEN 'Cohort C'
            ELSE 'Cohort D'
        END as cohort
    FROM emails
)
SELECT 
    cohort,
    COUNT(*) as ticket_count,
    COUNT(DISTINCT user_id) as users_in_cohort,
    AI_SUMMARIZE_AGG(content) as cohort_summary
FROM user_cohorts
GROUP BY cohort
ORDER BY cohort;

