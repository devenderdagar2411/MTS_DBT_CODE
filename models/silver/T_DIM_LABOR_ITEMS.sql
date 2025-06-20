{{ config(
    materialized = 'table',
    schema = 'SILVER_SALES',
    alias = 'T_DIM_LABOR_ITEMS'
) }}

with source_data as (
    select
        ENTRY_TIMESTAMP,
        SEQUENCE_NUMBER,
        OPERATION,
        "Z9ITM#" as Z9ITM ,                        -- ITEM_ID (Key field)
        SOURCE_SYSTEM,
        SOURCE_FILE_NAME,
        BATCH_ID,
        ETL_VERSION
    from {{ source('bronze_data', 'T_BRZ_LABOR_ITEMS_INITLB') }}
),

ranked_data as (
    select
        *,
        row_number() over (
            partition by Z9ITM
            order by ENTRY_TIMESTAMP desc
        ) as rn
    from source_data
),

final_data as (
    select
        Z9ITM,
        SOURCE_SYSTEM,
        SOURCE_FILE_NAME,
        BATCH_ID,
        MD5(COALESCE(TRIM(Z9ITM), '')) as RECORD_CHECKSUM_HASH,
        ETL_VERSION,
        CURRENT_TIMESTAMP() AS INGESTION_DTTM,
        CURRENT_DATE() AS INGESTION_DT
    from ranked_data
    where rn = 1
)

select
    CAST(Z9ITM AS NUMBER(10,0)) as ITEM_ID,
    CAST(SOURCE_SYSTEM AS VARCHAR(100)) as SOURCE_SYSTEM,
    CAST(SOURCE_FILE_NAME AS VARCHAR(200)) as SOURCE_FILE_NAME,
    CAST(BATCH_ID AS VARCHAR(50)) as BATCH_ID,
    CAST(RECORD_CHECKSUM_HASH AS VARCHAR(64)) as RECORD_CHECKSUM_HASH,
    CAST(ETL_VERSION AS VARCHAR(20)) as ETL_VERSION,
    CAST(INGESTION_DTTM AS TIMESTAMP_NTZ) as INGESTION_DTTM,
    CAST(INGESTION_DT AS DATE) as INGESTION_DT
from final_data
