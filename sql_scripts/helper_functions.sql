-- PREREQUISITE: Execute statements in setup.sql
-- This script demonstrates helper functions: AI_COUNT_TOKENS, PROMPT, TRY_COMPLETE, and TO_FILE

USE AISQL_DB.AISQL_SCHEMA;
USE WAREHOUSE AISQL_WH;

-- ============================================================================
-- AI_COUNT_TOKENS: Count Tokens in Text for Model Input
-- ============================================================================

-- Example 1: Count tokens for email content
SELECT 
    ticket_id,
    user_id,
    SUBSTR(content, 1, 100) as content_preview,
    LENGTH(content) as character_count,
    AI_COUNT_TOKENS('claude-3-7-sonnet', content) as token_count,
    ROUND(AI_COUNT_TOKENS('claude-3-7-sonnet', content) * 1.0 / LENGTH(content), 3) as tokens_per_char
FROM emails
ORDER BY token_count DESC
LIMIT 10;

-- ============================================================================
-- Example 2: Analyze token usage across different models
-- ============================================================================

CREATE OR REPLACE TABLE token_analysis AS
SELECT 
    ticket_id,
    content,
    LENGTH(content) as char_length,
    AI_COUNT_TOKENS('claude-3-7-sonnet', content) as claude_tokens,
    AI_COUNT_TOKENS('llama3.1-8b', content) as llama_tokens,
    AI_COUNT_TOKENS('mistral-large2', content) as mistral_tokens,
    created_at
FROM emails
LIMIT 100;

-- Compare token counts across models
SELECT 
    ticket_id,
    char_length,
    claude_tokens,
    llama_tokens,
    mistral_tokens,
    ROUND(AVG(claude_tokens) OVER (), 0) as avg_claude_tokens
FROM token_analysis
LIMIT 10;

-- ============================================================================
-- Example 3: Cost estimation based on token counts
-- ============================================================================

-- Estimate processing costs (example pricing - adjust based on actual rates)
WITH cost_estimates AS (
    SELECT 
        ticket_id,
        content,
        AI_COUNT_TOKENS('claude-3-7-sonnet', content) as token_count,
        -- Example: $0.003 per 1K input tokens, $0.015 per 1K output tokens
        (AI_COUNT_TOKENS('claude-3-7-sonnet', content) / 1000.0) * 0.003 as estimated_input_cost,
        -- Assume output is ~30% of input
        (AI_COUNT_TOKENS('claude-3-7-sonnet', content) * 0.3 / 1000.0) * 0.015 as estimated_output_cost
    FROM emails
)
SELECT 
    ticket_id,
    token_count,
    ROUND(estimated_input_cost, 6) as input_cost_usd,
    ROUND(estimated_output_cost, 6) as output_cost_usd,
    ROUND(estimated_input_cost + estimated_output_cost, 6) as total_cost_usd
FROM cost_estimates
ORDER BY total_cost_usd DESC
LIMIT 10;

-- ============================================================================
-- Example 4: Filter content by token limits
-- ============================================================================

-- Find emails that fit within a specific token budget
SELECT 
    ticket_id,
    SUBSTR(content, 1, 100) as content_preview,
    AI_COUNT_TOKENS('claude-3-7-sonnet', content) as token_count
FROM emails
WHERE AI_COUNT_TOKENS('claude-3-7-sonnet', content) < 500
ORDER BY token_count DESC
LIMIT 10;

-- Find emails that exceed token limits (may need truncation)
SELECT 
    ticket_id,
    SUBSTR(content, 1, 100) as content_preview,
    AI_COUNT_TOKENS('claude-3-7-sonnet', content) as token_count,
    'Needs truncation' as note
FROM emails
WHERE AI_COUNT_TOKENS('claude-3-7-sonnet', content) > 2000
ORDER BY token_count DESC
LIMIT 10;

-- ============================================================================
-- PROMPT: Build Dynamic Prompts
-- ============================================================================

-- Example 5: Basic PROMPT function usage
SELECT 
    ticket_id,
    content,
    PROMPT('Summarize this customer issue: {0}', content) as prompt_text,
    AI_COMPLETE('claude-3-7-sonnet', PROMPT('Summarize this customer issue: {0}', content)) as response
FROM emails
LIMIT 5;

-- ============================================================================
-- Example 6: Multi-parameter prompts
-- ============================================================================

SELECT 
    ticket_id,
    user_id,
    content,
    PROMPT('User {0} submitted ticket {1}. Issue: {2}. Please provide a response.', 
        user_id, ticket_id, content) as formatted_prompt
FROM emails
LIMIT 5;

-- ============================================================================
-- Example 7: PROMPT with images
-- ============================================================================

SELECT 
    relative_path,
    user_id,
    PROMPT('Analyze this screenshot and describe any issues visible. Image: {0}', img_file) as image_prompt,
    AI_COMPLETE('pixtral-large', 
        PROMPT('Analyze this screenshot and describe any issues visible. Image: {0}', img_file)) as analysis
FROM images
WHERE relative_path LIKE 'screenshot%'
LIMIT 3;

-- ============================================================================
-- Example 8: Complex prompt templates
-- ============================================================================

CREATE OR REPLACE TABLE prompt_templates AS
SELECT 
    'customer_response' as template_name,
    'Dear valued customer, regarding ticket {0}: {1}. We will resolve this within {2} hours.' as template_text
UNION ALL
SELECT 
    'issue_classification',
    'Classify this issue into one of these categories: {0}. Issue description: {1}'
UNION ALL
SELECT 
    'sentiment_analysis',
    'Analyze the sentiment of this message and rate from 1-10: {0}';

-- Use templates with PROMPT
WITH template AS (
    SELECT template_text 
    FROM prompt_templates 
    WHERE template_name = 'issue_classification'
)
SELECT 
    e.ticket_id,
    PROMPT(t.template_text, 
        'billing, technical, event, general',
        e.content) as formatted_prompt
FROM emails e
CROSS JOIN template t
LIMIT 5;

-- ============================================================================
-- TRY_COMPLETE: Error-Safe Completion
-- ============================================================================

-- Example 9: TRY_COMPLETE for handling errors gracefully
SELECT 
    ticket_id,
    content,
    SNOWFLAKE.CORTEX.TRY_COMPLETE('claude-3-7-sonnet', 
        PROMPT('Summarize: {0}', content)) as safe_completion
FROM emails
LIMIT 10;

-- ============================================================================
-- Example 10: Compare COMPLETE vs TRY_COMPLETE
-- ============================================================================

-- TRY_COMPLETE returns NULL on error instead of throwing an exception
CREATE OR REPLACE TABLE completion_comparison AS
SELECT 
    ticket_id,
    content,
    SNOWFLAKE.CORTEX.TRY_COMPLETE('claude-3-7-sonnet', content) as try_complete_result,
    CASE 
        WHEN SNOWFLAKE.CORTEX.TRY_COMPLETE('claude-3-7-sonnet', content) IS NULL 
        THEN 'Failed'
        ELSE 'Success'
    END as completion_status
FROM emails
LIMIT 50;

-- View completion success rate
SELECT 
    completion_status,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage
FROM completion_comparison
GROUP BY completion_status;

-- ============================================================================
-- TO_FILE: Create File References
-- ============================================================================

-- Example 11: TO_FILE with stage files
-- (Already used in images.sql and audio.sql, but demonstrating explicitly)

-- Show file references
SELECT 
    relative_path,
    file_url,
    TO_FILE(file_url) as file_reference,
    TYPEOF(TO_FILE(file_url)) as data_type
FROM directory(@AISQL_IMAGE_FILES)
LIMIT 5;

-- ============================================================================
-- Example 12: Using TO_FILE with AI functions
-- ============================================================================

-- Create file references and use with AI functions
WITH file_refs AS (
    SELECT 
        relative_path,
        file_url,
        TO_FILE(file_url) as img_file_ref
    FROM directory(@AISQL_IMAGE_FILES)
    WHERE relative_path LIKE 'screenshot%'
    LIMIT 3
)
SELECT 
    relative_path,
    AI_COMPLETE('pixtral-large', 
        PROMPT('Describe this image: {0}', img_file_ref)) as description
FROM file_refs;

-- ============================================================================
-- Example 13: Combined helper functions for optimization
-- ============================================================================

-- Optimize prompt length before sending to model
CREATE OR REPLACE TABLE optimized_prompts AS
WITH prompt_prep AS (
    SELECT 
        ticket_id,
        content,
        PROMPT('Please analyze this customer feedback and provide recommendations: {0}', content) as full_prompt,
        AI_COUNT_TOKENS('claude-3-7-sonnet', 
            PROMPT('Please analyze this customer feedback and provide recommendations: {0}', content)) as prompt_tokens
    FROM emails
)
SELECT 
    ticket_id,
    CASE 
        WHEN prompt_tokens > 1000 THEN 
            PROMPT('Analyze this feedback briefly: {0}', SUBSTR(content, 1, 500))
        ELSE full_prompt
    END as optimized_prompt,
    prompt_tokens,
    CASE 
        WHEN prompt_tokens > 1000 THEN 'Truncated'
        ELSE 'Original'
    END as prompt_status
FROM prompt_prep;

-- View optimization results
SELECT 
    prompt_status,
    COUNT(*) as count,
    ROUND(AVG(prompt_tokens), 0) as avg_tokens
FROM optimized_prompts
GROUP BY prompt_status;

-- ============================================================================
-- Example 14: Batch processing with error handling
-- ============================================================================

CREATE OR REPLACE TABLE batch_processing_results AS
SELECT 
    ticket_id,
    user_id,
    content,
    AI_COUNT_TOKENS('claude-3-7-sonnet', content) as token_count,
    CASE 
        WHEN AI_COUNT_TOKENS('claude-3-7-sonnet', content) > 4000 THEN NULL
        ELSE SNOWFLAKE.CORTEX.TRY_COMPLETE('claude-3-7-sonnet', 
            PROMPT('Summarize: {0}', content))
    END as summary,
    CASE 
        WHEN AI_COUNT_TOKENS('claude-3-7-sonnet', content) > 4000 THEN 'Skipped - Too Long'
        WHEN SNOWFLAKE.CORTEX.TRY_COMPLETE('claude-3-7-sonnet', 
            PROMPT('Summarize: {0}', content)) IS NULL THEN 'Failed'
        ELSE 'Success'
    END as processing_status
FROM emails;

-- View batch processing statistics
SELECT 
    processing_status,
    COUNT(*) as count,
    ROUND(AVG(token_count), 0) as avg_tokens,
    ROUND(MIN(token_count), 0) as min_tokens,
    ROUND(MAX(token_count), 0) as max_tokens
FROM batch_processing_results
GROUP BY processing_status
ORDER BY count DESC;

-- ============================================================================
-- Example 15: Token budget management
-- ============================================================================

-- Calculate total token usage for a batch operation
WITH token_budget AS (
    SELECT 
        SUM(AI_COUNT_TOKENS('claude-3-7-sonnet', content)) as total_input_tokens,
        -- Estimate output tokens (typically 20-50% of input)
        SUM(AI_COUNT_TOKENS('claude-3-7-sonnet', content)) * 0.3 as estimated_output_tokens,
        COUNT(*) as total_emails
    FROM emails
)
SELECT 
    total_emails,
    total_input_tokens,
    ROUND(estimated_output_tokens, 0) as estimated_output_tokens,
    ROUND(total_input_tokens + estimated_output_tokens, 0) as total_estimated_tokens,
    ROUND((total_input_tokens + estimated_output_tokens) / 1000000.0, 3) as tokens_in_millions,
    -- Example cost calculation
    ROUND(((total_input_tokens / 1000.0) * 0.003) + 
          ((estimated_output_tokens / 1000.0) * 0.015), 2) as estimated_cost_usd
FROM token_budget;

-- ============================================================================
-- Example 16: Dynamic prompt construction with validation
-- ============================================================================

CREATE OR REPLACE TABLE validated_prompts AS
WITH base_prompts AS (
    SELECT 
        ticket_id,
        content,
        PROMPT('Analyze and categorize this support ticket: {0}', content) as constructed_prompt
    FROM emails
)
SELECT 
    ticket_id,
    constructed_prompt,
    AI_COUNT_TOKENS('claude-3-7-sonnet', constructed_prompt) as prompt_tokens,
    CASE 
        WHEN AI_COUNT_TOKENS('claude-3-7-sonnet', constructed_prompt) < 100 THEN 'Too Short'
        WHEN AI_COUNT_TOKENS('claude-3-7-sonnet', constructed_prompt) > 3000 THEN 'Too Long'
        ELSE 'Valid'
    END as validation_status
FROM base_prompts;

-- View validation results
SELECT 
    validation_status,
    COUNT(*) as count,
    ROUND(AVG(prompt_tokens), 0) as avg_tokens
FROM validated_prompts
GROUP BY validation_status;

-- ============================================================================
-- Example 17: Helper functions for multimodal inputs
-- ============================================================================

-- Count tokens for combined text and image prompts
WITH multimodal_prompts AS (
    SELECT 
        i.relative_path,
        e.ticket_id,
        e.content,
        PROMPT('User reported an issue. Email: {0}. Screenshot: {1}', e.content, i.img_file) as combined_prompt
    FROM images i
    CROSS JOIN emails e
    WHERE i.relative_path LIKE 'screenshot%'
    LIMIT 5
)
SELECT 
    relative_path,
    ticket_id,
    AI_COUNT_TOKENS('pixtral-large', combined_prompt) as multimodal_tokens,
    SUBSTR(combined_prompt, 1, 100) as prompt_preview
FROM multimodal_prompts;

