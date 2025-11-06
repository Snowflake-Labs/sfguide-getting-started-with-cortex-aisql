USE ROLE SALES_ENGINEER;

USE WAREHOUSE US_MAJORS_RCG_WH;

USE SCHEMA SNOWHOUSE.SALES;

-- SET ACCOUNT NAME
SET ACC_NAME = 'Vizio';


SELECT
    *
FROM
    TEMP.VSHIV.ACCOUNT_DETAILS_V;

SET (ACCOUNT_ID, NUM_MONTHS_CALC) = (6027267, 3);

SELECT HLL(uuid)
FROM
        job_etl_v job
    WHERE
        account_id = $ACCOUNT_ID
        AND job.created_on >= ADD_MONTHS(DATE_TRUNC('month', CURRENT_DATE()), - $NUM_MONTHS_CALC);

CREATE
OR replace TABLE temp.vshiv.connections_jobs AS 
WITH stmts as (
SELECT
    key :: VARCHAR AS statement_type_id,
    VALUE :: VARCHAR AS statement_type
FROM
    TABLE(FLATTEN(input => PARSE_JSON(SYSTEM$DUMP_ENUM('StatementType'))))
),
sno AS (
    SELECT
        to_date(access_time) DATE,
        account_name,
        user_name,
        id AS session_id,
        client_environment :APPLICATION :: STRING application,
        client_app_id,
        client_app_version,
        authn_method,
    FROM
        session_etl_v
    WHERE
        account_id = $ACCOUNT_ID --= $account_id --Locator Here
        AND access_time >= ADD_MONTHS(DATE_TRUNC('month', CURRENT_DATE()), - $NUM_MONTHS_CALC)
),
qh AS (
    SELECT
        --job.created_on,
        uuid AS query_id,
        decode(
            COALESCE(
                strip_null_value(job.dpo :"JobDPO:stats" .currentStateId),
                strip_null_value(
                    job.dpo :"JobDPO:stats" .currentStateId
                )
            ) :: INT,
            15,
            'FAIL',
            16,
            'INCIDENT',
            17,
            'SUCCESS'
        ) AS execution_status,
        job.created_on,
        error_message,
        statement_properties,
        warehouse_name,
        NULLIF(latest_cluster_number, -1) + 1 AS cluster_number,
        decode(
            job.stats :warehouseSize :: INT,
            1,'X-Small',
            2,'Small',
            4,'Medium',
            8,'Large',
            16,'X-Large',
            32,'2X-Large',
            64,'3X-Large',
            128,'4X-Large',
            20,'5X-Large',
            40,'6X-Large',
            NULL
        ) AS warehouse_size,
        total_duration,
        dur_gs_executing,
        dur_compiling,
        dur_queued_load,
        dur_xp_executing,
        description AS sql_text,
        session_id AS session_id_qh,
        job.stats :stats.producedRows AS rows_produced
    FROM
        job_etl_v job
    WHERE
        account_id = $ACCOUNT_ID -- = $account_id --and application is null
        AND job.created_on >= ADD_MONTHS(DATE_TRUNC('month', CURRENT_DATE()), - $NUM_MONTHS_CALC)
)
SELECT
    stmts.*,
    sno. *,
    qh. *
FROM
    sno
    LEFT OUTER JOIN qh ON qh.session_id_qh = sno.session_id
    RIGHT OUTER JOIN stmts ON qh.statement_properties = stmts.statement_type_id;


select 
  DATE,
  STATEMENT_TYPE, 
  USER_NAME, 
  TEMP.AGAVIC.GET_TOOL(UPPER(COALESCE(APPLICATION::VARCHAR, APPLICATION))) AS TOOL,
  AUTHN_METHOD, 
  SESSION_ID, 
  QUERY_ID,
  EXECUTION_STATUS,
  WAREHOUSE_NAME, 
  WAREHOUSE_SIZE, TOTAL_DURATION, 
  SQL_TEXT,
  HASH(SQL_TEXT),
  ROWS_PRODUCED
from temp.vshiv.connections_jobs
where 1=1
  and regexp_like(application,  '.*databricks.*|.*spark.*', 'i')
  and (rows_produced is not null or rows_produced >0);
--------------------------

SELECT 
  TEMP.AGAVIC.GET_TOOL(UPPER(COALESCE(CLIENT_ENVIRONMENT:APPLICATION::VARCHAR, CLIENT_APP_ID))) AS TOOL
  , HLL(ID) SESSION_CNT
FROM SESSION_ETL_V
WHERE CREATED_ON BETWEEN '2025-08-22' AND '2025-08-23'
GROUP BY ALL;


select top 100 * from SESSION_ETL_V;


SELECT DISTINCT 
                    CASE 
                        WHEN PARENT_NAME = SFDC_CUST_NAME THEN SFDC_CUST_NAME
                        ELSE PARENT_NAME || ' > ' || SFDC_CUST_NAME 
                    END AS CUSTOMER_NAME,
                    SF_ACCT_ID,
                    SF_ACCT_NAME || ' (' || IFNULL(SF_ACCT_ALIAS,'NO ALIAS') || ')' AS SF_ACCT_NAME,
                    SF_ACCT_NAME AS SF_ACCOUNT_NAME,
                    SF_ACCOUNT_TYPE,
                    SF_SERVICE AS EDITION,
                    SF_AGREEMENT_TYPE, 
                    SF_CLOUD,
                    SF_CLOUD || ' ➡️ ' || PROVIDER_REGION || ' ➡️ ' || SF_DEPLOYMENT AS CLOUD_DEPLOYMENT,
                    SF_DEPLOYMENT AS SF_DEPLOYMENT,
                    QUERY_HISTORY_URL,
                    QUERY_URL,
                    SNOVI_URL,
                    SUB_START_DATE, SUB_END_DATE,
                    L30_CREDITS,
                    FROM
                    TEMP.VSHIV.SUBSCRIPTIONS_DT
                    WHERE
                    TRUE
                    --AND SF_ACCT_ALIAS IS NOT NULL
                    ORDER BY L30_CREDITS DESC NULLS LAST, SF_ACCT_NAME ASC NULLS LAST;

-----------------------------

SELECT 
distinct 
--client_app_id,
    REGEXP_SUBSTR(client_app_id, '^(.*)\\s') AS client_app,
    application,
    -- case
    -- when application ilike '%tableau%' then 'Tableau'
    -- when application ilike '%vscode%' then 'VS Code'
    -- when application ilike '%Snowflake%Web%App%' then 'Snowflake Web App'
    -- when application ilike '%jar' then 'Custom Java App'
    -- else application end as app
    L.APP_NAME_DISPLAY
FROM   TEMP.VSHIV.CONNECTIONS_JOBS J
LEFT JOIN TEMP.VSHIV.APPS_LOOKUP L
ON (
    j.application ILIKE '%' || l.app_name_regex || '%' 
    OR (l.app_name_regex = '.jar' AND J.application ILIKE '%.jar')
)
WHERE 1=1
AND J.APPLICATION IS NOT NULL
order by 1;


select * from TEMP.VSHIV.CONNECTIONS_JOBS J limit 10;
SELECT 
distinct 
    REGEXP_SUBSTR(client_app_id, '^(.*)\\s') AS client_app,
    application,
    case 
    WHEN APPLICATION ILIKE '%.jar%' THEN REGEXP_SUBSTR(APPLICATION, '[^/]+\.jar$')
    WHEN APPLICATION ILIKE '%vscode%' THEN 'VS Code'
    WHEN APPLICATION ILIKE '%Snowflake%Web%' THEN 'Snowsight'
    WHEN APPLICATION ILIKE '%databricks%' THEN 'Databricks'
    WHEN APPLICATION ILIKE '%tableau%' THEN 'Tableau'
    WHEN APPLICATION ILIKE '%tabprotosrv%' THEN 'Tableau'
    ELSE trim(regexp_replace(application, 'com.|org.','')) end as application_reg
FROM   TEMP.VSHIV.CONNECTIONS_JOBS J
WHERE 1=1
AND J.APPLICATION IS NOT NULL
order by 1;






SELECT f.*, l.app_name_display
FROM filtered_data f
LEFT JOIN lookup_table l
ON f.app_name REGEXP l.app_name_regex;

--AND APPLICATION = 'Go';

-- AGGREGATE
--CREATE OR REPLACE TABLE TEMP.VSHIV.CONNECTIONS_JOBS_AGG AS 
SELECT
    TO_CHAR(DATE, 'YYYY-MM') AS USAGE_MONTH,
    ACCOUNT_NAME,
    IFNULL(CASE
        WHEN CLIENT_APP_ID ILIKE '%JDBC%' THEN 'JDBC'
        WHEN CLIENT_APP_ID ILIKE '%ODBC%' THEN 'ODBC'
        WHEN CLIENT_APP_ID ILIKE '%Python%' THEN 'Python Connector'
        WHEN CLIENT_APP_ID ILIKE '%Go%' THEN 'Go'
        WHEN CLIENT_APP_ID ILIKE '%Javascript%' THEN 'Javascript'
        WHEN CLIENT_APP_ID ILIKE '%Snowflake%UI%' THEN 'Snowflake UI'
        WHEN CLIENT_APP_ID ILIKE '%Snow%SQL%' THEN 'SnowSQL'
        ELSE CLIENT_APP_ID
    END, 'N/A') || ' | ' ||
    IFNULL(CASE
        WHEN APPLICATION ILIKE '%databricks%' THEN 'Databricks'
        WHEN APPLICATION ILIKE '%tableau%' THEN 'Tableau'
        WHEN APPLICATION ILIKE '%tabprotosrv%' THEN 'Tableau'
        WHEN APPLICATION ILIKE '%Python%' THEN 'Python Connector'
        WHEN APPLICATION ILIKE '%AIRFLOW%' THEN 'Airflow'
        WHEN APPLICATION ILIKE '%unicorn%' THEN 'Unicorn Rails Worker'
        WHEN APPLICATION ILIKE '%remotejdbc%' THEN 'RemoteJDBCServer'
        WHEN APPLICATION ILIKE '%airbyte%' THEN 'Airbyte'
        WHEN APPLICATION ILIKE '%VS%CODE%' THEN 'VS Code'
        WHEN APPLICATION ILIKE '%Snowflake%Web%' THEN 'Snowflake Web App'
        ELSE APPLICATION
    END, 'N/A') || ' | ' || WAREHOUSE_NAME AS CLIENT_APPLICATION_WH,
    STATEMENT_TYPE,
    WAREHOUSE_NAME,
    USER_NAME,
    COUNT(QUERY_ID) AS NUM_QUERIES,
    ROUND(AVG(TOTAL_DURATION / 1000), 2) AS AVG_QUERY_DUR_S,
    ROUND(AVG(ROWS_PRODUCED)) AS AVG_ROWS_AFFECTED
    --CASE WHEN AVG_QUERY_DUR_S > 10 THEN TRUE ELSE FALSE END AS QUERY_DUR_BOOL
FROM
    TEMP.VSHIV.CONNECTIONS_JOBS
WHERE 1=1
 --AND USAGE_MONTH >= '2023-08'
-- --AND WAREHOUSE_NAME = 'REDASH'
-- AND USER_NAME ILIKE '%REDASH%'
--AND CLIENT_APPLICATION ilike '%segment%'
GROUP BY ALL
--HAVING COUNT(QUERY_ID) > 10000
--AND AVG_QUERY_DUR_S > 10
ORDER BY
    NUM_QUERIES DESC, STATEMENT_TYPE, USAGE_MONTH DESC;


SELECT DATE, STATEMENT_TYPE, COUNT(QUERY_ID)
FROM
    TEMP.VSHIV.CONNECTIONS_JOBS
WHERE 1=1
AND STATEMENT_TYPE IN ('CREATE_TABLE_AS_SELECT', 'MERGE', 'DELETE')
GROUP BY ALL
ORDER BY 1;

