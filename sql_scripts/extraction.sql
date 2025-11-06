-- PREREQUISITE: Execute statements in setup.sql
-- This script demonstrates AI_EXTRACT function for extracting structured information from unstructured text

USE AISQL_DB.AISQL_SCHEMA;
USE WAREHOUSE AISQL_WH;

-- ============================================================================
-- AI_EXTRACT: Extract Structured Information from Text
-- ============================================================================

-- Example 1: Extract order IDs from customer emails
-- This helps automatically identify and link orders mentioned in support tickets
SELECT 
    ticket_id,
    user_id,
    SUBSTR(content, 1, 150) as content_preview,
    AI_EXTRACT(content, 'What is the order ID or order number mentioned? Return only the order ID.') as order_id
FROM emails
WHERE content ILIKE '%order%'
LIMIT 10;

-- ============================================================================
-- Example 2: Extract dates and times from emails
-- ============================================================================

SELECT 
    ticket_id,
    SUBSTR(content, 1, 150) as content_preview,
    AI_EXTRACT(content, 'What date or time is mentioned in this text? Return in YYYY-MM-DD format if possible.') as mentioned_date
FROM emails
WHERE content ILIKE '%date%' OR content ILIKE '%time%' OR content ILIKE '%when%'
LIMIT 10;

-- ============================================================================
-- Example 3: Extract customer sentiment and specific issues
-- ============================================================================

CREATE OR REPLACE TABLE extracted_issues AS
SELECT 
    ticket_id,
    user_id,
    content,
    AI_EXTRACT(content, 'What is the main issue or problem the customer is reporting? Be specific and concise.') as main_issue,
    AI_EXTRACT(content, 'What product or service is the customer referring to?') as product_mentioned,
    AI_EXTRACT(content, 'Is the customer requesting a refund, exchange, or other action? What specifically?') as customer_request,
    created_at
FROM emails;

-- View extracted issues
SELECT 
    ticket_id,
    SUBSTR(content, 1, 100) as content_preview,
    main_issue,
    product_mentioned,
    customer_request
FROM extracted_issues
LIMIT 10;

-- ============================================================================
-- Example 4: Extract contact information
-- ============================================================================

SELECT 
    ticket_id,
    SUBSTR(content, 1, 150) as content_preview,
    AI_EXTRACT(content, 'Extract any email addresses mentioned in this text.') as mentioned_email,
    AI_EXTRACT(content, 'Extract any phone numbers mentioned in this text.') as mentioned_phone
FROM emails
LIMIT 10;

-- ============================================================================
-- Example 5: Extract music genre preferences from customer feedback
-- ============================================================================

CREATE OR REPLACE TABLE music_preferences AS
SELECT 
    ticket_id,
    user_id,
    content,
    AI_EXTRACT(content, 'What music genres or artists does the customer mention? List them.') as music_preferences,
    AI_EXTRACT(content, 'Is the customer expressing a positive or negative opinion about the music? Explain briefly.') as music_sentiment
FROM emails
WHERE content ILIKE '%music%' OR content ILIKE '%genre%' OR content ILIKE '%artist%'
    OR content ILIKE '%rock%' OR content ILIKE '%jazz%' OR content ILIKE '%pop%'
    OR content ILIKE '%electronic%' OR content ILIKE '%indie%';

-- View music preferences
SELECT 
    ticket_id,
    SUBSTR(content, 1, 120) as content_preview,
    music_preferences,
    music_sentiment
FROM music_preferences
LIMIT 15;

-- ============================================================================
-- Example 6: Extract monetary amounts and refund requests
-- ============================================================================

CREATE OR REPLACE TABLE refund_analysis AS
SELECT 
    ticket_id,
    user_id,
    content,
    AI_EXTRACT(content, 'What is the dollar amount or price mentioned? Return just the number.') as amount_mentioned,
    AI_EXTRACT(content, 'Is this a refund request? Answer yes or no.') as is_refund_request,
    AI_EXTRACT(content, 'What is the reason given for the refund or complaint?') as refund_reason,
    created_at
FROM emails
WHERE content ILIKE '%refund%' OR content ILIKE '%$%' OR content ILIKE '%price%' 
    OR content ILIKE '%charge%' OR content ILIKE '%payment%';

-- View refund analysis
SELECT 
    ticket_id,
    SUBSTR(content, 1, 120) as content_preview,
    amount_mentioned,
    is_refund_request,
    refund_reason
FROM refund_analysis
LIMIT 10;

-- ============================================================================
-- Example 7: Extract technical issues from bug reports
-- ============================================================================

SELECT 
    ticket_id,
    SUBSTR(content, 1, 150) as content_preview,
    AI_EXTRACT(content, 'What technical error or bug is being reported? Be specific.') as technical_issue,
    AI_EXTRACT(content, 'What device or platform is mentioned (mobile app, website, iOS, Android, etc.)?') as platform,
    AI_EXTRACT(content, 'What action was the user trying to perform when the issue occurred?') as user_action
FROM emails
WHERE content ILIKE '%error%' OR content ILIKE '%bug%' OR content ILIKE '%glitch%' 
    OR content ILIKE '%not working%' OR content ILIKE '%problem%'
LIMIT 10;

-- ============================================================================
-- Example 8: Extract event information
-- ============================================================================

CREATE OR REPLACE TABLE event_mentions AS
SELECT 
    ticket_id,
    user_id,
    content,
    AI_EXTRACT(content, 'What event, concert, or show is mentioned?') as event_name,
    AI_EXTRACT(content, 'What is the date or time of the event mentioned?') as event_date,
    AI_EXTRACT(content, 'What venue or location is mentioned?') as venue,
    created_at
FROM emails
WHERE content ILIKE '%event%' OR content ILIKE '%concert%' OR content ILIKE '%show%' 
    OR content ILIKE '%festival%' OR content ILIKE '%venue%';

-- View event mentions
SELECT 
    ticket_id,
    SUBSTR(content, 1, 120) as content_preview,
    event_name,
    event_date,
    venue
FROM event_mentions
LIMIT 10;

-- ============================================================================
-- Example 9: Multi-field extraction for comprehensive ticket analysis
-- ============================================================================

CREATE OR REPLACE TABLE comprehensive_ticket_analysis AS
SELECT 
    ticket_id,
    user_id,
    content,
    AI_EXTRACT(content, 'Summarize the main issue in one sentence.') as issue_summary,
    AI_EXTRACT(content, 'What is the urgency level: low, medium, or high?') as urgency,
    AI_EXTRACT(content, 'What department should handle this: billing, technical support, customer service, or events?') as suggested_department,
    AI_EXTRACT(content, 'Extract any specific request or action the customer wants.') as action_requested,
    AI_EXTRACT(content, 'Is the customer a new user or returning customer? What indicates this?') as customer_type,
    created_at
FROM emails;

-- View comprehensive analysis
SELECT 
    ticket_id,
    issue_summary,
    urgency,
    suggested_department,
    action_requested,
    customer_type
FROM comprehensive_ticket_analysis
LIMIT 10;

-- ============================================================================
-- Example 10: Extract structured data for analytics
-- ============================================================================

-- Aggregate extracted information for business insights
SELECT 
    suggested_department,
    urgency,
    COUNT(*) as ticket_count,
    COUNT(DISTINCT user_id) as unique_users
FROM comprehensive_ticket_analysis
WHERE suggested_department IS NOT NULL
GROUP BY suggested_department, urgency
ORDER BY ticket_count DESC;

-- ============================================================================
-- Example 11: Extract from solution center articles
-- ============================================================================

SELECT 
    article_id,
    title,
    SUBSTR(solution, 1, 100) as solution_preview,
    AI_EXTRACT(solution, 'What is the main problem this article solves?') as problem_addressed,
    AI_EXTRACT(solution, 'What are the key steps to resolve the issue? List them briefly.') as resolution_steps,
    tags
FROM solution_center_articles
LIMIT 10;

