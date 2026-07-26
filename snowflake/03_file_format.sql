-- Reusable CSV parsing rules for Lending Club loads.
-- Named object so every load parses identically and rules change in one place.

CREATE OR REPLACE FILE FORMAT credit_stream.raw.ff_lending_club_csv
  TYPE = CSV
  SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  COMPRESSION = AUTO
  NULL_IF = ('', 'NULL', 'null', 'n/a')
  EMPTY_FIELD_AS_NULL = TRUE
  COMMENT = 'Lending Club CSV. Quoted fields required - desc column is free text with embedded commas and newlines.';