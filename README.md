# Getting Started with Cortex AISQL

## Overview

Cortex AISQL reimagines SQL into an AI query language for multimodal data, bringing powerful AI capabilities directly into Snowflake's SQL engine. It enables users to build scalable AI pipelines across text, images, and audio using familiar SQL commands. With native support for multimodal data through a new FILE datatype, Cortex AISQL seamlessly integrates AI operators with traditional SQL primitives like AI_FILTER and AGGREGATE, allowing analysts to process diverse data types more efficiently and cost-effectively while maintaining enterprise-grade security and governance.

This repository provides comprehensive examples and demonstrations of **ALL** Snowflake Cortex AISQL functions.

## Quick Start

### Prerequisites
- Snowflake account with Cortex AISQL enabled
- Appropriate permissions (CORTEX_USER database role)
- Snowflake CLI or Snowsight access

### Setup

1. **Run the setup scripts in order** (numbered for easy execution):
```sql
-- Step 1: Create database, schema, and tables
@00_setup.sql

-- Step 2: Load image files (upload data/images/* to stage first)
@01_images.sql

-- Step 3: Load audio files (upload data/audio/* to stage first)
@02_audio.sql
```

2. **Explore the examples**:
   - Original demo: `03_cortex_aisql_original.ipynb`
   - Extended demos: `notebooks/` (01-05)
   - Individual functions: `sql_scripts/`

## Repository Structure

```
sfguide-getting-started-with-cortex-aisql/
├── README.md                              # This file
├── LICENSE                                # License information
│
├── 00_setup.sql                           # Step 1: Database setup
├── 01_images.sql                          # Step 2: Load images
├── 02_audio.sql                           # Step 3: Load audio
├── 03_cortex_aisql_original.ipynb        # Original quickstart demo
├── snowbooks_extras.py                    # Snowflake Notebooks utility
│
├── sql_scripts/                           # SQL demonstrations by function
│   ├── embedding_similarity.sql           # AI_EMBED, AI_SIMILARITY
│   ├── extraction.sql                     # AI_EXTRACT
│   ├── sentiment_analysis.sql             # AI_SENTIMENT
│   ├── translation.sql                    # AI_TRANSLATE
│   ├── summarization.sql                  # SUMMARIZE, AI_SUMMARIZE_AGG
│   ├── document_parsing.sql               # AI_PARSE_DOCUMENT
│   ├── helper_functions.sql               # AI_COUNT_TOKENS, PROMPT, TRY_COMPLETE, TO_FILE
│   └── cortex_guard.sql                   # Cortex Guard safety filtering
│
├── notebooks/                             # Extended interactive demos
│   ├── 01_text_analytics.ipynb            # Text analysis functions
│   ├── 02_embeddings_similarity.ipynb     # Semantic search & embeddings
│   ├── 03_multimodal_analytics.ipynb      # Images & audio processing
│   ├── 04_aggregation_translation.ipynb   # Aggregation & translation
│   └── 05_advanced_features.ipynb         # Advanced features & helpers
│
└── data/                                  # Sample data files
    ├── emails.csv                         # Customer email data
    ├── solution_center_articles.csv       # Solution articles
    ├── images/                            # Sample images (50+ files)
    └── audio/                             # Sample audio (50+ files)
```

### SQL Scripts (`sql_scripts/`)

| File | Functions | Description |
|------|-----------|-------------|
| `embedding_similarity.sql` | AI_EMBED, AI_SIMILARITY | Generate embeddings and find similar content |
| `extraction.sql` | AI_EXTRACT | Extract structured information from unstructured text |
| `sentiment_analysis.sql` | AI_SENTIMENT | Analyze sentiment scores across data sources |
| `translation.sql` | AI_TRANSLATE | Translate text between multiple languages |
| `summarization.sql` | SUMMARIZE, AI_SUMMARIZE_AGG | Summarize individual texts and aggregate summaries |
| `document_parsing.sql` | AI_PARSE_DOCUMENT | Extract text from images using OCR |
| `helper_functions.sql` | AI_COUNT_TOKENS, PROMPT, TRY_COMPLETE, TO_FILE | Helper functions for optimization and error handling |
| `cortex_guard.sql` | Cortex Guard | Safety filtering for AI responses |

### Jupyter Notebooks (`notebooks/`)

| Notebook | Focus Area | Functions Demonstrated |
|----------|------------|------------------------|
| `01_text_analytics.ipynb` | Text Analysis | AI_COMPLETE, AI_CLASSIFY, AI_SENTIMENT, AI_EXTRACT, SUMMARIZE |
| `02_embeddings_similarity.ipynb` | Semantic Search | AI_EMBED, AI_SIMILARITY, semantic search, clustering |
| `03_multimodal_analytics.ipynb` | Images & Audio | AI_COMPLETE (images), AI_TRANSCRIBE, AI_PARSE_DOCUMENT, TO_FILE |
| `04_aggregation_translation.ipynb` | Aggregation & Translation | AI_AGG, AI_SUMMARIZE_AGG, AI_TRANSLATE, AI_FILTER |
| `05_advanced_features.ipynb` | Advanced Features | Cortex Guard, AI_COUNT_TOKENS, PROMPT, TRY_COMPLETE |

## Complete AISQL Function Reference

### Text Generation & Completion

#### AI_COMPLETE
Generate completions for text prompts or analyze images.

```sql
-- Text completion
SELECT AI_COMPLETE('claude-3-7-sonnet', 'Summarize this email: ' || content) 
FROM emails LIMIT 5;

-- Image analysis
SELECT AI_COMPLETE('pixtral-large', 'Describe this image', img_file) 
FROM images LIMIT 5;

-- With Cortex Guard
SELECT AI_COMPLETE('llama3.1-8b', prompt_text, {'guard_enable': true}) 
FROM prompts;
```

**Use Cases:** Customer service responses, content generation, image analysis, code generation

### Classification & Categorization

#### AI_CLASSIFY
Classify text or images into user-defined categories.

```sql
SELECT 
    content,
    AI_CLASSIFY(
        'Classify this ticket: ' || content,
        ARRAY_CONSTRUCT('Billing', 'Technical', 'Event', 'Refund', 'General')
    )['labels'][0] as category
FROM emails;
```

**Use Cases:** Ticket routing, content moderation, topic classification, multi-label tagging

### Filtering & Semantic Joins

#### AI_FILTER
Filter rows based on natural language conditions.

```sql
-- Filter tickets about refunds
SELECT * FROM emails
WHERE AI_FILTER(PROMPT('Is this about a refund request? {0}', content));

-- Semantic join
SELECT e.content, s.solution
FROM emails e
LEFT JOIN solution_center_articles s
ON AI_FILTER(PROMPT('Does this solution address this issue? Issue: {0}, Solution: {1}', 
    e.content, s.solution));
```

**Use Cases:** Semantic filtering, intelligent joins, conditional processing

### Aggregation & Insights

#### AI_AGG
Aggregate insights across multiple rows with custom prompts.

```sql
SELECT 
    DATE_TRUNC('day', created_at) as date,
    COUNT(*) as ticket_count,
    AI_AGG(content, 'Summarize the main issues reported today') as daily_insights
FROM emails
GROUP BY DATE_TRUNC('day', created_at);
```

**Use Cases:** Daily summaries, trend analysis, aggregated insights

#### AI_SUMMARIZE_AGG
Create coherent summaries across multiple rows.

```sql
SELECT 
    user_id,
    COUNT(*) as ticket_count,
    AI_SUMMARIZE_AGG(content) as user_summary
FROM emails
GROUP BY user_id;
```

**Use Cases:** User behavior summaries, aggregated feedback, executive reports

### Embeddings & Similarity

#### AI_EMBED
Generate vector embeddings for semantic search.

```sql
-- Create embeddings
CREATE TABLE email_embeddings AS
SELECT 
    ticket_id,
    content,
    AI_EMBED('snowflake-arctic-embed-m-v1.5', content) as embedding
FROM emails;
```

**Use Cases:** Semantic search, clustering, recommendation systems, duplicate detection

#### AI_SIMILARITY
Calculate similarity between embeddings.

```sql
-- Find similar tickets
WITH query AS (
    SELECT AI_EMBED('snowflake-arctic-embed-m-v1.5', 'refund request') as query_embedding
)
SELECT 
    e.ticket_id,
    e.content,
    AI_SIMILARITY(e.embedding, q.query_embedding) as similarity_score
FROM email_embeddings e
CROSS JOIN query q
ORDER BY similarity_score DESC
LIMIT 10;
```

**Use Cases:** Similar content discovery, duplicate detection, recommendation engines

### Information Extraction

#### AI_EXTRACT
Extract structured information from unstructured text.

```sql
SELECT 
    ticket_id,
    content,
    AI_EXTRACT(content, 'What is the order ID mentioned?') as order_id,
    AI_EXTRACT(content, 'What is the main issue?') as main_issue,
    AI_EXTRACT(content, 'What does the customer want?') as requested_action
FROM emails;
```

**Use Cases:** Entity extraction, data enrichment, form parsing, metadata extraction

### Sentiment Analysis

#### AI_SENTIMENT
Extract sentiment scores from text (-1 to 1).

```sql
SELECT 
    ticket_id,
    content,
    AI_SENTIMENT(content) as sentiment_score,
    CASE 
        WHEN AI_SENTIMENT(content) > 0.3 THEN 'Positive'
        WHEN AI_SENTIMENT(content) < -0.3 THEN 'Negative'
        ELSE 'Neutral'
    END as sentiment_category
FROM emails;
```

**Use Cases:** Customer satisfaction analysis, feedback monitoring, escalation triggers

### Summarization

#### SUMMARIZE (SNOWFLAKE.CORTEX)
Summarize individual text items.

```sql
SELECT 
    ticket_id,
    content,
    SNOWFLAKE.CORTEX.SUMMARIZE(content) as summary
FROM emails;
```

**Use Cases:** Email summaries, document abstracts, quick previews

### Translation

#### AI_TRANSLATE
Translate text between languages.

```sql
SELECT 
    ticket_id,
    content as english,
    AI_TRANSLATE(content, 'en', 'es') as spanish,
    AI_TRANSLATE(content, 'en', 'fr') as french,
    AI_TRANSLATE(content, 'en', 'de') as german
FROM emails;
```

**Supported Languages:** English, Spanish, French, German, Italian, Portuguese, Japanese, Korean, Chinese, Arabic, and more

**Use Cases:** Multilingual support, content localization, global customer service

### Document Processing

#### AI_TRANSCRIBE
Transcribe audio and video files.

```sql
SELECT 
    relative_path,
    AI_TRANSCRIBE(audio_file)['text'] as transcription,
    AI_TRANSCRIBE(audio_file)['timestamps'] as timestamps
FROM voicemails;
```

**Use Cases:** Voicemail transcription, meeting notes, audio content analysis

#### AI_PARSE_DOCUMENT
Extract text from documents using OCR or layout analysis.

```sql
-- OCR mode
SELECT 
    relative_path,
    AI_PARSE_DOCUMENT(img_file, {'mode': 'OCR'}) as extracted_text
FROM images;

-- Layout mode (preserves structure)
SELECT 
    relative_path,
    AI_PARSE_DOCUMENT(img_file, {'mode': 'LAYOUT'}) as layout_data
FROM images;
```

**Use Cases:** Document digitization, invoice processing, form extraction, screenshot analysis

### Helper Functions

#### AI_COUNT_TOKENS
Count tokens for cost estimation and optimization.

```sql
SELECT 
    ticket_id,
    content,
    AI_COUNT_TOKENS('claude-3-7-sonnet', content) as token_count,
    ROUND((AI_COUNT_TOKENS('claude-3-7-sonnet', content) / 1000.0) * 0.003, 6) as estimated_cost
FROM emails
ORDER BY token_count DESC;
```

**Use Cases:** Cost optimization, prompt sizing, batch planning

#### PROMPT
Build dynamic prompts with parameters.

```sql
SELECT 
    ticket_id,
    AI_COMPLETE('claude-3-7-sonnet',
        PROMPT('User {0} submitted ticket {1}. Issue: {2}', user_id, ticket_id, content)
    ) as response
FROM emails;
```

**Use Cases:** Dynamic prompt construction, parameterized queries, template-based generation

#### TRY_COMPLETE
Error-safe version of COMPLETE (returns NULL on error).

```sql
SELECT 
    ticket_id,
    SNOWFLAKE.CORTEX.TRY_COMPLETE('claude-3-7-sonnet', content) as safe_response,
    CASE 
        WHEN SNOWFLAKE.CORTEX.TRY_COMPLETE('claude-3-7-sonnet', content) IS NULL 
        THEN 'Failed'
        ELSE 'Success'
    END as status
FROM emails;
```

**Use Cases:** Batch processing, error handling, production pipelines

#### TO_FILE
Create file references for use with AI functions.

```sql
SELECT 
    relative_path,
    TO_FILE(file_url) as file_reference,
    AI_COMPLETE('pixtral-large', 'Describe this image', TO_FILE(file_url)) as description
FROM directory(@AISQL_IMAGE_FILES);
```

**Use Cases:** File handling, multimodal processing, stage file access

### Safety & Moderation

#### Cortex Guard
Filter potentially unsafe AI responses using Llama Guard 3.

```sql
SELECT 
    ticket_id,
    AI_COMPLETE('llama3.1-8b', 
        'Generate a response to: ' || content,
        {'guard_enable': true}) as safe_response
FROM emails;
```

**Use Cases:** Content moderation, safe AI responses, compliance filtering

## Use Case Examples

### Customer Support Automation
```sql
-- Comprehensive ticket analysis
SELECT 
    ticket_id,
    user_id,
    SNOWFLAKE.CORTEX.SUMMARIZE(content) as summary,
    AI_SENTIMENT(content) as sentiment,
    AI_CLASSIFY('Classify: ' || content, 
        ARRAY_CONSTRUCT('Billing', 'Technical', 'Event', 'Refund')) as category,
    AI_EXTRACT(content, 'What is the urgency level?') as urgency,
    AI_COMPLETE('claude-3-7-sonnet', 
        'Generate a professional response to: ' || content,
        {'guard_enable': true}) as ai_response
FROM emails;
```

### Semantic Search & Knowledge Base
```sql
-- Build searchable knowledge base
CREATE TABLE knowledge_base AS
SELECT 
    article_id,
    title,
    solution,
    AI_EMBED('snowflake-arctic-embed-m-v1.5', title || ' ' || solution) as embedding
FROM solution_center_articles;

-- Search for relevant articles
WITH query AS (
    SELECT AI_EMBED('snowflake-arctic-embed-m-v1.5', 
        'payment processing failed') as query_embedding
)
SELECT 
    k.article_id,
    k.title,
    AI_SIMILARITY(k.embedding, q.query_embedding) as relevance
FROM knowledge_base k
CROSS JOIN query q
ORDER BY relevance DESC
LIMIT 5;
```

### Multilingual Support
```sql
-- Translate and respond in customer's language
SELECT 
    ticket_id,
    content as original,
    AI_TRANSLATE(content, 'en', 'es') as spanish_translation,
    AI_TRANSLATE(
        AI_COMPLETE('claude-3-7-sonnet', 'Respond to: ' || content),
        'en', 'es'
    ) as spanish_response
FROM emails;
```

### Multimodal Analysis
```sql
-- Analyze tickets across text, images, and audio
CREATE TABLE unified_insights AS
SELECT 'Email' as source, ticket_id, content as text_content,
    AI_SENTIMENT(content) as sentiment
FROM emails
UNION ALL
SELECT 'Voicemail', relative_path, AI_TRANSCRIBE(audio_file)['text'],
    AI_SENTIMENT(AI_TRANSCRIBE(audio_file)['text'])
FROM voicemails
UNION ALL
SELECT 'Screenshot', relative_path, AI_PARSE_DOCUMENT(img_file, {'mode': 'OCR'}),
    AI_SENTIMENT(AI_PARSE_DOCUMENT(img_file, {'mode': 'OCR'}))
FROM images;
```

## Model Selection Guide

### Large Models (Best Quality)
- **claude-3-7-sonnet**: Best for complex reasoning, analysis, and generation
- **claude-3-5-sonnet**: High-quality general-purpose model
- **pixtral-large**: Best for image analysis and vision tasks
- **mistral-large2**: Strong multilingual capabilities

### Medium Models (Balanced)
- **llama3.1-70b**: Good balance of quality and speed
- **mixtral-8x7b**: Efficient mixture-of-experts model

### Small Models (Fast & Cost-Effective)
- **llama3.1-8b**: Fast, cost-effective for simple tasks
- **mistral-7b**: Efficient for basic completions

### Embedding Models
- **snowflake-arctic-embed-m-v1.5**: 768-dimensional embeddings
- **snowflake-arctic-embed-l**: 1024-dimensional embeddings (higher quality)

## Best Practices

### Performance
1. **Use appropriate model sizes** - Don't use large models for simple tasks
2. **Batch processing** - Process multiple rows in single queries
3. **Token management** - Use AI_COUNT_TOKENS to optimize costs
4. **Caching** - Store frequently used embeddings and summaries

### Cost Optimization
1. **Monitor token usage** with AI_COUNT_TOKENS
2. **Use smaller models** when appropriate
3. **Implement caching** for repeated operations
4. **Set token limits** with max_tokens parameter

### Safety & Quality
1. **Enable Cortex Guard** for user-facing applications
2. **Use TRY_COMPLETE** for production pipelines
3. **Validate outputs** with AI_FILTER or business logic
4. **Test with diverse inputs** before production deployment

### Data Management
1. **Create embeddings tables** for frequently searched content
2. **Index on similarity scores** for faster retrieval
3. **Archive processed results** to avoid reprocessing
4. **Use stages** for large media files

## Cost Tracking

Track AISQL function usage and costs:

```sql
-- Query history for AISQL functions
SELECT 
    query_text,
    execution_time,
    credits_used_cloud_services,
    start_time
FROM snowflake.account_usage.query_history
WHERE query_text ILIKE '%AI_%'
    AND start_time >= DATEADD(day, -7, CURRENT_TIMESTAMP())
ORDER BY start_time DESC;
```

## Documentation & Resources

- [Snowflake Cortex AISQL Documentation](https://docs.snowflake.com/en/user-guide/snowflake-cortex/aisql)
- [QuickStart Guide](https://quickstarts.snowflake.com/guide/getting-started-with-cortex-aisql/index.html)
- [Cortex Playground](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-playground)
- [Model Documentation](https://docs.snowflake.com/en/user-guide/snowflake-cortex/llm-functions#label-cortex-llm-models)

## Support & Contribution

For issues, questions, or contributions, please refer to the Snowflake Community or your Snowflake account team.

## Execution Order

For first-time setup, run files in numbered order:

```bash
# 1. Setup database and schema
snowsql -f 00_setup.sql

# 2. Upload images to stage (manual step via Snowsight or SnowSQL PUT)
# PUT file://data/images/* @AISQL_IMAGE_FILES;

# 3. Load images into table
snowsql -f 01_images.sql

# 4. Upload audio to stage (manual step)
# PUT file://data/audio/* @AISQL_AUDIO_FILES;

# 5. Load audio into table
snowsql -f 02_audio.sql

# 6. Explore demos
# - Open 03_cortex_aisql_original.ipynb (original quickstart)
# - Open notebooks/01-05 (extended demos)
# - Run any sql_scripts/*.sql file
```

## License

See LICENSE file for details.

