-- credit-stream: Snowflake setup
-- Run as ACCOUNTADMIN. Creates the S3 ingestion path.

USE ROLE ACCOUNTADMIN;

-- Storage integration: lets Snowflake assume an AWS IAM role to reach S3.
-- No credentials stored here - auth is delegated to the role's trust policy.
-- STORAGE_ALLOWED_LOCATIONS whitelists the bucket, so no stage using this
-- integration can point anywhere else.
CREATE STORAGE INTEGRATION credit_stream_s3_int
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'S3'
  ENABLED = TRUE
  STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::863618515495:role/snowflake_credit_stream_role'
  STORAGE_ALLOWED_LOCATIONS = ('s3://credit-stream-raw-andres/');

CREATE DATABASE credit_stream;

-- Raw layer: data exactly as it arrived from source. Never edited in place.
CREATE SCHEMA credit_stream.raw;

-- Named pointer to the bucket + how to authenticate to it.
CREATE STAGE credit_stream.raw.s3_raw_stage
  URL = 's3://credit-stream-raw-andres/'
  STORAGE_INTEGRATION = credit_stream_s3_int;

-- Smoke test: proves the full path works before loading real data.
-- All VARCHAR so a load can never fail on a type mismatch. Casting is
-- the staging layer's job.
CREATE TABLE credit_stream.raw.smoke_test (
  loan_id  VARCHAR,
  amount   VARCHAR,
  status   VARCHAR
);

COPY INTO credit_stream.raw.smoke_test
FROM @credit_stream.raw.s3_raw_stage/smoke_test.csv
FILE_FORMAT = (TYPE = CSV SKIP_HEADER = 1);

-- Two rows in a Snowflake table that started as a file on my laptop. 
-- The full path works: local → S3 → external stage → warehouse. 
-- That's the ingestion path.
