-- PREREQUISITE: Execute statements in setup.sql
-- This script demonstrates Cortex Guard for filtering unsafe and harmful AI responses

USE AISQL_DB.AISQL_SCHEMA;
USE WAREHOUSE AISQL_WH;

-- ============================================================================
-- CORTEX GUARD: Safety Filtering for AI Responses
-- ============================================================================

-- Cortex Guard is an option of AI_COMPLETE that filters potentially unsafe
-- and harmful responses from language models. It uses Meta's Llama Guard 3
-- to evaluate responses before returning them to the application.

-- ============================================================================
-- Example 1: Basic Cortex Guard usage
-- ============================================================================

-- Without Cortex Guard (standard completion)
SELECT 
    'Standard Response' as response_type,
    AI_COMPLETE('llama3.1-8b', 
        'Tell me about customer service best practices') as response;

-- With Cortex Guard enabled
SELECT 
    'Guarded Response' as response_type,
    AI_COMPLETE('llama3.1-8b', 
        'Tell me about customer service best practices',
        {'guard_enable': true}) as response;

-- ============================================================================
-- Example 2: Test Cortex Guard with various prompt types
-- ============================================================================

CREATE OR REPLACE TABLE guard_test_prompts AS
SELECT 'Safe customer inquiry' as prompt_type, 
       'How can I improve customer satisfaction?' as test_prompt
UNION ALL
SELECT 'Technical question', 
       'What are the best practices for data security?'
UNION ALL
SELECT 'Business advice', 
       'How should I handle a difficult customer complaint?'
UNION ALL
SELECT 'General inquiry', 
       'What are common reasons for ticket escalation?';

-- Test with and without guard
CREATE OR REPLACE TABLE guard_comparison AS
SELECT 
    prompt_type,
    test_prompt,
    AI_COMPLETE('llama3.1-8b', test_prompt) as response_without_guard,
    AI_COMPLETE('llama3.1-8b', test_prompt, {'guard_enable': true}) as response_with_guard,
    CASE 
        WHEN AI_COMPLETE('llama3.1-8b', test_prompt, {'guard_enable': true}) IS NULL 
        THEN 'Filtered by Guard'
        ELSE 'Passed Guard'
    END as guard_status
FROM guard_test_prompts;

-- View comparison
SELECT * FROM guard_comparison;

-- ============================================================================
-- Example 3: Apply Cortex Guard to customer email responses
-- ============================================================================

-- Generate responses to customer emails with safety filtering
CREATE OR REPLACE TABLE guarded_email_responses AS
SELECT 
    ticket_id,
    user_id,
    SUBSTR(content, 1, 150) as customer_message,
    AI_COMPLETE('llama3.1-8b', 
        PROMPT('Generate a professional customer service response to this inquiry: {0}', content),
        {'guard_enable': true}) as safe_response,
    CASE 
        WHEN AI_COMPLETE('llama3.1-8b', 
            PROMPT('Generate a professional customer service response to this inquiry: {0}', content),
            {'guard_enable': true}) IS NULL 
        THEN 'Response filtered'
        ELSE 'Response approved'
    END as guard_status,
    created_at
FROM emails
LIMIT 20;

-- View guarded responses
SELECT 
    ticket_id,
    customer_message,
    safe_response,
    guard_status
FROM guarded_email_responses
LIMIT 10;

-- ============================================================================
-- Example 4: Guard status analysis
-- ============================================================================

-- Analyze how many responses pass vs. get filtered
SELECT 
    guard_status,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage
FROM guarded_email_responses
GROUP BY guard_status;

-- ============================================================================
-- Example 5: Cortex Guard with different models
-- ============================================================================

-- Test guard with multiple models
CREATE OR REPLACE TABLE multi_model_guard_test AS
SELECT 
    ticket_id,
    SUBSTR(content, 1, 100) as content_preview,
    AI_COMPLETE('llama3.1-8b', 
        PROMPT('Respond to: {0}', content),
        {'guard_enable': true}) as llama_guarded,
    AI_COMPLETE('llama3.1-70b', 
        PROMPT('Respond to: {0}', content),
        {'guard_enable': true}) as llama_70b_guarded,
    AI_COMPLETE('mistral-large2', 
        PROMPT('Respond to: {0}', content),
        {'guard_enable': true}) as mistral_guarded
FROM emails
LIMIT 10;

-- View multi-model results
SELECT 
    ticket_id,
    content_preview,
    CASE WHEN llama_guarded IS NULL THEN 'Filtered' ELSE 'Passed' END as llama_status,
    CASE WHEN llama_70b_guarded IS NULL THEN 'Filtered' ELSE 'Passed' END as llama_70b_status,
    CASE WHEN mistral_guarded IS NULL THEN 'Filtered' ELSE 'Passed' END as mistral_status
FROM multi_model_guard_test;

-- ============================================================================
-- Example 6: Cortex Guard for content moderation
-- ============================================================================

-- Use guard to moderate user-generated content
CREATE OR REPLACE TABLE moderated_content AS
SELECT 
    ticket_id,
    user_id,
    content as original_content,
    AI_COMPLETE('llama3.1-8b',
        PROMPT('Analyze if this content is appropriate for a public forum: {0}', content),
        {'guard_enable': true}) as moderation_analysis,
    CASE 
        WHEN AI_COMPLETE('llama3.1-8b',
            PROMPT('Analyze if this content is appropriate for a public forum: {0}', content),
            {'guard_enable': true}) IS NULL 
        THEN 'Content flagged'
        ELSE 'Content approved'
    END as moderation_status
FROM emails
LIMIT 50;

-- View moderation results
SELECT 
    moderation_status,
    COUNT(*) as count
FROM moderated_content
GROUP BY moderation_status;

-- ============================================================================
-- Example 7: Cortex Guard with summarization
-- ============================================================================

-- Generate safe summaries of customer feedback
CREATE OR REPLACE TABLE safe_summaries AS
SELECT 
    ticket_id,
    content,
    AI_COMPLETE('llama3.1-8b',
        PROMPT('Summarize this customer feedback in a professional manner: {0}', content),
        {'guard_enable': true}) as safe_summary,
    CASE 
        WHEN AI_COMPLETE('llama3.1-8b',
            PROMPT('Summarize this customer feedback in a professional manner: {0}', content),
            {'guard_enable': true}) IS NULL 
        THEN 'Summary filtered'
        ELSE 'Summary generated'
    END as summary_status
FROM emails
LIMIT 30;

-- View safe summaries
SELECT 
    ticket_id,
    SUBSTR(content, 1, 100) as original_preview,
    SUBSTR(safe_summary, 1, 150) as summary_preview,
    summary_status
FROM safe_summaries
WHERE summary_status = 'Summary generated'
LIMIT 10;

-- ============================================================================
-- Example 8: Fallback handling for filtered responses
-- ============================================================================

-- Implement fallback when guard filters a response
CREATE OR REPLACE TABLE responses_with_fallback AS
SELECT 
    ticket_id,
    content,
    AI_COMPLETE('llama3.1-8b',
        PROMPT('Provide a helpful response to: {0}', content),
        {'guard_enable': true}) as primary_response,
    CASE 
        WHEN AI_COMPLETE('llama3.1-8b',
            PROMPT('Provide a helpful response to: {0}', content),
            {'guard_enable': true}) IS NULL 
        THEN 'Thank you for your message. A customer service representative will review your inquiry and respond shortly.'
        ELSE AI_COMPLETE('llama3.1-8b',
            PROMPT('Provide a helpful response to: {0}', content),
            {'guard_enable': true})
    END as final_response
FROM emails
LIMIT 20;

-- View responses with fallback
SELECT 
    ticket_id,
    SUBSTR(content, 1, 100) as customer_message,
    SUBSTR(final_response, 1, 150) as response_preview
FROM responses_with_fallback
LIMIT 10;

-- ============================================================================
-- Example 9: Cortex Guard performance metrics
-- ============================================================================

-- Track guard performance over time
CREATE OR REPLACE TABLE guard_performance_log AS
SELECT 
    DATE_TRUNC('day', created_at) as date,
    COUNT(*) as total_requests,
    COUNT(CASE 
        WHEN AI_COMPLETE('llama3.1-8b',
            PROMPT('Respond to: {0}', content),
            {'guard_enable': true}) IS NULL 
        THEN 1 END) as filtered_count,
    COUNT(CASE 
        WHEN AI_COMPLETE('llama3.1-8b',
            PROMPT('Respond to: {0}', content),
            {'guard_enable': true}) IS NOT NULL 
        THEN 1 END) as passed_count,
    ROUND(COUNT(CASE 
        WHEN AI_COMPLETE('llama3.1-8b',
            PROMPT('Respond to: {0}', content),
            {'guard_enable': true}) IS NULL 
        THEN 1 END) * 100.0 / COUNT(*), 2) as filter_rate
FROM emails
GROUP BY DATE_TRUNC('day', created_at)
ORDER BY date DESC;

-- View performance metrics
SELECT * FROM guard_performance_log LIMIT 10;

-- ============================================================================
-- Example 10: Cortex Guard with custom instructions
-- ============================================================================

-- Use guard with specific safety instructions
CREATE OR REPLACE TABLE custom_guarded_responses AS
SELECT 
    ticket_id,
    content,
    AI_COMPLETE('llama3.1-8b',
        PROMPT('You are a professional customer service agent. Respond helpfully and respectfully to: {0}', content),
        {'guard_enable': true, 'max_tokens': 200}) as guarded_response,
    AI_COMPLETE('llama3.1-8b',
        PROMPT('You are a professional customer service agent. Respond helpfully and respectfully to: {0}', content),
        {'max_tokens': 200}) as unguarded_response
FROM emails
LIMIT 15;

-- Compare guarded vs unguarded
SELECT 
    ticket_id,
    SUBSTR(content, 1, 100) as customer_message,
    CASE WHEN guarded_response IS NULL THEN 'Filtered' ELSE 'Approved' END as guard_status,
    SUBSTR(guarded_response, 1, 150) as guarded_preview,
    SUBSTR(unguarded_response, 1, 150) as unguarded_preview
FROM custom_guarded_responses
LIMIT 10;

-- ============================================================================
-- Example 11: Cortex Guard for automated email responses
-- ============================================================================

-- Generate safe automated responses for common inquiries
CREATE OR REPLACE TABLE automated_safe_responses AS
WITH common_topics AS (
    SELECT 
        ticket_id,
        content,
        AI_EXTRACT(content, 'What is the main topic: refund, technical issue, event inquiry, or general question?') as topic
    FROM emails
)
SELECT 
    ticket_id,
    topic,
    content,
    AI_COMPLETE('llama3.1-8b',
        PROMPT('Generate a professional automated response for a {0} inquiry: {1}', topic, content),
        {'guard_enable': true, 'max_tokens': 150}) as automated_response,
    CASE 
        WHEN AI_COMPLETE('llama3.1-8b',
            PROMPT('Generate a professional automated response for a {0} inquiry: {1}', topic, content),
            {'guard_enable': true, 'max_tokens': 150}) IS NULL 
        THEN 'Requires manual review'
        ELSE 'Can be sent automatically'
    END as automation_status
FROM common_topics
WHERE topic IS NOT NULL
LIMIT 20;

-- View automation candidates
SELECT 
    topic,
    automation_status,
    COUNT(*) as count
FROM automated_safe_responses
GROUP BY topic, automation_status
ORDER BY topic, count DESC;

-- ============================================================================
-- Example 12: Cost analysis with Cortex Guard
-- ============================================================================

-- Note: Cortex Guard incurs additional compute charges
-- Calculate estimated costs with guard enabled

WITH guard_usage AS (
    SELECT 
        COUNT(*) as total_calls,
        SUM(AI_COUNT_TOKENS('llama3.1-8b', content)) as total_input_tokens,
        -- Guard adds overhead for safety checking
        SUM(AI_COUNT_TOKENS('llama3.1-8b', content)) * 1.2 as estimated_guard_tokens
    FROM emails
    LIMIT 100
)
SELECT 
    total_calls,
    total_input_tokens,
    ROUND(estimated_guard_tokens, 0) as tokens_with_guard,
    ROUND(estimated_guard_tokens - total_input_tokens, 0) as guard_overhead_tokens,
    ROUND((estimated_guard_tokens - total_input_tokens) / total_input_tokens * 100, 2) as overhead_percentage
FROM guard_usage;

-- ============================================================================
-- Example 13: Cortex Guard best practices implementation
-- ============================================================================

-- Implement a complete safe response system
CREATE OR REPLACE TABLE production_safe_responses AS
SELECT 
    ticket_id,
    user_id,
    content as customer_inquiry,
    -- Step 1: Analyze sentiment
    AI_SENTIMENT(content) as sentiment_score,
    -- Step 2: Generate response with guard
    AI_COMPLETE('llama3.1-8b',
        PROMPT('Generate a professional, empathetic response to this customer inquiry: {0}', content),
        {'guard_enable': true, 'max_tokens': 250, 'temperature': 0.7}) as ai_response,
    -- Step 3: Determine if response is safe
    CASE 
        WHEN AI_COMPLETE('llama3.1-8b',
            PROMPT('Generate a professional, empathetic response to this customer inquiry: {0}', content),
            {'guard_enable': true, 'max_tokens': 250, 'temperature': 0.7}) IS NULL 
        THEN 'MANUAL_REVIEW_REQUIRED'
        WHEN AI_SENTIMENT(content) < -0.5 THEN 'ESCALATE_TO_SUPERVISOR'
        ELSE 'APPROVED_FOR_SENDING'
    END as response_status,
    created_at,
    CURRENT_TIMESTAMP() as processed_at
FROM emails
LIMIT 50;

-- View production response distribution
SELECT 
    response_status,
    COUNT(*) as count,
    ROUND(AVG(sentiment_score), 3) as avg_sentiment
FROM production_safe_responses
GROUP BY response_status
ORDER BY count DESC;

-- View approved responses ready to send
SELECT 
    ticket_id,
    SUBSTR(customer_inquiry, 1, 100) as inquiry_preview,
    SUBSTR(ai_response, 1, 150) as response_preview,
    sentiment_score
FROM production_safe_responses
WHERE response_status = 'APPROVED_FOR_SENDING'
LIMIT 10;

