-- Load Lending Club accepted loans from S3 into the raw layer.
-- Points at a prefix, not a filename, so future files under this path
-- are picked up by the same statement.

COPY INTO credit_stream.raw.accepted_loans
FROM @credit_stream.raw.s3_raw_stage/raw/lending_club/
FILE_FORMAT = (FORMAT_NAME = credit_stream.raw.ff_lending_club_csv)
ON_ERROR = 'ABORT_STATEMENT';