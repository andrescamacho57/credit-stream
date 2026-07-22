# credit-stream — Progress Tracker

**Owner:** Andres Camacho
**Started:** 2026-07-22
**Target demoable slice:** 2026-07-29
**Status:** Ingestion path proven end-to-end

---

## The rule for this project

One finished flagship beats three half-built repos. Anything not in "Next 7 Days"
goes in the Parking Lot until the core slice is done and demoable.

---

## Done

### Day 0 — 2026-07-22

**Infrastructure**
- Snowflake trial provisioned, region verified as `AWS_US_EAST_2` (checked, not assumed)
- S3 bucket `credit-stream-raw-andres` in us-east-2, Block Public Access fully on
- Global bucket namespace chosen over Account Regional for third-party compatibility

**Security**
- IAM permissions policy `snowflake_credit_stream_s3_read` — read-only, no write, no delete
- IAM role `snowflake_credit_stream_role` with trust policy scoped to Snowflake's
  principal and gated by an external ID
- Storage integration `credit_stream_s3_int` — no credentials stored in Snowflake

**Warehouse**
- Database `credit_stream`, schema `raw`
- External stage `s3_raw_stage`
- Smoke test loaded end-to-end: local file → S3 → stage → Snowflake table (2 rows)

**Repo**
- GitHub repo created, 3 commits pushed
- `snowflake/01_setup.sql` — setup reproducible from version control
- `.gitignore` guards against committing data files

**Concepts learned**
- Git's four locations: working dir → staging → local repo → remote
- IAM roles vs users; trust policy (who) vs permissions policy (what)
- External ID and the confused-deputy problem
- Empty result ≠ error — different diagnoses
- Why raw layer is all-VARCHAR

---

## Next 7 Days

### Day 1 — Jul 23: Load the real dataset
**Deliverable:** Lending Club data queryable in `credit_stream.raw`

- Inspect the file before loading (row count, column count, size)
- Compress with gzip — understand why before doing it
- Upload to S3 under a prefix convention: `raw/lending_club/<date>/`
- Create a named file format object (reusable, versioned)
- Create raw table, all VARCHAR
- `COPY INTO` with `ON_ERROR` handling; validate with `COPY_HISTORY`
- Commit updated setup SQL

**Concepts:** file compression and load parallelism, S3 prefixes vs folders,
`ON_ERROR` modes, load metadata

**Risk:** first real-data load; expect at least one parse failure. That's the lesson.

---

### Day 2 — Jul 24: dbt project + first staging model
**Deliverable:** `dbt run` succeeds against Snowflake

- Python virtual environment, install `dbt-snowflake`
- `dbt init`, configure `profiles.yml` — and keep it out of Git
- `sources.yml` declaring the raw tables
- First staging model `stg_loans`: cast types, clean `"13.56%"` → `0.1356`,
  `" 36 months"` → `36`
- `dbt run`, inspect compiled SQL in `target/`

**Concepts:** what dbt actually does (compiles Jinja → SQL → runs it),
`ref()` vs `source()`, materializations, why credentials live outside the repo

---

### Day 3 — Jul 25: Finish staging + tests
**Deliverable:** `dbt build` green with tests passing

- Complete column cleaning in `stg_loans`
- `schema.yml` with `unique` and `not_null` on the grain
- One custom test that encodes a real business rule
- `dbt docs generate` and browse the lineage graph

**Concepts:** a dbt test is just a SQL query that should return zero rows;
grain as a contract; generic vs singular tests

---

### Day 4 — Jul 26: Design the star schema
**Deliverable:** a written grain statement + first dimension and fact model

- Design on paper first — no SQL until the grain is declared in one sentence
- Decide fact vs dimension for each entity
- Build `dim_borrower`, `fct_loans`
- Surrogate keys via `dbt_utils.generate_surrogate_key`

**Concepts:** grain, conformed dimensions, surrogate vs natural keys,
why star schema over one wide table

**Risk:** this is the slowest day. Design thinking takes longer than typing.
Do not rush it — this is the layer interviewers ask about.

---

### Day 5 — Jul 27: Finish marts
**Deliverable:** marts layer complete, all tests passing

- Complete the dimensional models
- Add the small-business-purpose slice (ties to SMB credit risk background)
- `relationships` tests between fact and dimensions
- Add incremental materialization to at least one model

**Concepts:** incremental models, `is_incremental()`, late-arriving data,
why incremental matters at scale even when full-refresh works today

---

### Day 6 — Jul 28: CI/CD
**Deliverable:** GitHub Actions runs `dbt build` + `sqlfluff` on every PR

- Learn branches and pull requests properly (first real use)
- Snowflake credentials as GitHub Actions secrets
- Workflow file: lint, then build, then test
- Open a PR, watch it fail, fix it, watch it pass

**Concepts:** branching, PR workflow, secrets management, why CI matters
even for a solo project

**Risk:** highest chance of frustrating auth errors. Budget extra time.

---

### Day 7 — Jul 29: README + narrative
**Deliverable:** repo a stranger can understand in 90 seconds

- Architecture diagram
- "Tool Choices & Tradeoffs" section — including what you'd do differently
- Setup instructions someone else could follow
- Rehearse the 30-second interview version out loud

---

## After Day 7 (level-ups while interviewing)

Each of these is a fresh talking point — "since we last spoke I added…"

- Snowflake Streams + Tasks for incremental stream processing
- Python payment-event generator
- Anomaly view: clients paying multiple times per month
- Streamlit dashboard on the marts
- RBAC roles beyond ACCOUNTADMIN
- Snowpipe for auto-ingest
- Dagster or Airflow replacing GitHub Actions cron

---

## Parking Lot (deliberately not doing yet)

- Live market-data API instead of simulated events
- Anything that merges this project with the SMB risk product
- Additional datasets
- Terraform / infrastructure-as-code

---

## Open Questions

- Does the anomaly signal get a stated interpretation, or stay purely a
  "route for human review" flag? (Leaning: the latter — more defensible)
- Which incremental strategy for `fct_loans` — merge or insert-overwrite?
