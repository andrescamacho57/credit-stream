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
