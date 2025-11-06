# Execution Order Guide

## 📋 Quick Start (5 Steps)

### Step 0: Prerequisites
- Snowflake account with Cortex AISQL enabled
- CORTEX_USER role permissions
- SnowSQL or Snowsight access

### Step 1: Database Setup
```sql
@00_setup.sql
```
**Creates:**
- Database: `AISQL_DB`
- Schema: `AISQL_SCHEMA`
- Warehouse: `AISQL_WH`
- Tables: `EMAILS`, `SOLUTION_CENTER_ARTICLES`
- Stages: `AISQL_IMAGE_FILES`, `AISQL_AUDIO_FILES`

### Step 2: Upload & Load Images
```bash
# Upload images to stage (via Snowsight UI or SnowSQL)
PUT file://data/images/* @AISQL_IMAGE_FILES;

# Load into table
@01_images.sql
```
**Creates:** `IMAGES` table with ~50 image files

### Step 3: Upload & Load Audio
```bash
# Upload audio to stage
PUT file://data/audio/* @AISQL_AUDIO_FILES;

# Load into table
@02_audio.sql
```
**Creates:** `VOICEMAILS` table with ~50 audio files

### Step 4: Verify Setup
```sql
USE DATABASE AISQL_DB;
USE SCHEMA AISQL_SCHEMA;

SELECT COUNT(*) FROM emails;              -- Should return ~50
SELECT COUNT(*) FROM solution_center_articles;  -- Should return ~50
SELECT COUNT(*) FROM images;              -- Should return ~50
SELECT COUNT(*) FROM voicemails;          -- Should return ~50
```

### Step 5: Explore Demos

#### Option A: Original Quickstart Demo
```
Open: 03_cortex_aisql_original.ipynb
```
Shows: Multimodal analysis, AI_FILTER, AI_AGG, AI_CLASSIFY

#### Option B: Extended Demos (Recommended)
```
Open notebooks in order:
├── notebooks/01_text_analytics.ipynb
├── notebooks/02_embeddings_similarity.ipynb
├── notebooks/03_multimodal_analytics.ipynb
├── notebooks/04_aggregation_translation.ipynb
└── notebooks/05_advanced_features.ipynb
```

#### Option C: Individual SQL Scripts
```bash
# Run any script from sql_scripts/
snowsql -f sql_scripts/sentiment_analysis.sql
snowsql -f sql_scripts/embedding_similarity.sql
snowsql -f sql_scripts/translation.sql
# etc.
```

## 📁 File Organization

### Root Directory (Numbered for Execution Order)
```
00_setup.sql                    ← Step 1: Run first
01_images.sql                   ← Step 2: Run second
02_audio.sql                    ← Step 3: Run third
03_cortex_aisql_original.ipynb ← Step 4: Original demo
snowbooks_extras.py             ← Utility (auto-loaded)
```

### Organized Directories
```
sql_scripts/                    ← Individual function demos
├── embedding_similarity.sql
├── extraction.sql
├── sentiment_analysis.sql
├── translation.sql
├── summarization.sql
├── document_parsing.sql
├── helper_functions.sql
└── cortex_guard.sql

notebooks/                      ← Extended interactive demos
├── 01_text_analytics.ipynb
├── 02_embeddings_similarity.ipynb
├── 03_multimodal_analytics.ipynb
├── 04_aggregation_translation.ipynb
└── 05_advanced_features.ipynb

data/                          ← Sample data
├── emails.csv
├── solution_center_articles.csv
├── images/                    ← 50+ image files
└── audio/                     ← 50+ audio files
```

## 🎯 Common Workflows

### Workflow 1: Quick Demo
```bash
1. @00_setup.sql
2. Upload images & audio (via Snowsight)
3. @01_images.sql
4. @02_audio.sql
5. Open 03_cortex_aisql_original.ipynb
```

### Workflow 2: Learn All Functions
```bash
1. Complete Quick Demo steps 1-4
2. Open notebooks/01_text_analytics.ipynb
3. Work through notebooks 01-05 in order
```

### Workflow 3: Specific Function Testing
```bash
1. Complete Quick Demo steps 1-4
2. Run specific SQL script:
   snowsql -f sql_scripts/sentiment_analysis.sql
```

## ⚠️ Important Notes

1. **Upload Files First**: You must upload files to stages before running `01_images.sql` and `02_audio.sql`

2. **Stage Upload Methods**:
   - **Snowsight UI**: Navigate to Data → Databases → AISQL_DB → Stages → Upload
   - **SnowSQL**: Use `PUT file://path/to/files/* @STAGE_NAME;`

3. **Dependencies**:
   - All SQL scripts in `sql_scripts/` require setup (steps 1-4) to be completed
   - All notebooks require setup (steps 1-4) to be completed
   - Original notebook `03_cortex_aisql_original.ipynb` requires all data loaded

4. **Execution Environment**:
   - SQL scripts: Run in SnowSQL, Snowsight, or any SQL client
   - Notebooks: Run in Snowflake Notebooks, Jupyter, or compatible environment

## 🔍 Troubleshooting

### Issue: "Table does not exist"
**Solution**: Run `00_setup.sql` first

### Issue: "Stage is empty"
**Solution**: Upload files to stages using PUT command or Snowsight UI

### Issue: "No data in IMAGES or VOICEMAILS table"
**Solution**: 
1. Verify files uploaded to stages
2. Run `01_images.sql` and `02_audio.sql`

### Issue: "Function not found"
**Solution**: Ensure Cortex AISQL is enabled for your account and you have CORTEX_USER role

## 📚 Next Steps

After completing setup:
1. ✅ Try the original demo: `03_cortex_aisql_original.ipynb`
2. ✅ Explore extended demos: `notebooks/01-05`
3. ✅ Test individual functions: `sql_scripts/*.sql`
4. ✅ Build your own AI applications!

## 📖 Additional Resources

- Full documentation: `README.md`
- Function reference: See README.md "Complete AISQL Function Reference" section
- Official docs: https://docs.snowflake.com/en/user-guide/snowflake-cortex/aisql

