-- PREREQUISITE: Execute statements in setup.sql
-- This script demonstrates AI_EMBED and AI_SIMILARITY functions for semantic search and similarity matching

USE AISQL_DB.AISQL_SCHEMA;
USE WAREHOUSE AISQL_WH;

-- ============================================================================
-- AI_EMBED: Generate Embeddings for Semantic Search
-- ============================================================================

-- Example 1: Create embeddings for email content
-- This enables semantic search across support tickets
CREATE OR REPLACE TABLE email_embeddings AS
SELECT 
    ticket_id,
    user_id,
    content,
    AI_EMBED('snowflake-arctic-embed-m-v1.5', content) as content_embedding,
    created_at
FROM emails;

-- View sample embeddings
SELECT 
    ticket_id, 
    user_id,
    SUBSTR(content, 1, 100) as content_preview,
    ARRAY_SIZE(content_embedding) as embedding_dimension
FROM email_embeddings
LIMIT 5;

-- ============================================================================
-- Example 2: Create embeddings for images
-- ============================================================================

CREATE OR REPLACE TABLE image_embeddings AS
SELECT 
    relative_path,
    user_id,
    img_file,
    AI_EMBED('snowflake-arctic-embed-m-v1.5', img_file) as image_embedding,
    created_at
FROM images;

-- View sample image embeddings
SELECT 
    relative_path,
    user_id,
    ARRAY_SIZE(image_embedding) as embedding_dimension
FROM image_embeddings
LIMIT 5;

-- ============================================================================
-- AI_SIMILARITY: Find Similar Content
-- ============================================================================

-- Example 3: Find similar support tickets based on content
-- This helps identify duplicate or related issues
WITH ticket_pairs AS (
    SELECT 
        a.ticket_id as ticket_a,
        b.ticket_id as ticket_b,
        SUBSTR(a.content, 1, 80) as content_a_preview,
        SUBSTR(b.content, 1, 80) as content_b_preview,
        AI_SIMILARITY(a.content_embedding, b.content_embedding) as similarity_score
    FROM email_embeddings a
    CROSS JOIN email_embeddings b
    WHERE a.ticket_id < b.ticket_id
)
SELECT 
    ticket_a,
    ticket_b,
    content_a_preview,
    content_b_preview,
    similarity_score
FROM ticket_pairs
ORDER BY similarity_score DESC
LIMIT 10;

-- ============================================================================
-- Example 4: Semantic Search - Find tickets similar to a query
-- ============================================================================

-- Create a query embedding and find similar tickets
WITH query AS (
    SELECT AI_EMBED('snowflake-arctic-embed-m-v1.5', 
        'I need a refund for my cancelled ticket') as query_embedding
)
SELECT 
    e.ticket_id,
    e.user_id,
    SUBSTR(e.content, 1, 150) as content_preview,
    AI_SIMILARITY(e.content_embedding, q.query_embedding) as relevance_score
FROM email_embeddings e
CROSS JOIN query q
ORDER BY relevance_score DESC
LIMIT 10;

-- ============================================================================
-- Example 5: Find similar images (visual similarity)
-- ============================================================================

WITH image_pairs AS (
    SELECT 
        a.relative_path as image_a,
        b.relative_path as image_b,
        AI_SIMILARITY(a.image_embedding, b.image_embedding) as similarity_score
    FROM image_embeddings a
    CROSS JOIN image_embeddings b
    WHERE a.relative_path < b.relative_path
)
SELECT 
    image_a,
    image_b,
    similarity_score
FROM image_pairs
ORDER BY similarity_score DESC
LIMIT 10;

-- ============================================================================
-- Example 6: Clustering - Group similar tickets together
-- ============================================================================

-- Find tickets that are semantically similar to each ticket
-- This can be used for automatic ticket routing or categorization
CREATE OR REPLACE TABLE ticket_clusters AS
WITH similarity_matrix AS (
    SELECT 
        a.ticket_id as source_ticket,
        b.ticket_id as related_ticket,
        AI_SIMILARITY(a.content_embedding, b.content_embedding) as similarity
    FROM email_embeddings a
    CROSS JOIN email_embeddings b
    WHERE a.ticket_id != b.ticket_id
)
SELECT 
    source_ticket,
    related_ticket,
    similarity
FROM similarity_matrix
WHERE similarity > 0.8  -- High similarity threshold
ORDER BY source_ticket, similarity DESC;

-- View clusters
SELECT 
    source_ticket,
    COUNT(*) as similar_ticket_count,
    ARRAY_AGG(related_ticket) as related_tickets
FROM ticket_clusters
GROUP BY source_ticket
HAVING COUNT(*) > 0
ORDER BY similar_ticket_count DESC
LIMIT 10;

-- ============================================================================
-- Example 7: Cross-modal similarity (text to image)
-- ============================================================================

-- Find images that match text descriptions
WITH text_query AS (
    SELECT AI_EMBED('snowflake-arctic-embed-m-v1.5', 
        'error message on screen') as query_embedding
)
SELECT 
    i.relative_path,
    i.user_id,
    AI_SIMILARITY(i.image_embedding, t.query_embedding) as relevance_score
FROM image_embeddings i
CROSS JOIN text_query t
ORDER BY relevance_score DESC
LIMIT 5;

-- ============================================================================
-- Example 8: Recommendation System - Find similar user issues
-- ============================================================================

-- For each user, find other users with similar issues
CREATE OR REPLACE TABLE user_issue_similarity AS
WITH user_embeddings AS (
    SELECT 
        user_id,
        AI_EMBED('snowflake-arctic-embed-m-v1.5', 
            LISTAGG(SUBSTR(content, 1, 200), ' ') WITHIN GROUP (ORDER BY created_at)) as user_profile_embedding
    FROM emails
    GROUP BY user_id
)
SELECT 
    a.user_id as user_a,
    b.user_id as user_b,
    AI_SIMILARITY(a.user_profile_embedding, b.user_profile_embedding) as profile_similarity
FROM user_embeddings a
CROSS JOIN user_embeddings b
WHERE a.user_id < b.user_id
ORDER BY profile_similarity DESC
LIMIT 20;

-- View user similarity results
SELECT * FROM user_issue_similarity LIMIT 10;

