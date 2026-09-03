# credit-stream — Concepts Reference

Running glossary of what I've learned building this project.
Terminal commands live separately in `UNIX_COMMANDS.md`.
Updated each session.

---

## How a Computer Works

**CPU** — does the calculating. Everything else exists to feed it.

**RAM (memory)** — fast, small, **wiped on power-off**. Where a program's active
data lives while it runs.

**Disk (SSD/HDD)** — slow, large, **permanent**. Where files live.

**Cache** — tiny and even faster than RAM, sitting on the CPU itself. Holds what
the CPU is about to need. You rarely manage it directly.

**The analogy:** RAM is your desk — grab anything instantly, but it only holds so
much. Disk is the filing cabinet — holds everything, slower to fetch from. The CPU
can only work on what's on the desk.

**Rough speed gap:** RAM is ~100x faster than even a fast SSD. That gap is why
"does it fit in memory?" determines so much about how data tools are designed.

**"To disk"** — written as a real file on the drive, vs. living only in memory or
streaming through a pipe. `gunzip file.gz` writes 1.5GB to disk.
`gzcat file.gz | head -3` never does — a few lines pass through memory and vanish.

### Why this matters for data engineering

**"Does it fit in memory?" is the recurring question.** `pandas` loads an entire
dataset into RAM: a 1.5GB CSV on a 16GB laptop is fine, a 50GB one crashes.

Snowflake and Spark exist precisely because real data doesn't fit. They split work
across many machines and spill to disk when memory runs out. That's the whole
reason a warehouse is a different thing from a laptop with a big CSV.

**Streaming vs loading** is the same idea at small scale. A pipe processes a few
lines at a time and forgets them. Loading holds everything at once. Streaming
scales to any file size; loading is capped by RAM.

---

## Cloud & Infrastructure

**AWS (Amazon Web Services)** — rents infrastructure by the hour instead of buying
servers. ~200 services; this project uses two: S3 and IAM.

**S3 (Simple Storage Service)** — object storage. Put files in, get files out by
name. Not a database: no querying, no schema, no in-place updates.

**Bucket** — top-level S3 container. Names are globally unique across all of AWS.

**Object** — one file in S3, identified by a **key** (its full path-like name).

**S3 has no real folders.** Every object is a flat key. The console renders
`raw/lending_club/file.csv` as nested folders by splitting on `/`, but the object's
actual name is that whole string. "Create folder" writes a zero-byte object ending
in `/` just so the UI has something to show.

**Prefix** — the leading part of a key. Stages and filters match on prefixes, not
directory traversal. `raw/` means "every key starting with raw/".

**Prefix convention used here:** `<layer>/<source>/<file>`, e.g.
`raw/lending_club/accepted_2007_to_2018Q4.csv.gz`. A date level
(`raw/lending_club/2026-07-23/`) matters for *recurring* loads where each run drops
a new file and history is never overwritten. Skipped here because this is a
one-time historical dump.

**Egress** — the charge for moving data OUT of a cloud provider's network
(~$0.09/GB on AWS). Ingress is usually free. Why you co-locate storage and compute.

**Region** — physical data center location (e.g. `us-east-2` = Ohio). Snowflake
accounts are pinned to a cloud + region at creation and can't be moved.

---

## Identity & Access (IAM)

**IAM (Identity and Access Management)** — AWS's permission system. Founding rule:
**deny by default**. Nothing can touch anything unless explicitly allowed.

**IAM user** — permanent identity with long-lived credentials (access key + secret).
Never expires — which is the problem.

**IAM role** — a set of permissions with NO permanent credentials. Something
*assumes* the role and gets credentials that expire in ~1 hour.

**Why role, not user:** with a user, the secret ends up in a config file, a
screenshot, a commit, a log — and never rotates. With a role, Snowflake stores no
secret at all. Nothing durable to leak.

**Every role has two policies:**
- **Trust policy** — *who* may assume this role
- **Permissions policy** — *what* they can do once they have

**ARN (Amazon Resource Name)** — globally unique ID for any AWS resource.
Format: `arn:aws:service:region:account-id:resource`.

**STS (Security Token Service)** — issues the temporary credentials when a role is
assumed.

**External ID** — a shared secret in the trust policy. Prevents the **confused
deputy problem**: Snowflake serves thousands of customers from one AWS principal,
so without it, anyone who guessed your role ARN could have Snowflake assume it on
their behalf.

**Least privilege** — grant the minimum, add more only when a real need appears.
This project's policy has `GetObject` + `ListBucket` and deliberately no
`PutObject` or `DeleteObject`.

**Two kinds of S3 permission, easy to confuse:**
- Object-level (`GetObject`) — reading file contents. ARN ends in `/*`.
- Bucket-level (`ListBucket`) — discovering what files exist. ARN has no `/*`.

`GetObject` without `ListBucket` = Snowflake can read a file if it already knows the
exact name, but can't discover files by prefix, so `COPY INTO` finds nothing.

---

## Git & Version Control

**Git is distributed** — the repo on your laptop is complete and functional on its
own. GitHub isn't the "real" one; they're peers that happen to sync.

**Remote** — a copy of your repo living elsewhere. `origin` is the default nickname
Git assigns when you clone.

### The four locations

```
working directory  →  staging area  →  local repo  →  remote (GitHub)
     (git add)        (git commit)     (git push)
```

- **Working directory** — your live files. The only place you actually edit.
- **Staging area** — a *snapshot of file contents* frozen when you ran `git add`.
  Not files you can open.
- **Local repo** — committed history, on your machine, still private.
- **Remote** — GitHub.

**You never edit "in" the staging area.** If you `git add file` and then edit that
file again, you have two versions in flight — the staged snapshot and newer
unstaged changes. `git status` lists the same file under *both* "Changes to be
committed" and "Changes not staged." Surprises everyone once.

**Why staging exists:** it lets you *compose* a commit. Changed five files — two
are a bug fix, three are a feature? Stage and commit the two, then the three. Two
clean reviewable commits instead of one grab-bag.

**Once committed, that snapshot is history.** Normal practice is a *new* commit for
further changes, not editing an old one. Git history is append-only in day-to-day
use — which is exactly why a committed secret is so hard to remove.

**Untracked vs modified** — untracked means Git has never seen this file. Modified
means it's tracked and has changed since the last commit.

**Git counts in lines, not files.** "4 insertions, 1 deletion" means lines; an edit
is recorded as a deletion plus an insertion.

**`.gitignore`** — patterns Git refuses to track. The most important file in a
portfolio repo: a committed secret lives in history forever, in every clone, even
after you delete the file. `!` negates a pattern.

**Git doesn't track empty directories.** A folder appears only once it has a file.

**What belongs out of a public portfolio repo:** credentials obviously, but also
data files, and anything that reads oddly to a recruiter browsing it — interview
prep notes included.

---

## Operating Systems & the Shell

**Operating system** — the layer between programs and physical hardware. Manages
disk, memory, scheduling, network. The traffic controller.

**Unix** — an OS design from Bell Labs, 1970s. Philosophy: small tools that each do
one thing, connected by pipes, everything as text streams.

**Linux** — free OS built on Unix's design in the 1990s. Runs essentially all cloud
servers: Snowflake compute, S3 backend, CI runners.

**macOS is also Unix-based** — same lineage. That's why terminal skills transfer
unchanged to any server you'll touch.

**Shell / terminal** — a program that runs other programs. VS Code has one built in;
macOS Terminal is standalone. Same thing.

**CLI (Command Line Interface)** — a specific program you run inside a shell. `git`
is a CLI. Distinct from a GUI plugin like the VS Code Snowflake extension.

**Three ways to run SQL here:** web worksheet (browser), VS Code extension (GUI
plugin), CLI (shell program). The extension is the best habit — the file that runs
is the file in Git, so there's no drift between version control and what executed.

---

## Compression

**gzip ("GNU zip")** — compression program. The `g` is GNU, the free-software
project that wrote it.

**`.csv.gz`** reads right-to-left: a CSV, then gzipped.

**Snowflake reads `.gz` natively** — compression stays on all the way to the
warehouse. Less to upload, less to store.

---

## Parallelism

**Thread** — one worker doing one sequence of tasks.

**Parallelize** — split work across multiple workers to finish faster.

**Analogy:** 800 boxes into a truck. One mover takes all day; eight movers take an
eighth of the time.

**Snowflake's unit of load work is a FILE.** Each thread grabs one file. 16 files
with 8 threads = 8 load at once, then the next 8.

**Why gzip breaks this:** gzip decompresses sequentially — decoding the middle
requires having decoded everything before it. So one `.gz` file = one thread, no
matter how big the warehouse.

**Analogy:** the 800 boxes are welded into one steel crate. Eight movers can't
help; only one can drag it.

**The fix:** split into multiple files, ~100–250MB compressed each.

**When NOT to fix it:** a one-time backfill where splitting costs more time than it
saves. Knowing when the usual lever doesn't apply is worth more than applying it
reflexively.

---

## Data Warehouse Layers

**Raw** — exactly as it arrived. No edits, ever. Answers "what did the source
actually say?" All VARCHAR so a load can never fail on a type mismatch.

**Staging** — one model per source table. Cleaned but not reshaped: cast types, fix
`" 36 months"` → `36`, rename to consistent conventions. Still one row per source
row.

**Marts** — reshaped for business questions. Star schema: **fact** tables at a
defined grain (one row per loan, one row per payment) surrounded by **dimension**
tables of descriptive attributes.

**A mart is a contract:** this table has this grain, these tested keys, these
definitions. Everything upstream is plumbing.

---

## Snowflake Objects

**Storage integration** — account-level object holding the AWS role ARN and allowed
locations. No credentials stored. `STORAGE_ALLOWED_LOCATIONS` whitelists buckets, so
no stage using it can point elsewhere — a second layer of least privilege,
independent of the AWS policy.

**Stage** — a schema-level named pointer to a storage location plus how to
authenticate to it. Lets `COPY INTO` say `@my_stage` instead of repeating the bucket
path and auth every time.

**File format object** — named, stored parsing rules. Snowflake can't infer from a
`.csv` extension where a row ends or what separates fields. Naming it means every
load parses identically, a rule change is one edit, and it lives in version control
as a real object instead of a string buried in a `COPY` statement.

Key settings used here:
- `SKIP_HEADER = 1` — don't load the header row as data
- `FIELD_OPTIONALLY_ENCLOSED_BY = '"'` — honor CSV quoting
- `COMPRESSION = AUTO` — detect gzip from the extension
- `NULL_IF` / `EMPTY_FIELD_AS_NULL` — map placeholder strings to real NULL

**Why quoting matters:** CSV separates fields with commas, but free-text columns
contain commas. The convention is to wrap those fields in double quotes so the
commas inside are data, not delimiters. Snowflake only honors that if told to.
Same setting handles embedded newlines inside quoted fields. **This is the single
most common cause of CSV load failures.**

**`LIST @stage`** — enumerate files at that location. Exercises `ListBucket` only,
not `GetObject`.

**`COPY INTO`** — load files from a stage into a table.

**Account-level vs schema-level:** a storage integration lives outside any database;
a stage or file format lives inside a schema, like a table.

---

## Testing & Debugging

**Smoke test** — from hardware: power on a new board and see if smoke comes out. A
minimal end-to-end check that the basic path works before investing in the real
thing.

**Empty result ≠ error.** Different diagnoses:
- **Empty** — "I looked and found nothing." The plumbing works.
- **Error** — "I couldn't look." The plumbing is broken.

Check which one you got before assuming what's wrong.

**IAM changes take up to ~2 minutes to propagate.** Wait 60s and retry before
concluding something is broken.

**When a command fails in a way that makes no sense, retype it by hand.** Pasted
text can carry invisible non-breaking spaces that break argument parsing.

**Generated code needs a human check at the seams.** The 151-column generator
appended a comma to every line, including the last — where it's a syntax error.

---

## Working Practice

**Infrastructure defined in a UI is invisible and unreproducible.** Setup SQL
belongs in version control, not a browser worksheet.

**Git is for code, object storage is for data.** Repos bloated with CSVs are a
portfolio smell. GitHub rejects files >100MB anyway.

**Small test payload first, real data second.** Debugging a broken integration
against 374MB means minutes per attempt.

**Nobody hand-writes wide DDL.** Generate schema from the source's own header, then
review the seams.

---

## About This Dataset

**Lending Club accepted loans, 2007–2018Q4.** 374MB gzipped (~1.5GB raw),
2,260,701 data rows, 151 columns.

**Grain: one row per loan.** `id` is the key — `member_id` is almost entirely null.

**No payment-level grain exists.** `last_pymnt_d`, `total_pymnt`, `out_prncp` are
aggregates or last-value snapshots. Payment history is collapsed into totals.

**This is the architectural justification for the stream layer.** The batch source
gives the loan book — who borrowed, terms, risk grade, status. The simulated payment
stream supplies the transaction-level grain the batch source lacks. The anomaly view
joins them: stream detects the behavior, batch supplies borrower context.

**Known messiness for the staging layer:** `emp_length` as `"10+ years"`, `term` as
`" 36 months"` with a leading space, dates as `"Dec-2018"`, columns that are almost
entirely null, and `desc` as free text with embedded commas and newlines.

**Already cleaned by the uploader:** `int_rate` and `revol_util` had percent signs
stripped and were converted to floats — so that particular mess isn't present.

---

## Compiled vs Interpreted (and why dbt changed)

**Interpreted language (Python):** the source code is read and executed line by line
at runtime by an interpreter. To run a Python program you need Python installed,
plus the program's packages, plus all of *their* dependencies. Those dependencies
can collide between projects — which is the entire reason virtual environments exist.

**Compiled language (Rust, Go, C):** source is translated ahead of time into machine
code the CPU runs directly. The result is a **binary** — one self-contained
executable file with everything baked in.

**Why this mattered here:** dbt-core 1.x is Python — `pip install`, virtualenv,
dependency management. dbt Fusion is a Rust binary — one file downloaded to
`~/.local/bin/dbt`, no Python involved. dbt Labs rewrote it because Python's startup
and project-parsing time was the bottleneck on large projects.

**Rule of thumb:** compiled = faster and self-contained but must be built per
platform. Interpreted = slower and needs a runtime but is easier to modify and ship.

---

## Adapters

dbt models are written generically, but **every warehouse speaks a different SQL
dialect.** Creating a table, merging rows, casting types, handling dates — Snowflake,
BigQuery, Postgres, and Databricks all differ.

An **adapter** is the translation layer: it knows how to *connect* to a specific
warehouse and how to *emit valid SQL* for it.

- dbt-core 1.x: installed separately (`pip install dbt-snowflake`)
- dbt Fusion: compiled into the binary, including the database driver and a SQL
  dialect parser

Same idea appears everywhere — a database driver, an ODBC/JDBC connector, a cloud
SDK. A generic interface plus a vendor-specific implementation behind it.

---

## YAML

**YAML** — a human-readable format for configuration and structured data.

```yaml
# Comments start with a hash.
models:
  - name: stg_loans           # a list item, marked with -
    description: Cleaned loans
    columns:
      - name: loan_id
        tests:
          - unique
          - not_null
```

- **Indentation defines nesting**, like Python
- `key: value` pairs
- `-` marks list items
- `#` for comments

**The one unbreakable rule: spaces only, never tabs.** A tab produces a parse error
that does not mention tabs. Everyone hits this once.

**Why YAML over JSON for config:** YAML allows comments and is far less
punctuation-heavy. JSON is better for machine-to-machine data exchange.

---

## Public Key Cryptography

**The one-line version:** a digital ID card that proves who you are without sending
a password.

You generate a matched **key pair**:
- **Private key** — stays on your machine forever. The secret.
- **Public key** — handed to the service. Not secret at all.

Anything signed by the private key can be verified with the public key, but the
public key cannot produce a signature. So the service can confirm "this connection
holds the matching private key" without ever possessing it.

**The wax seal analogy:** you keep the stamp. The service keeps a picture of what
the stamp's impression looks like. Anyone can verify the seal; only you can make one.

**Why it beats passwords for automation:**
- Nothing secret crosses the network — it can't be intercepted in transit
- The service never stores anything that could be stolen and reused
- **A CI runner cannot type an MFA code.** Key pair is how automated pipelines
  authenticate.

**Fingerprint** — a short hash of a public key (`RSA_PUBLIC_KEY_FP` in Snowflake).
Public keys are long; a fingerprint is short enough to eyeball when checking "is this
the key I think it is?"

**RSA** — the algorithm. 2048 bits is the current standard minimum key size.

**PKCS#8** — a standard file format for private keys. Snowflake requires it, which is
why the key generation pipes through `openssl pkcs8`.

**Passphrase tradeoff:** encrypting the private key with a passphrase adds a second
secret you'd then have to store somewhere anyway. For automated service access, the
standard pattern is an unencrypted key plus strict file permissions.

---

## File Permissions

Unix files carry permissions for three audiences: **owner**, **group**, **everyone
else**. Each gets read (4), write (2), execute (1), summed into a digit.

| Mode | Means | Used for |
|---|---|---|
| `600` | owner read+write, nobody else anything | private keys, secrets |
| `644` | owner read+write, everyone else read | normal files, public keys |
| `755` | owner all, everyone else read+execute | folders, programs |

`ls -l` shows them as `-rw-------` (600) or `-rw-r--r--` (644).

**Some tools refuse to use a key file with permissions looser than 600.** That's a
feature — it stops you from accidentally leaving a credential world-readable.

---

## Hidden Config Directories

A **leading dot makes a file or folder hidden** on Unix — `ls` skips it unless you
pass `-a`.

By convention, tools store their settings in `~/.toolname/`:
- `~/.dbt/` — dbt profiles and licenses
- `~/.snowflake/` — Snowflake CLI config, keys
- `~/.zshrc` — shell configuration
- `~/.gitconfig` — Git identity

**Credentials live here, outside any repo.** That's the point: config that varies per
machine and contains secrets should never sit next to code that gets shared.

---

## Credential Hygiene

**How credentials actually leak:** not dramatic breaches. Ordinary copy-paste — a
config file pasted into Slack, a screenshot attached to a ticket, a `.env` committed
by reflex, a password read aloud in a screen share.

**Habits that prevent it:**
- `cat` a config file and *look* before pasting it anywhere
- Prefer key pair or environment variables over passwords in files
- `.gitignore` secrets **before** the first `git add`, not after
- Treat any credential that has been pasted anywhere as burned — rotate it
- A committed secret lives in Git history forever, in every clone, even after the
  file is deleted

**Why key pair sidesteps this entirely:** there is no secret a human ever needs to
read, copy, or transmit. The private key stays on disk and is used by tools, not
people.

---

## Contracts and Grain

**A contract is a promise about your output that others can rely on without reading
your code.**

`stg_loans` promises: one row per loan, `loan_id` unique and never null,
`term_months` is an integer, `issued_at` is a real date. Anything built downstream
depends on those promises holding.

Same idea as an API contract or a function signature — the implementation can change
freely, the promise cannot.

**Grain** — what one row represents. "One row per loan." "One row per payment."
"One row per customer per month." **This is the single most important thing to state
about any table**, and the first question to ask about someone else's.

Getting grain wrong is how you get silently-double-counted revenue. A join that
fans out changes the grain without announcing it.

**A comment saying "one row per loan" is a hope. A `unique` test on the key is
enforcement.** Tests are what make a contract real — they fail the build when the
promise breaks.

---

## Green Pipeline ≠ Correct Data

**The most important lesson from this project so far.**

The Lending Club load ran clean: 2,260,701 rows parsed, 2,260,701 loaded, zero
rejected, all casts succeeded. Every dbt model built successfully.

**33 of those rows were not loans.** Lending Club appends a summary footer to each
quarterly CSV — `Total amount funded in policy code 2: 81866225`. Concatenating the
quarterly files carried the footers in as data rows. The footer text landed in the
`id` column and every other field parsed as null.

Nothing errored. Nothing warned. The row count was inflated, every average over a
nullable column was shifted, and any `COUNT(*)` downstream would have been wrong.

**It was only found by explicitly checking.**

**The general lesson:** tooling verifies that operations *completed*, not that
results are *correct*. Correctness has to be asserted separately — by you, in tests.

---

## Verifying a Load Actually Worked

**`count(*)` vs `count(column)`** — `count(*)` counts rows; `count(some_column)`
counts rows where that column is **not null**. The gap between them is the null
count, with no `WHERE` clause needed.

**The technique:** run the same counts on the source and on the transformed model,
then compare column by column.

```sql
-- on the model
select count(*), count(loan_amount), count(term_months) from stg_loans;
-- on the source
select count(*), count(loan_amnt), count(term) from raw.accepted_loans;
```

Matching numbers mean the transformation destroyed nothing. A gap separates "was
already null in the source" from "my cast silently broke it" — two very different
problems that look identical if you only inspect the output.

**`count_if(condition)`** — counts rows where a condition is true. Cleaner than
`sum(case when ... then 1 else 0 end)`.

**Always measure a filter's blast radius before applying it.** Confirm the count it
removes matches the count you expect to remove. If it's larger, there's a category
of data you haven't looked at.

---

## try_cast vs cast

**`cast`** errors on the first bad value and kills the query.
**`try_cast`** returns null instead.

**In a staging layer, prefer `try_cast`** — you want the model to survive one
malformed row rather than blocking everything.

**But `try_cast` fails silently**, which is its own risk: it can quietly null out a
column and still report success. The discipline is **permissive casting plus a test
that catches what slipped through**. Belt and suspenders.

---

## Filtering on Meaning, Not Symptoms

Three ways to remove the footer rows:

| Filter | Filters on | Problem |
|---|---|---|
| `where loan_amnt is not null` | a **symptom** | drops a real loan that happened to lack an amount |
| `where id not like 'Total amount%'` | a **literal string** | breaks silently if the wording changes |
| `where try_cast(id as number) is not null` | the **grain definition** | ✓ |

The third encodes what you actually mean — "a loan is keyed by a numeric id" — so it
catches future junk regardless of its wording.

**General principle: filter on the definition of what belongs, not on a
characteristic of what doesn't.**

---

## CTEs and Model Structure

**CTE (Common Table Expression)** — a named subquery defined with `with`.

dbt convention is one CTE per logical step, named for what it does:

```sql
with source as (...),        -- pull it in
loans_only as (...),         -- filter to the grain
cleaned as (...)             -- cast and rename
select * from cleaned
```

A reader follows the pipeline top to bottom without holding nested subqueries in
their head. Overkill for two steps; stops being overkill fast.

**Warning — an unused CTE is a silent no-op.** Defining `loans_only` but leaving the
next CTE reading `from source` compiles fine, runs fine, reports success, and changes
nothing. SQL does not warn about unused CTEs. If a change appears to have no effect,
check that the new step is actually wired into the chain.

---

## Display Values vs Analytical Values

The value you *compute with* and the value you *show a human* are different things
and belong in different layers.

`emp_length` in the source is bucketed text: `'< 1 year'`, `'10+ years'`.

- **Staging** produces the analytical value — `0` and `10` — because these get
  filtered, compared, and averaged.
- **Marts or the dashboard** produce the display value — `'< 1 year'` — because
  that's a presentation concern.

**Name the cost when you make this choice.** Mapping `'< 1 year'` to 0 biases average
tenure slightly low, since everyone under 12 months contributes zero. Using 0.5 as a
midpoint would invent precision the source never had. Document the decision in the
model and in the column description so nobody downstream mistakes a bucket boundary
for a measurement.

**Put the unit in the column name.** `interest_rate_pct` = 13.56 means 13.56%.
Ambiguous units cause real bugs and naming them away costs nothing.

---

## Sources in dbt

Declaring a raw table as a **source** rather than hardcoding its name buys five things:

1. **Lineage** — dbt builds its dependency graph from `ref()` and `source()` calls.
   A hardcoded table name is invisible; the model appears to come from nowhere.
2. **One place to change** — if the raw schema moves, edit one YAML file.
3. **Testing at the boundary** — bad data gets caught entering the project, not three
   models downstream.
4. **Freshness checks** — `dbt source freshness` can flag stale tables.
5. **Semantic clarity** — `source()` means "arrived from outside." `ref()` means
   "dbt built this." That distinction *is* the boundary between raw and everything
   after it.


---

## Star Schema

**The division of labor:**

| | Dimensions | Fact |
|---|---|---|
| Row count | tiny (9–7,670) | huge (2.26M) |
| Content | descriptive text | numbers and keys |
| Changes | rarely | constantly |
| Answers | "what are the options?" | "what happened?" |

**Why it beats one wide table:** the definition of "West region" lives in one row
instead of 800,000 copies. Change it once, everything downstream is consistent. And
`group by census_region` replaces a 51-branch CASE statement.

**Why it is called a star:** fact in the middle, dimensions radiating out, every
dimension exactly one hop from center. No dimension joins to another dimension.

**Build dimensions first.** The fact carries foreign keys pointing into them — you
cannot test that a key resolves if the target does not exist yet.

**Cardinality** — the number of distinct values in a column. `grade` has cardinality
7. `loan_id` has cardinality 2,260,668, one per row, which is what makes it a key.
Low cardinality suggests a dimension candidate; cardinality equal to row count means
it is an identifier.

---

## Does This Column Earn a Dimension Table?

The textbook move is to dimension every low-cardinality attribute. **That is usually
wrong.** A 3-row table whose only column is the value itself is a join you pay for to
retrieve a string you already had.

**The test is not "is cardinality low?" It is "does this table carry information the
fact table does not already have?"**

Three answers to the same question in this project:

| Dimension | Verdict | Why |
|---|---|---|
| `dim_geography` | **build** | adds region and division — an entire rollup level the source lacks |
| `dim_loan_status` | **build** | ordinal severity enables roll-rate analysis and range filters |
| `dim_purpose` | **build** | category rollup (79.4% of the book collapses to one group) plus a small-business flag |
| `dim_loan_grade` | **drop** | `left(sub_grade, 1)` is not a dimension |

Same question asked four times, different answers with stated reasons. More convincing
than a schema where every low-cardinality column got a table.

**Degenerate dimension** — a descriptive attribute kept on the fact table with no
dimension behind it. Classic example is an invoice number: dimensional in nature, but
it has no attributes of its own so there is nothing to join to. Here:
`grade`, `sub_grade`, `home_ownership`, `verification_status`, `application_type`.

---

## Surrogate vs Natural Keys

**Natural key** — a value that already identifies the row. `CA` for California.
**Surrogate key** — a generated substitute, usually a hash or integer.

**Use a natural key when it is already unique, stable, and readable.**
`dim_geography` uses `state_code` directly. A surrogate there would add a lookup step
to retrieve a value you already had.

**Use a surrogate when the natural key is multiple columns.** `dim_loan_status` needs
one, because after splitting policy status the natural key is
`(loan_status, meets_credit_policy)` — `Fully Paid` appears twice. Without a surrogate
every downstream join needs two conditions.

```sql
{{ dbt_utils.generate_surrogate_key(['loan_status', 'meets_credit_policy']) }}
```

**`dim_date` uses an integer `YYYYMMDD`.** Not for speed — a Snowflake `DATE` is
already stored as an integer internally, so joining on a date is not string matching.
The real arguments are convention (anyone reading the schema recognizes it) and
readability inside the fact table. The cost: no arithmetic on the key, so the
dimension also carries the real date.

**Knowing when NOT to use a surrogate is the more valuable half.**

---

## Role-Playing Dimensions

One physical dimension referenced multiple times for different purposes.

`fct_loans` carries `issued_date_key`, `last_payment_date_key`, and
`last_credit_pull_date_key` — all pointing at `dim_date`. Downstream you join three
times with different aliases.

**Carry all the role keys you have.** You can ignore a column later; you cannot join
to a date you never carried.

**Conformed dimension** — one shared by multiple fact tables. `dim_date` is the
canonical example, which is why it was generated as a full daily calendar rather than
derived from loan issue dates. Loans were issued monthly, but payment events land on
arbitrary days. A dimension serving only one fact table is a lookup table with
delusions.

---

## Seed vs Derived Dimension

**The question is where the domain is defined.**

**Seed** — when the domain is **externally defined**. 51 states exist whether or not
you have loans in them. A state with zero loans still belongs in the dimension, or
"loans by region" silently omits it from the denominator.

**Derived from source** (`select distinct`) — when the domain **is whatever the source
system emits**. Loan status has no external authority. A seed would silently drift
from reality as the source adds statuses.

**The tripwire for derived dimensions:** `not_null` on the mapped column. If a new
status appears and falls through the CASE, it comes back null and fails the build
instead of quietly landing in a mart.

**Seeds also get tests.** A seed is hand-maintained, so a human can typo it. A
duplicate `CA` caught at the seed is a duplicate that never fans out the fact table.

---

## One Column, Two Facts

Lending Club encodes two independent facts in one string:

```
"Does not meet the credit policy. Status:Charged Off"
```

That is a status **plus** a policy exception. Left as-is, every "what is my charge-off
rate" query has to remember two strings. Someone forgets, and the number is quietly
wrong.

**Split it.** `loan_status` + `meets_credit_policy` as separate columns. Now
`where loan_status = 'Charged Off'` catches all 269,320 instead of missing 761.

**General principle: when a source value encodes two facts, split it into two
columns.**

**And split it in the right layer.** The first version of this project normalized in
the dimension, which forced `fct_loans` to reconstruct the original string just to
join:

```sql
-- the smell
on l.loan_status = case when s.meets_credit_policy then s.loan_status
                        else 'Does not meet the credit policy. Status:' || s.loan_status end
```

Moving the split into `stg_loans` made the join two equality conditions. **An ugly
join usually means the transformation happened in the wrong layer.**

---

## Refactoring

**A refactor changes structure, not behavior.** After moving the status split from the
dimension into staging, the verification was running the same grain check as before:

```sql
select count(*), count(distinct loan_id), count_if(loan_status_key is null)
from fct_loans;
```

Same three numbers before and after = behavior preserved. **If the numbers change, it
was not a refactor.**

---

## Two CTE Failure Modes

**Unused CTE — silent.** Define `loans_only` but leave the next CTE reading
`from source`. Compiles, runs, reports success, changes nothing. SQL does not warn
about unused CTEs.

**Undefined CTE — loud.** Reference `from normalized` after deleting that CTE.
Immediate `Table 'NORMALIZED' not found`.

**Loud is better.** SQL only warns you in one of these two directions, which is why
the unused CTE is the more dangerous mistake. If a change appears to have had no
effect, check that the new step is actually wired into the chain.


---

## CI/CD

**CI (Continuous Integration)** — every push triggers an automated build and test run,
so breakage is caught before it reaches the main branch.

**CD (Continuous Deployment)** — if CI passes, the change deploys automatically.

This project has CI only. CD would mean auto-running dbt against a production schema
on merge.

**What actually changes is WHEN problems are caught.** Before: after committing, if you
remember to run a build. After: automatically, on the branch, before anything merges.
`main` becomes a place where tests are *known* to pass rather than assumed to.

**GitHub Actions** — GitHub's automation service. It watches the repo for events, reads
workflow files from `.github/workflows/`, and executes them.

**Workflow** — a YAML file describing triggers and steps. The recipe.

**Runner** — the machine that executes the steps. GitHub provides them free, spins one
up per run, destroys it after.

**VM (virtual machine)** — software pretending to be a computer. One physical server
hosts many isolated VMs, each with its own OS and filesystem, unaware of the others.

**Nothing persists between runs.** A fresh Ubuntu VM has no dbt, no `profiles.yml`, no
private key. The workflow installs and writes all of it every time — which is also why
CI is a genuine test of reproducibility.

---

## Branches and Pull Requests

**A branch is a separate line of commits.** Creating one gives you a pointer starting
at the same place as `main` that then moves independently.

**The point:** build something half-finished, commit to it repeatedly, and `main` stays
untouched and working. If the idea turns out badly, delete the branch — nothing was
harmed.

**Why it is the standard workflow:** `main` is what gets deployed, what others clone,
what CI protects. You do not experiment there.

```
branch → commit → push → open PR → CI runs → review → merge → delete branch
```

**Pull request** — a request to merge one branch into another, plus a place for CI
results and review discussion. Pushing to a branch with an open PR **automatically
re-runs CI**.

**A PR description explains WHY.** The diff already shows what.

**Naming convention:** `feature/`, `fix/`, `chore/` prefixes.

---

## Secrets

Credentials cannot live in a workflow file — it is committed to a public repository.

**GitHub Secrets** are encrypted values stored on the repo. A workflow references one
with `${{ secrets.NAME }}`; the value is masked in logs and cannot be read back out,
even by you.

Used here: `SNOWFLAKE_ACCOUNT`, `SNOWFLAKE_USER`, `SNOWFLAKE_ROLE`, and
`SNOWFLAKE_PRIVATE_KEY`.

**This is where key pair authentication pays off.** A CI runner is a fresh Linux VM
with no browser and no human — it cannot complete MFA. Key pair is the only mechanism
that works for automation, which is why it was set up on day two rather than a
password.

---

## Environment Isolation

Three schemas in one database, selected by the `target:` in `profiles.yml`:

| Schema | Used by |
|---|---|
| `raw` | the S3 landing zone, never written by dbt |
| `dbt_andres` | local development |
| `dbt_ci` | CI runs |

**Why separate:** if CI wrote into `dbt_andres`, a workflow run would clobber
in-progress models mid-edit, and local builds would fail CI's tests for reasons
unrelated to the PR.

Real teams extend the same pattern — a personal schema per developer, one for CI, one
for production.

---

## "Works On My Machine"

**The first CI run failed, and it caught a repo that was broken for everyone except
its author.**

`dim_geography` referenced a seed that was not in the repository. The root `.gitignore`
had `*.csv` with an exception only for `smoke_test.csv`, so `git add` had silently
skipped `state_regions.csv`. Locally everything worked — the file was on disk. Anyone
cloning the repo would have hit `Ref 'state_regions' not found in project`.

**Nothing would have revealed this without CI.** Not a local build, not a passing test
suite, not code review. Only a fresh machine with nothing but what is committed.

**The general lesson: a green local build proves your machine works, not that your
repository does.** This is the same shape as "green pipeline ≠ correct data" — the
check has to run somewhere your assumptions do not.

**`git check-ignore -v <path>`** names which rule in which file is excluding a path.
The tool for "why is Git not tracking this?"
