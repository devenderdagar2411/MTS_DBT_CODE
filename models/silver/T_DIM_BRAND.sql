{{ config(
    materialized = 'table',
    schema = 'SILVER_SALES',
    alias = 'T_DIM_BRAND'
) }}

with source_data as (
    select
        ENTRY_TIMESTAMP,
        SEQUENCE_NUMBER,
        OPERATION,
        B99BSCD,               -- BRAND_ID
        B99NAME,               -- BRAND_NAME
        B99USER,               -- LAST_MODIFIED_USER
        B99CYMD,               -- LAST_MODIFIED_DATE
        B99HMS,                -- LAST_MODIFIED_TIME
        B99WKSN,               -- WORKSTATION_ID
        SOURCE_SYSTEM,
        SOURCE_FILE_NAME,
        BATCH_ID,
        ETL_VERSION,
        INGESTION_DTTM,
        INGESTION_DT
    from RAW_DATA.BRONZE_SALES.t_brz_brand_inbrnd
),

ranked_data as (
    select
        *,
        row_number() over (
            partition by B99BSCD 
            order by ENTRY_TIMESTAMP desc, SEQUENCE_NUMBER desc
        ) as rn
    from source_data
),

final_data as (
    select
        -- BRAND_KEY (BIGINT → hashed surrogate key)
        cast(abs(hash(try_cast(B99BSCD as number(10,0)))) as bigint) as BRAND_KEY,

        -- BRAND_ID (INTEGER(10))
        cast(try_cast(B99BSCD as number(10,0)) as integer) as BRAND_ID,

        -- BRAND_NAME (VARCHAR(100))
        cast(B99NAME as varchar(100)) as BRAND_NAME,

        -- Audit Fields
        cast(SOURCE_SYSTEM as varchar(100)) as SOURCE_SYSTEM,
        cast(SOURCE_FILE_NAME as varchar(200)) as SOURCE_FILE_NAME,
        cast(BATCH_ID as varchar(50)) as BATCH_ID,
        md5(coalesce(B99NAME, '')) as RECORD_CHECKSUM_HASH,
        cast(ETL_VERSION as varchar(20)) as ETL_VERSION,
        cast(INGESTION_DTTM as timestamp_ntz) as INGESTION_DTTM,
        cast(INGESTION_DT as date) as INGESTION_DT

    from ranked_data
    where rn = 1
)

select * from final_data
