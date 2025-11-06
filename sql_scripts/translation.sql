-- PREREQUISITE: Execute statements in setup.sql
-- This script demonstrates AI_TRANSLATE function for translating text between languages

USE AISQL_DB.AISQL_SCHEMA;
USE WAREHOUSE AISQL_WH;

-- ============================================================================
-- AI_TRANSLATE: Translate Text Between Languages
-- ============================================================================

-- Example 1: Basic translation - English to Spanish
SELECT 
    ticket_id,
    SUBSTR(content, 1, 150) as original_english,
    AI_TRANSLATE(content, 'en', 'es') as spanish_translation
FROM emails
LIMIT 5;

-- ============================================================================
-- Example 2: Multi-language translation for global support
-- ============================================================================

CREATE OR REPLACE TABLE multilingual_emails AS
SELECT 
    ticket_id,
    user_id,
    content as original_english,
    AI_TRANSLATE(content, 'en', 'es') as spanish,
    AI_TRANSLATE(content, 'en', 'fr') as french,
    AI_TRANSLATE(content, 'en', 'de') as german,
    AI_TRANSLATE(content, 'en', 'it') as italian,
    AI_TRANSLATE(content, 'en', 'pt') as portuguese,
    AI_TRANSLATE(content, 'en', 'ja') as japanese,
    AI_TRANSLATE(content, 'en', 'ko') as korean,
    AI_TRANSLATE(content, 'en', 'zh') as chinese,
    created_at
FROM emails
LIMIT 20;

-- View multilingual translations
SELECT 
    ticket_id,
    SUBSTR(original_english, 1, 100) as english_preview,
    SUBSTR(spanish, 1, 100) as spanish_preview,
    SUBSTR(french, 1, 100) as french_preview
FROM multilingual_emails
LIMIT 5;

-- ============================================================================
-- Example 3: Translate solution center articles for international customers
-- ============================================================================

CREATE OR REPLACE TABLE multilingual_solutions AS
SELECT 
    article_id,
    title as title_english,
    solution as solution_english,
    AI_TRANSLATE(title, 'en', 'es') as title_spanish,
    AI_TRANSLATE(solution, 'en', 'es') as solution_spanish,
    AI_TRANSLATE(title, 'en', 'fr') as title_french,
    AI_TRANSLATE(solution, 'en', 'fr') as solution_french,
    AI_TRANSLATE(title, 'en', 'de') as title_german,
    AI_TRANSLATE(solution, 'en', 'de') as solution_german,
    tags
FROM solution_center_articles;

-- View translated solutions
SELECT 
    article_id,
    title_english,
    title_spanish,
    title_french,
    SUBSTR(solution_spanish, 1, 150) as solution_spanish_preview
FROM multilingual_solutions
LIMIT 5;

-- ============================================================================
-- Example 4: Create a language preference system
-- ============================================================================

-- Simulate user language preferences
CREATE OR REPLACE TABLE user_language_preferences AS
SELECT 
    user_id,
    CASE 
        WHEN MOD(user_id, 5) = 0 THEN 'es'
        WHEN MOD(user_id, 5) = 1 THEN 'fr'
        WHEN MOD(user_id, 5) = 2 THEN 'de'
        WHEN MOD(user_id, 5) = 3 THEN 'ja'
        ELSE 'en'
    END as preferred_language,
    CASE 
        WHEN MOD(user_id, 5) = 0 THEN 'Spanish'
        WHEN MOD(user_id, 5) = 1 THEN 'French'
        WHEN MOD(user_id, 5) = 2 THEN 'German'
        WHEN MOD(user_id, 5) = 3 THEN 'Japanese'
        ELSE 'English'
    END as language_name
FROM (SELECT DISTINCT user_id FROM emails);

-- View language preferences
SELECT * FROM user_language_preferences LIMIT 10;

-- ============================================================================
-- Example 5: Translate emails based on user preferences
-- ============================================================================

CREATE OR REPLACE TABLE personalized_translations AS
SELECT 
    e.ticket_id,
    e.user_id,
    e.content as original_content,
    p.preferred_language,
    p.language_name,
    CASE 
        WHEN p.preferred_language = 'en' THEN e.content
        ELSE AI_TRANSLATE(e.content, 'en', p.preferred_language)
    END as translated_content,
    e.created_at
FROM emails e
JOIN user_language_preferences p ON e.user_id = p.user_id;

-- View personalized translations
SELECT 
    ticket_id,
    user_id,
    language_name,
    SUBSTR(original_content, 1, 100) as original_preview,
    SUBSTR(translated_content, 1, 100) as translated_preview
FROM personalized_translations
WHERE preferred_language != 'en'
LIMIT 10;

-- ============================================================================
-- Example 6: Translate aggregated insights
-- ============================================================================

-- Translate monthly summary reports
WITH monthly_summary AS (
    SELECT 
        DATE_TRUNC('month', created_at) as month,
        COUNT(*) as ticket_count,
        'In ' || TO_VARCHAR(DATE_TRUNC('month', created_at), 'MMMM YYYY') || 
        ', we received ' || COUNT(*) || ' support tickets. ' ||
        'The most common issues were related to billing, technical problems, and event inquiries.' as summary_text
    FROM emails
    GROUP BY DATE_TRUNC('month', created_at)
)
SELECT 
    month,
    ticket_count,
    summary_text as english_summary,
    AI_TRANSLATE(summary_text, 'en', 'es') as spanish_summary,
    AI_TRANSLATE(summary_text, 'en', 'fr') as french_summary,
    AI_TRANSLATE(summary_text, 'en', 'de') as german_summary
FROM monthly_summary
ORDER BY month DESC;

-- ============================================================================
-- Example 7: Translate customer feedback for international teams
-- ============================================================================

-- Extract and translate key feedback
WITH feedback_extraction AS (
    SELECT 
        ticket_id,
        content,
        AI_EXTRACT(content, 'What is the main feedback or suggestion from the customer?') as key_feedback
    FROM emails
    WHERE content ILIKE '%feedback%' OR content ILIKE '%suggest%' OR content ILIKE '%recommend%'
)
SELECT 
    ticket_id,
    SUBSTR(content, 1, 100) as original_content,
    key_feedback as feedback_english,
    AI_TRANSLATE(key_feedback, 'en', 'es') as feedback_spanish,
    AI_TRANSLATE(key_feedback, 'en', 'fr') as feedback_french,
    AI_TRANSLATE(key_feedback, 'en', 'ja') as feedback_japanese
FROM feedback_extraction
WHERE key_feedback IS NOT NULL
LIMIT 10;

-- ============================================================================
-- Example 8: Translate voicemail transcriptions
-- ============================================================================

-- Translate transcribed voicemails for international support teams
CREATE OR REPLACE TABLE translated_voicemails AS
SELECT 
    relative_path as voicemail_id,
    user_id,
    AI_TRANSCRIBE(audio_file)['text'] as original_transcription,
    AI_TRANSLATE(AI_TRANSCRIBE(audio_file)['text'], 'en', 'es') as spanish_transcription,
    AI_TRANSLATE(AI_TRANSCRIBE(audio_file)['text'], 'en', 'fr') as french_transcription,
    created_at
FROM voicemails
LIMIT 10;

-- View translated voicemails
SELECT 
    voicemail_id,
    SUBSTR(original_transcription, 1, 100) as original_preview,
    SUBSTR(spanish_transcription, 1, 100) as spanish_preview
FROM translated_voicemails
LIMIT 5;

-- ============================================================================
-- Example 9: Create multilingual FAQ responses
-- ============================================================================

-- Generate common responses in multiple languages
WITH common_responses AS (
    SELECT 'Thank you for contacting us. We have received your request and will respond within 24 hours.' as response_text
    UNION ALL
    SELECT 'Your refund has been processed and will appear in your account within 5-7 business days.'
    UNION ALL
    SELECT 'We apologize for the inconvenience. Our technical team is working to resolve this issue.'
    UNION ALL
    SELECT 'Your ticket has been escalated to our senior support team for immediate attention.'
)
SELECT 
    response_text as english,
    AI_TRANSLATE(response_text, 'en', 'es') as spanish,
    AI_TRANSLATE(response_text, 'en', 'fr') as french,
    AI_TRANSLATE(response_text, 'en', 'de') as german,
    AI_TRANSLATE(response_text, 'en', 'it') as italian,
    AI_TRANSLATE(response_text, 'en', 'pt') as portuguese,
    AI_TRANSLATE(response_text, 'en', 'ja') as japanese
FROM common_responses;

-- ============================================================================
-- Example 10: Translate error messages and notifications
-- ============================================================================

WITH system_messages AS (
    SELECT 'Payment processing failed. Please check your card details and try again.' as message
    UNION ALL
    SELECT 'Your ticket has been confirmed. Check your email for details.'
    UNION ALL
    SELECT 'Event postponed. You can request a refund or transfer to a new date.'
    UNION ALL
    SELECT 'Your account has been successfully updated.'
)
SELECT 
    message as english,
    AI_TRANSLATE(message, 'en', 'es') as spanish,
    AI_TRANSLATE(message, 'en', 'fr') as french,
    AI_TRANSLATE(message, 'en', 'zh') as chinese,
    AI_TRANSLATE(message, 'en', 'ar') as arabic
FROM system_messages;

-- ============================================================================
-- Example 11: Bidirectional translation example
-- ============================================================================

-- Translate to Spanish and back to English to check translation quality
WITH translation_test AS (
    SELECT 
        ticket_id,
        content as original_english,
        AI_TRANSLATE(content, 'en', 'es') as spanish_translation
    FROM emails
    LIMIT 5
)
SELECT 
    ticket_id,
    SUBSTR(original_english, 1, 100) as original,
    SUBSTR(spanish_translation, 1, 100) as spanish,
    SUBSTR(AI_TRANSLATE(spanish_translation, 'es', 'en'), 1, 100) as back_to_english
FROM translation_test;

-- ============================================================================
-- Example 12: Language detection and auto-translation
-- ============================================================================

-- Create a system that detects non-English content and translates it
-- (In this example, we assume all content is English and translate samples)
CREATE OR REPLACE TABLE auto_translated_support AS
SELECT 
    ticket_id,
    user_id,
    content as original_text,
    'en' as detected_language,
    'English' as language_name,
    content as english_translation,  -- Already in English
    created_at
FROM emails
LIMIT 100;

-- View auto-translation results
SELECT 
    ticket_id,
    language_name,
    SUBSTR(original_text, 1, 100) as original_preview,
    SUBSTR(english_translation, 1, 100) as english_preview
FROM auto_translated_support
LIMIT 10;

