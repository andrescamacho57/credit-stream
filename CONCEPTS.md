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
