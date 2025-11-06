# Running Notebooks in Local Jupyter

## Quick Setup for Local Development

### 1. Install Dependencies

**Option A: Using requirements.txt (Recommended)**
```bash
pip install -r requirements.txt
```

**Option B: Manual installation**
```bash
pip install snowflake-snowpark-python plotly toml pandas jupyter
```

**Option C: Using a virtual environment (Best Practice)**
```bash
# Create virtual environment
python -m venv venv

# Activate it
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Verify installation (optional but recommended)
python verify_setup.py
```

### 2. Configure Snowflake Connection

Create `~/.snowflake/connections.toml`:

```toml
[default]
account = "your_account_identifier"
user = "your_username"
password = "your_password"
warehouse = "AISQL_WH"
database = "AISQL_DB"
schema = "AISQL_SCHEMA"
role = "ACCOUNTADMIN"  # or your appropriate role
```

**Security Tip:** Use environment variables or authenticator instead of passwords:

```toml
[default]
account = "your_account_identifier"
user = "your_username"
authenticator = "externalbrowser"  # For SSO/browser auth
warehouse = "AISQL_WH"
database = "AISQL_DB"
schema = "AISQL_SCHEMA"
```

### 3. Start Jupyter

```bash
jupyter notebook
# or
jupyter lab
```

### 4. Open Any Notebook

Navigate to `notebooks/` and open any notebook:
- `01_text_analytics.ipynb`
- `02_embeddings_similarity.ipynb`
- `03_multimodal_analytics.ipynb`
- `04_aggregation_translation.ipynb`
- `05_advanced_features.ipynb`

The notebooks will automatically:
1. Try to connect using Snowflake Notebooks session (if available)
2. Fall back to `~/.snowflake/connections.toml` (for local Jupyter)
3. Display connection status

## Troubleshooting

### Issue: "Connection file not found"
**Solution:** Create `~/.snowflake/connections.toml` with your credentials

### Issue: "Connection 'default' not found"
**Solution:** Ensure your connection profile is named `[default]` or update the `connection_name` variable in the notebook

### Issue: "Module 'plotly' not found" or "Module 'toml' not found"
**Solution:** Install all dependencies using `pip install -r requirements.txt`

### Issue: Visualizations not showing
**Solution:** 
- For Jupyter Notebook: Ensure you're running cells in order
- For VS Code: Install Jupyter extension
- Try restarting the kernel

## Features

✅ **Automatic Connection Handling**: Works in both Snowflake Notebooks and local Jupyter
✅ **Interactive Visualizations**: Plotly charts with zoom, pan, hover
✅ **Rich Display**: Markdown formatting, tables, and code blocks
✅ **No Streamlit Required**: Pure Jupyter/IPython display

## VS Code Setup

1. Install VS Code Jupyter extension
2. Open notebook file
3. Select Python kernel
4. Run cells normally

## Google Colab Setup

1. Upload notebook to Colab
2. Upload `requirements.txt` to Colab
3. Install dependencies:
   ```python
   !pip install -r requirements.txt
   ```
4. Create connection config in Colab:
   ```python
   import os
   from pathlib import Path
   
   config_dir = Path.home() / ".snowflake"
   config_dir.mkdir(exist_ok=True)
   
   with open(config_dir / "connections.toml", "w") as f:
       f.write("""
   [default]
   account = "your_account"
   user = "your_username"
   password = "your_password"
   warehouse = "AISQL_WH"
   database = "AISQL_DB"
   schema = "AISQL_SCHEMA"
   """)
   ```
4. Run notebook cells

## Comparison: Snowflake Notebooks vs Local Jupyter

| Feature | Snowflake Notebooks | Local Jupyter |
|---------|-------------------|---------------|
| Connection | Automatic | Via connections.toml |
| Performance | Runs in Snowflake | Runs locally |
| Data Access | Direct | Via Snowpark |
| Visualizations | Plotly | Plotly |
| Sharing | Snowflake UI | Export .ipynb |
| Cost | Warehouse compute | Local compute |

Both environments are fully supported!

## Next Steps

- ✅ Run `00_setup.sql` to create database and load data
- ✅ Upload images and audio files to stages
- ✅ Open any notebook and start exploring!
- ✅ Modify queries and experiment with different AI functions

For more details, see:
- `README.md` - Complete documentation
- `NOTEBOOK_CHANGES.md` - Technical details of notebook updates
- `EXECUTION_ORDER.md` - Step-by-step setup guide

