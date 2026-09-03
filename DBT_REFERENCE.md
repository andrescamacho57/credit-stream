# dbt Reference

Running reference for dbt on this project. Appended to as we go.
**Engine: dbt Fusion (dbt 2.0), preview build.**

---

## What dbt Actually Is

dbt does **one thing**: it takes SQL files you write, compiles them into runnable
SQL, executes them against your warehouse in dependency order, and tests the
results.

It does **not** move data. It does not extract or load. It transforms data that is
already in the warehouse. The "T" in ELT.

**A dbt model is just a SELECT statement in a `.sql` file.** dbt wraps it in
`CREATE TABLE AS` or `CREATE VIEW AS` for you. You never write the DDL.

---

## Fusion vs Core (as of July 2026)

**dbt was rewritten in Rust.** dbt Core v2.0 shipped in alpha June 1, 2026, built
on the same Rust engine as Fusion. Installing dbt now gives you Fusion by default.
dbt Core v1.x (the Python version) continues on the 1.x series.

**What this means practically:**
- Fusion is a **single self-contained binary** — no Python, no pip, no virtualenv
- Adapters (Snowflake, BigQuery, etc.) are **compiled in**, not installed separately
- Much faster startup and parsing
- Some features still in preview; Python models are not fully supported

**The dbt language is unchanged.** Models, `ref()`, `source()`, tests,
`schema.yml`, materializations — identical between Core and Fusion. Skills transfer
completely. The difference is the engine, not the syntax.

**Fusion-specific behavior worth knowing:** Fusion ignores the `threads` setting on
Snowflake and Databricks and optimizes parallelism itself.

**dbt Labs was acquired by Fivetran.**

---

## Commands

### Setup & health
| Command | Does |
|---|---|
| `dbt --version` | Which engine and version |
| `dbt system update` | Update the Fusion binary to latest |
| `dbt init <name>` | Scaffold a new project |
| `dbt debug` | **Test the warehouse connection** — run this first when anything is wrong |
| `dbt deps` | Install packages listed in `packages.yml` |

### Running
| Command | Does |
|---|---|
| `dbt run` | Build all models |
| `dbt run --select stg_loans` | Build one model |
| `dbt run --select staging` | Build everything in the staging folder |
| `dbt run --select stg_loans+` | That model **and everything downstream** |
| `dbt run --select +fct_loans` | That model **and everything upstream** |
| `dbt run --full-refresh` | Rebuild incremental models from scratch |

### Testing & building
| Command | Does |
|---|---|
| `dbt test` | Run all tests |
| `dbt build` | **run + test together, in dependency order** — the one to prefer |
| `dbt compile` | Generate SQL without executing it |

**`dbt build` over `dbt run` + `dbt test`:** build interleaves them, so a model
whose upstream test failed doesn't get built on bad data. `run` then `test` would
build everything first and only then discover the problem.

### Docs
| Command | Does |
|---|---|
| `dbt docs generate` | Build the documentation site |
| `dbt docs serve` | Open it in a browser with the lineage graph |

### Inspecting
| Command | Does |
|---|---|
| `dbt ls` | List resources matching a selector |
| `dbt parse` | Parse the project without running |

---

## Project Structure

```
dbt/
├── dbt_project.yml      # project config - name, paths, model defaults
├── profiles.yml         # connection credentials (usually ~/.dbt/, NOT in repo)
├── packages.yml         # third-party packages to install
├── models/
│   ├── staging/         # one model per source table, cleaned
│   ├── intermediate/    # reusable logic between staging and marts
│   └── marts/           # star schema, business-facing
├── macros/              # reusable Jinja functions
├── tests/               # custom singular tests
├── seeds/               # small CSVs loaded as tables
├── snapshots/           # slowly changing dimension tracking
├── target/              # GENERATED - compiled SQL, artifacts. Gitignore this.
└── logs/                # GENERATED. Gitignore this.
```

**`target/` and `logs/` are generated output.** They must be in `.gitignore` —
committing them is a classic beginner tell.

---

## The YAML Files

**YAML** = human-readable config format. Indentation defines nesting.
**Spaces only, never tabs.** A tab produces a parse error that doesn't mention tabs.

### `dbt_project.yml` — project configuration
```yaml
name: 'credit_stream'
version: '1.0.0'
profile: 'credit_stream'      # which profile in profiles.yml to use

model-paths: ["models"]
target-path: "target"

models:
  credit_stream:
    staging:
      +materialized: view     # defaults for everything in models/staging/
    marts:
      +materialized: table
```

The `+` prefix marks a **config**, distinguishing it from a folder name.

### `profiles.yml` — connection credentials
Lives in `~/.dbt/profiles.yml`, **outside the repo**, because it holds secrets.
The `profile:` key in `dbt_project.yml` picks which entry here to use.

```yaml
credit_stream:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: ABC12345.us-east-2.aws
      user: myuser
      password: "{{ env_var('SNOWFLAKE_PASSWORD') }}"
      role: ACCOUNTADMIN
      warehouse: COMPUTE_WH
      database: CREDIT_STREAM
      schema: dbt_dev
      threads: 8
```

**`target`** = which named output to use by default. Having `dev` and `prod`
targets pointing at different schemas is how you avoid clobbering production
while developing.

### `sources.yml` — declare what's already in the warehouse
```yaml
version: 2
sources:
  - name: raw
    database: credit_stream
    schema: raw
    tables:
      - name: accepted_loans
```

Then reference it in a model as `{{ source('raw', 'accepted_loans') }}`.

### `schema.yml` — tests and documentation
```yaml
version: 2
models:
  - name: stg_loans
    description: One row per loan, types cast and values cleaned
    columns:
      - name: loan_id
        description: Natural key from the source system
        tests:
          - unique
          - not_null
```

---

## Core Concepts

**`ref()`** — reference another dbt model: `{{ ref('stg_loans') }}`. dbt replaces it
with the real table name at compile time and uses it to build the dependency graph.
**Never hardcode a table name for a dbt-built model** — you lose lineage and
ordering.

**`source()`** — reference a table dbt did *not* build:
`{{ source('raw', 'accepted_loans') }}`. Declared in `sources.yml`.

**The DAG** (Directed Acyclic Graph) — dbt reads every `ref()` and `source()` to
work out what depends on what, then runs models in the correct order automatically.
You never specify run order manually.

**Materialization** — how a model becomes a physical object:
| Type | Result |
|---|---|
| `view` | A view. Cheap to build, computed on every query. Good for staging. |
| `table` | A table. Rebuilt fully each run. Good for marts. |
| `incremental` | A table, but only new/changed rows are processed. |
| `ephemeral` | Not built at all — inlined as a CTE into downstream models. |

**Jinja** — the templating language dbt uses. Anything in `{{ }}` is evaluated at
compile time. This is what makes `ref()` and macros possible.

**A dbt test is just a SQL query that should return zero rows.** If it returns rows,
those are the failures. That's the whole idea — nothing more magic than that.

- **Generic tests** — `unique`, `not_null`, `accepted_values`, `relationships`.
  Declared in YAML, reusable.
- **Singular tests** — a `.sql` file in `tests/` containing one specific query.

**Package** — reusable macros and tests from the community. `dbt_utils` is the
standard one. Declared in `packages.yml`, installed with `dbt deps`.

---

## Good to Know

**`dbt debug` is the first thing to run when anything is broken.** It checks the
profile, the connection, and required dependencies, and tells you which one failed.

**Credentials never go in the repo.** `profiles.yml` lives in `~/.dbt/`, and even
there the password should come from an environment variable via `env_var()`. In CI
they come from secrets.

**Each developer gets their own schema.** Setting `schema: dbt_andres` in your dev
target means your models build into `dbt_andres` and can't collide with anyone
else's work — or with production.

**Staging models are almost always views.** They're thin transformations, and a view
costs nothing to build. Marts are usually tables because they're queried often.

**One staging model per source table.** Resist the urge to join in staging — that's
what intermediate and marts are for.

---

## Not Yet Used (add detail when we get there)

- `packages.yml` and `dbt deps` — Day 4, for `dbt_utils.generate_surrogate_key`
- Incremental models and `is_incremental()` — Day 5
- Snapshots — not planned for v1
- Custom macros — as needed

---

## Setup As Actually Performed (Fusion, July 2026)

### Install / update
```bash
dbt system update      # updates the Rust binary in place
dbt --version          # dbt-fusion 2.0.0-preview.202
```

Binary lives at `~/.local/bin/dbt`. The updater adds that to PATH in `~/.zshrc`.

### Init — syntax differs from dbt-core 1.x
```bash
dbt init --project-name credit_stream
```

**Not** `dbt init credit_stream`. Fusion takes a flag, not a positional argument.
The old syntax errors with `unexpected argument found`.

Interactive prompts:
1. Profile setup → **Set up a new profile from scratch**
2. Adapter → **snowflake** (all adapters available; none need installing)
3. Auth method → **Key pair**
4. Private key path vs inline → **file path**

`--sample` defaults to `jaffle-shop`, so init scaffolds a full sample project.

### What init creates — and what to delete
```
models/staging/*     ← DELETE, jaffle-shop samples
models/marts/*       ← DELETE
seeds/*.csv          ← DELETE
macros/cents_to_dollars.sql  ← DELETE
README.md            ← DELETE (repo already has a real one)

dbt_project.yml      ← KEEP, edit
packages.yml         ← KEEP (comes with dbt_utils already listed)
.gitignore           ← KEEP
.vscode/extensions.json ← KEEP
```

A portfolio repo containing someone else's tutorial models is worse than an empty one.

### Folder naming
Project was renamed from `credit_stream/` to `dbt/` inside the repo.
**Folder name and project name are independent** — the `profile:` lookup uses the
project name from `dbt_project.yml`, not the directory. Nothing breaks.

```
credit-stream/
├── snowflake/    # infrastructure DDL
├── dbt/          # transformations  ← the dbt project
└── README.md
```

Some CI tooling assumes dbt lives at the repo root. Non-issue — the workflow just
runs `cd dbt` first.

---

## profiles.yml With Key Pair Auth

Lives at `~/.dbt/profiles.yml`, outside the repo.
**Multiple profiles coexist in one file** — add a new block rather than overwriting.

```yaml
credit_stream:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: DLKDUTD-CI31254
      user: AFCAMACH
      private_key_path: /Users/anfelca2/.snowflake/rsa_key.p8
      role: ACCOUNTADMIN
      warehouse: COMPUTE_WH
      database: CREDIT_STREAM
      schema: dbt_andres
      threads: 8
```

**No `password:` field at all.** `private_key_path` replaces it — dbt reads the key,
signs a token, Snowflake verifies against the registered public key.

**Absolute path, not `~`.** Tilde expansion is the shell's job; dbt reads this file
directly.

**Back up before editing:**
```bash
cp ~/.dbt/profiles.yml ~/.dbt/profiles.yml.backup-$(date +%Y%m%d)
```

**The `profile:` key in `dbt_project.yml` must match the top-level key here.**
Mismatch is the most common `dbt debug` failure and the error doesn't make the cause
obvious.

**Schema should NOT be `raw`.** Raw is the immutable landing zone; dbt writes
elsewhere. Naming the dev schema after yourself (`dbt_andres`) is the convention —
on a team every developer gets their own so nobody clobbers anyone else.

---

## dbt_project.yml Config Worth Knowing

```yaml
models:
  credit_stream:
    +static_analysis: strict
    staging:
      +materialized: view
    marts:
      +materialized: table
```

**`+static_analysis: strict`** — a Fusion feature. Parses SQL and validates column
references and types against the real warehouse schema **at compile time**, before
executing. Catches a typo'd column in seconds instead of after a five-minute run.
One of the genuine advantages of the Rust engine.

**Staging as views, marts as tables** — staging models are thin transformations
queried rarely, so a view costs nothing to build. Marts are queried repeatedly, so
materializing pays off.

**Delete config for things you don't have.** The scaffold shipped a `seeds:` block
routing seeds into a `_raw` schema; with all seeds deleted it was dead config that
would also collide conceptually with the S3 landing zone.

---

## Packages

`dbt_utils` confirmed working on Fusion:
```bash
dbt deps
# Installed dbt-labs/dbt_utils: 1.4.1
```

Downloads into `dbt_packages/`, which is **gitignored** — packages are fetched, not
authored. `packages.yml` is the source of truth; anyone cloning runs `dbt deps`.

---

## dbt debug

```bash
cd ~/credit-stream/dbt
dbt debug
```

Checks the profile parses, credentials work, and warehouse/database/schema are
reachable. **First thing to run when anything dbt-related breaks** — it isolates
"can I connect at all?" from "is my SQL wrong?"

Failure causes, in order of likelihood:
1. YAML indentation slip in `profiles.yml`
2. `profile:` name mismatch between `dbt_project.yml` and `profiles.yml`
3. Wrong account identifier
4. Bad private key path


---

## Sources — Declaring What dbt Did Not Build

`models/staging/_sources.yml`:

```yaml
version: 2

sources:
  - name: raw
    description: Immutable landing zone. Loaded from S3, never modified in place.
    database: credit_stream
    schema: raw
    tables:
      - name: accepted_loans
        description: >
          Lending Club accepted loans, 2007 through 2018Q4.
          One row per loan, keyed on id.
```

Reference it in a model as `{{ source('raw', 'accepted_loans') }}`.

- `name: raw` is the **alias used in code**, not necessarily the schema name
- `database` and `schema` say where it actually lives
- `>` is YAML folded-block syntax for multi-line text joined into one line

**Leading underscore in the filename** (`_sources.yml`, `_stg_loans.yml`) sorts it to
the top of the folder. Convention for files that describe a folder rather than being
a model in it.

---

## Model Anatomy

```sql
with source as (

    select * from {{ source('raw', 'accepted_loans') }}

),

loans_only as (

    select * from source
    where try_cast(id as number) is not null

),

cleaned as (

    select
        id                                  as loan_id,
        try_cast(loan_amnt as number(12,2)) as loan_amount
    from loans_only

)

select * from cleaned
```

- **One CTE per logical step**, named for what it does
- Final `select * from <last_cte>` — makes the output obvious
- `{{ source(...) }}` is Jinja; dbt substitutes the real table name at compile time
- Compiled output lands in `target/compiled/` — worth reading once to see what dbt
  actually sent to the warehouse

**An unused CTE is a silent no-op.** Defining a filter step but leaving the next CTE
reading from the previous one compiles, runs, and reports success while changing
nothing. SQL does not warn about this.

---

## Tests

`models/staging/_stg_loans.yml`:

```yaml
version: 2

models:
  - name: stg_loans
    description: >
      Grain: one row per loan. Footer rows from the source CSVs are excluded.
    columns:
      - name: loan_id
        description: Natural key. Kept as text - never used in arithmetic.
        tests:
          - unique
          - not_null

      - name: term_months
        tests:
          - not_null
          - accepted_values:
              arguments:
                values: [36, 60]
```

**Note the `arguments:` nesting** under `accepted_values`. This works on Fusion.
Older tutorials show `values:` directly under the test name — if you copy from a
dbt-core 1.x example and it errors, this is why.

### The four generic tests

| Test | Asserts |
|---|---|
| `unique` | no duplicate values |
| `not_null` | no nulls |
| `accepted_values` | every value is in a given list |
| `relationships` | every value exists in another model column (foreign key) |

### What a test actually is

**A SQL query designed to return the failing rows.** Zero rows returned = the
assertion holds. That is the entire mechanism — nothing more magic than that.

### Test selection principles

- **`unique` + `not_null` on the key is the grain test** — the single most important
  test in any model. Catches junk rows returning and joins that fan out.
- **Test the columns that were broken before.** The footer rows had null amount,
  term, and issue date — so `not_null` on those three is a tripwire for their return.
- **`accepted_values` encodes domain knowledge.** Lending Club only issued 36- and
  60-month loans; a 48 means the source changed or the parsing broke.
- **Do not test what is legitimately nullable.** `employment_length_years` is null
  for ~6.5% of rows because borrowers did not report it. A `not_null` there would
  fail on correctly-handled data. The description carries the caveat instead.

---

## Commands Used

```bash
dbt parse                        # validate YAML and SQL structure, no connection
dbt run   --select stg_loans     # build one model
dbt test  --select stg_loans     # test one model
dbt build --select stg_loans     # run + test in dependency order  <- prefer this
```

**Always use `--select`.** `dbt run` with no selector rebuilds everything.

**Prefer `dbt build`** over `run` then `test`: build interleaves them, so a model
whose upstream test failed never gets built on bad data.

### Warnings that are fine

`UnusedResourceConfigPath` — `dbt_project.yml` declares config for `models.*.marts`
but no marts exist yet. Resolves itself when the folder has models in it.

`NoNodesForSelectionCriteria` — the selector matched nothing. Usually means the model
file is empty or was never saved.


---

## Seeds

Small static reference data loaded from CSV into a table.

```
dbt/seeds/state_regions.csv
```

```bash
dbt seed              # load seeds only
dbt build             # runs seeds, models, and tests together
```

Reference in a model with **`ref()`**, not `source()` — dbt built the table, so it is
part of the dependency graph:

```sql
select * from {{ ref('state_regions') }}
```

**When a seed is right:** small, static, human-maintained reference data that does not
exist in the source system. Version-controlled, diffs cleanly in a PR, editable by
someone who does not write SQL.

**When it is wrong:** anything large (50,000 rows belongs in a real source table), or
anything the source system already defines.

**A seed is not a dimension.** The seed is raw reference data; the dimension sits on
top of it, same as `stg_loans` sits on `raw.accepted_loans`.

**Seeds can carry tests** — declare them under a `seeds:` block in the YAML.

**Watch the root `.gitignore`.** A `*.csv` rule will silently exclude your seed from
version control.

---

## The relationships Test

```yaml
      - name: state_key
        tests:
          - relationships:
              arguments:
                to: ref('dim_geography')
                field: state_key
```

Asserts every value in this column exists in the target model's column. Under the
hood it is a left join filtered to nulls on the right — the permanent version of:

```sql
select l.state_code, count(*)
from stg_loans l
left join dim_geography g on l.state_code = g.state_key
where g.state_key is null
group by l.state_code;
```

**This is the test that makes a star schema trustworthy.** Without it, a key pointing
at a missing dimension row means those facts silently vanish from any inner join, or
produce nulls on a left join. Nobody notices until a number is wrong in a dashboard.

**Nulls are ignored by design** — a nullable FK like `last_payment_date_key` passes as
long as its non-null values all resolve.

---

## Selectors

| Selector | Means |
|---|---|
| `--select model_name` | just that model |
| `--select +model_name` | that model **and everything upstream** |
| `--select model_name+` | that model **and everything downstream** |
| `--select +model_name+` | the full lineage both directions |
| `--select folder_name` | everything in that folder |
| `--select a b` | multiple resources, space-separated |

`+model` is better than listing dependencies by hand — it cannot go stale when you add
an upstream model later.

**`stg_loans+` is the one to use after changing staging** — it rebuilds every
dimension and fact that depends on it.

---

## dbt build Stops on Failure

When a model fails, `dbt build` **skips** its tests and every downstream model:

```
 Failed  [ 2.07s] model dim_loan_status
 Skipped [------] test 'unique_dim_loan_status_loan_status_key' and 8 others
 Skipped [------] model fct_loans
```

`dbt run` followed by `dbt test` would have built everything on bad data first and
told you afterward. **This is the argument for `build` over `run` + `test`.**

---

## dbt clean

```bash
dbt clean     # deletes target/ and dbt_packages/
dbt deps      # reinstall packages - clean removed them
```

**When you need it:** Fusion caches the warehouse schema for static analysis. After
adding a column to an upstream model you can get:

```
[UnresolvedIdentifier (dbt0227)]: No column MEETS_CREDIT_POLICY found in the
locally cached schema for the source in CREDIT_STREAM.RAW.ACCEPTED_LOANS
It is likely that this cache needs to be refreshed by running: dbt clean
```

Note it resolves the reference all the way back to the **source table**, not just the
immediate parent — that is static analysis tracing the full lineage before executing
anything.

**Always `dbt deps` after `dbt clean`**, or the next build fails on a missing package.

**Rule out a missing save first.** The same error appears if the upstream edit never
made it to disk:

```bash
grep meets_credit_policy models/staging/stg_loans.sql
```

---

## Role-Playing Dimensions in Practice

Three keys on the fact, all referencing `dim_date`:

```sql
        cast(to_char(l.issued_at, 'YYYYMMDD') as integer)  as issued_date_key,
        cast(to_char(l.last_payment_at, 'YYYYMMDD') as integer)
                                                           as last_payment_date_key,
        cast(to_char(l.last_credit_pull_at, 'YYYYMMDD') as integer)
                                                           as last_credit_pull_date_key,
```

Each gets its own `relationships` test. Downstream, join `dim_date` three times with
different aliases.

---

## The Save-Before-Build Trap

Recurring failure mode in this project:

```bash
touch models/marts/_fct_loans.yml
code models/marts/_fct_loans.yml
dbt build --select fct_loans      # <- runs against the still-empty file
```

Result: `1 model | 0 tests`. The build succeeded and tested nothing.

**Tell:** the summary says 0 tests when you just wrote a YAML file.
**Check:** `wc -l models/marts/_fct_loans.yml` — a `0` means empty.
**Habit:** VS Code shows a filled dot instead of an X on tabs with unsaved changes.


---

## Documentation

```bash
dbt docs generate     # compile descriptions, tests, and lineage into a site
dbt docs serve        # local web server, Ctrl+C to stop
```

Output lands in `target/`. It is a **static site** — no server logic — so it can be
hosted anywhere that serves files.

**The descriptions in your `.yml` files are what populate it.** Writing a real
description on every model and column is not busywork; it is the documentation site.

**Publishing to GitHub Pages:**

1. Repo → Settings → Pages → Source: **GitHub Actions** (not "Deploy from a branch")
2. A workflow that runs `dbt docs generate`, then `actions/upload-pages-artifact`
   pointed at `dbt/target`, then `actions/deploy-pages`

**The `permissions:` block is the part most people miss:**
```yaml
permissions:
  contents: read
  pages: write
  id-token: write
```
Without `pages: write` and `id-token: write` the deploy step fails.

**Trigger on push to `main`, not on pull requests** — docs should reflect what is
merged.

**Caveat:** publishing `target/` exposes compiled SQL and any stored test failures
alongside the docs. Not sensitive in this project, but worth knowing before pointing
it at a corporate warehouse.

**Two workflows, different triggers:** `dbt_ci.yml` runs on PRs and gates merges;
`dbt_docs.yml` runs on push to `main` and publishes. Same secrets, same setup steps,
different jobs.

---

## When Incremental Is Wrong

Incremental materialization exists so you do not reprocess data that has not changed.

**`fct_loans` is deliberately not incremental.** The source is a static historical file
that will never receive another row. An incremental model there would carry
`is_incremental()` logic that no run ever exercises — a pattern added because it is
expected rather than because the problem calls for it.

**Incremental belongs on the payment fact**, where events genuinely arrive over time,
accumulate, and should not be reprocessed from scratch.

**Same judgment as dropping `dim_loan_grade`.** Being able to say why you did *not*
use a pattern is worth more than using it everywhere.
