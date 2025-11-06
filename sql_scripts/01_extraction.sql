-- PREREQUISITE: Execute statements in setup.sql
-- This script demonstrates AI_EXTRACT function for extracting structured information from unstructured text
-- 
-- AI_EXTRACT requires responseFormat as an object, array, or JSON schema
-- See: https://docs.snowflake.com/en/sql-reference/functions/ai_extract

USE AISQL_DB.AISQL_SCHEMA;
USE WAREHOUSE AISQL_WH;

-- ============================================================================
-- AI_EXTRACT: Extract Structured Information from Text
-- ============================================================================

-- Example 1: Extract multiple fields using object format
-- This is the most common and readable format
SELECT 
    ticket_id,
    user_id,
    SUBSTR(content, 1, 150) as content_preview,
    AI_EXTRACT(
        content, 
        {
            'main_issue': 'What is the main issue or problem? Be specific and concise.',
            'product': 'What product or service is mentioned?',
            'action_requested': 'What action does the customer want?'
        }
    ) as extracted_info
FROM emails
LIMIT 10;

-- ============================================================================
-- Example 2: Extract using array format (returns array of answers)
-- ============================================================================

SELECT 
    ticket_id,
    SUBSTR(content, 1, 150) as content_preview,
    AI_EXTRACT(
        content,
        [
            'What is the order ID or order number mentioned?',
            'What date or time is mentioned?',
            'Is this urgent? Answer yes or no.'
        ]
    ) as extracted_array
FROM emails
WHERE content ILIKE '%order%'
LIMIT 10;

-- ============================================================================
-- Example 3: Extract using labeled array format
-- ============================================================================

SELECT 
    ticket_id,
    SUBSTR(content, 1, 150) as content_preview,
    AI_EXTRACT(
        content,
        [
            ['order_id', 'What is the order ID mentioned?'],
            ['urgency', 'Is this urgent?'],
            ['sentiment', 'Is the tone positive or negative?']
        ]
    ) as labeled_extraction
FROM emails
LIMIT 10;

-- ============================================================================
-- Example 4: Create comprehensive extraction table
-- ============================================================================

CREATE OR REPLACE TABLE extracted_ticket_info AS
SELECT 
    ticket_id,
    user_id,
    content,
    AI_EXTRACT(
        content,
        {
            'main_issue': 'What is the main issue? Be concise.',
            'product_mentioned': 'What product or service is mentioned?',
            'customer_request': 'What does the customer want us to do?',
            'urgency': 'Is this urgent? Answer: low, medium, or high.',
            'department': 'Which department should handle this: billing, technical, events, or general?'
        }
    ) as extracted_data,
    created_at
FROM emails;

-- View extracted information
SELECT 
    ticket_id,
    SUBSTR(content, 1, 100) as content_preview,
    extracted_data
FROM extracted_ticket_info
LIMIT 10;

-- ============================================================================
-- Example 5: Extract and parse specific fields
-- ============================================================================

-- Access specific fields from the extracted JSON
SELECT 
    ticket_id,
    extracted_data['main_issue']::STRING as main_issue,
    extracted_data['urgency']::STRING as urgency,
    extracted_data['department']::STRING as department
FROM extracted_ticket_info
WHERE extracted_data IS NOT NULL
LIMIT 20;

-- ============================================================================
-- Example 6: Extract refund-related information
-- ============================================================================

CREATE OR REPLACE TABLE refund_analysis AS
SELECT 
    ticket_id,
    user_id,
    content,
    AI_EXTRACT(
        content,
        {
            'is_refund_request': 'Is this a refund request? Answer yes or no.',
            'amount': 'What dollar amount is mentioned? Return just the number.',
            'reason': 'What is the reason for the refund request?',
            'order_id': 'What order ID is mentioned?'
        }
    ) as refund_info,
    created_at
FROM emails
WHERE content ILIKE '%refund%' OR content ILIKE '%$%' OR content ILIKE '%money back%';

-- View refund requests
SELECT 
    ticket_id,
    SUBSTR(content, 1, 120) as content_preview,
    refund_info['is_refund_request']::STRING as is_refund,
    refund_info['amount']::STRING as amount,
    refund_info['reason']::STRING as reason
FROM refund_analysis
WHERE refund_info['is_refund_request']::STRING = 'yes'
LIMIT 10;

-- ============================================================================
-- Example 7: Extract event information
-- ============================================================================

CREATE OR REPLACE TABLE event_mentions AS
SELECT 
    ticket_id,
    user_id,
    content,
    AI_EXTRACT(
        content,
        {
            'event_name': 'What event, concert, or show is mentioned?',
            'event_date': 'What date is mentioned? Use YYYY-MM-DD format if possible.',
            'venue': 'What venue or location is mentioned?',
            'ticket_count': 'How many tickets are mentioned?'
        }
    ) as event_info,
    created_at
FROM emails
WHERE content ILIKE '%event%' OR content ILIKE '%concert%' OR content ILIKE '%show%';

-- View event information
SELECT 
    ticket_id,
    event_info['event_name']::STRING as event_name,
    event_info['event_date']::STRING as event_date,
    event_info['venue']::STRING as venue
FROM event_mentions
WHERE event_info IS NOT NULL
LIMIT 10;

-- ============================================================================
-- Example 8: Extract technical issues
-- ============================================================================

SELECT 
    ticket_id,
    SUBSTR(content, 1, 150) as content_preview,
    AI_EXTRACT(
        content,
        {
            'error_type': 'What technical error or bug is reported?',
            'platform': 'What platform: mobile app, website, iOS, or Android?',
            'user_action': 'What was the user trying to do when the error occurred?',
            'frequency': 'How often does this happen: once, sometimes, or always?'
        }
    ) as technical_info
FROM emails
WHERE content ILIKE '%error%' OR content ILIKE '%bug%' OR content ILIKE '%not working%'
LIMIT 10;

-- ============================================================================
-- Example 9: Extract contact information
-- ============================================================================

SELECT 
    ticket_id,
    SUBSTR(content, 1, 150) as content_preview,
    AI_EXTRACT(
        content,
        {
            'email': 'Extract any email addresses mentioned.',
            'phone': 'Extract any phone numbers mentioned.',
            'name': 'Extract any person names mentioned.'
        }
    ) as contact_info
FROM emails
LIMIT 10;

-- ============================================================================
-- Example 10: Aggregate extracted data for analytics
-- ============================================================================

-- Analyze urgency distribution
SELECT 
    extracted_data['urgency']::STRING as urgency_level,
    COUNT(*) as ticket_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage
FROM extracted_ticket_info
WHERE extracted_data['urgency'] IS NOT NULL
GROUP BY extracted_data['urgency']::STRING
ORDER BY ticket_count DESC;

-- Analyze by department
SELECT 
    extracted_data['department']::STRING as department,
    COUNT(*) as ticket_count,
    COUNT(DISTINCT user_id) as unique_users
FROM extracted_ticket_info
WHERE extracted_data['department'] IS NOT NULL
GROUP BY extracted_data['department']::STRING
ORDER BY ticket_count DESC;

-- ============================================================================
-- Example 11: Extract from solution center articles
-- ============================================================================

SELECT 
    article_id,
    title,
    SUBSTR(solution, 1, 100) as solution_preview,
    AI_EXTRACT(
        solution,
        {
            'problem': 'What problem does this article solve?',
            'solution_type': 'What type of solution: technical fix, policy explanation, or how-to guide?',
            'difficulty': 'Is this solution simple, moderate, or complex?'
        }
    ) as article_analysis,
    tags
FROM solution_center_articles
LIMIT 10;

-- ============================================================================
-- Example 12: Using JSON schema format for structured extraction
-- ============================================================================

-- Extract structured data with specific types
SELECT 
    ticket_id,
    SUBSTR(content, 1, 100) as content_preview,
    AI_EXTRACT(
        content,
        {
            'schema': {
                'type': 'object',
                'properties': {
                    'customer_name': {
                        'description': 'What is the customer name mentioned?',
                        'type': 'string'
                    },
                    'issues': {
                        'description': 'List all issues mentioned',
                        'type': 'array'
                    },
                    'priority': {
                        'description': 'Priority level: low, medium, or high',
                        'type': 'string'
                    }
                }
            }
        }
    ) as structured_extraction
FROM emails
LIMIT 5;

