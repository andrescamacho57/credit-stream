# Unix / Terminal Command Reference

Everything I've actually used on this project, with what it does and why.
These work identically on macOS and on any Linux server — that's the point.

---

## Navigation

| Command | Does |
|---|---|
| `pwd` | **P**rint **W**orking **D**irectory — where am I right now |
| `ls` | List files in current directory |
| `ls -a` | Include hidden files (anything starting with `.`) |
| `ls -lh` | Long format with **h**uman-readable sizes (374M not 392265879) |
| `cd foo` | Change into directory `foo` |
| `cd ..` | Up one level |
| `cd ~` | Home directory |
| `cd` | Also home directory (shortcut) |

**`~` means your home folder** — `/Users/yourname`. So `~/credit-stream` is
`/Users/yourname/credit-stream`.

---

## Creating & Moving

| Command | Does |
|---|---|
| `mkdir foo` | Make directory |
| `mkdir -p a/b/c` | Make nested directories, no error if they exist |
| `touch file.txt` | Create an empty file (or update its timestamp if it exists) |
| `mv old new` | Move **or** rename — same operation to Unix |
| `mv a.md b.md .` | Move multiple files into current directory (`.`) |
| `cp a b` | Copy |
| `rm file` | Delete a file — **no undo, no trash** |

**`rm` is permanent.** There is no recycle bin. Be deliberate.

---

## Reading Files

| Command | Does |
|---|---|
| `cat file` | Print entire contents ("con**cat**enate") |
| `head -3 file` | First 3 lines |
| `tail -3 file` | Last 3 lines |
| `wc -l file` | Count lines ("**w**ord **c**ount", `-l` for lines) |
| `gzcat file.gz` | Print a gzipped file's contents without decompressing to disk |

**`head`/`tail` are how you inspect a huge file safely.** Never `cat` a 1GB file —
it will flood your terminal for minutes.

---

## Text Processing

| Command | Does |
|---|---|
| `grep pattern file` | Print only lines containing `pattern` |
| `grep -i pattern` | Case-insensitive |
| `tr 'a' 'b'` | **Tr**anslate — swap one character for another |
| `sed 's/pat/repl/'` | **S**tream **ed**itor — pattern-based find and replace |

**`tr` vs `sed`:** `tr` swaps single characters. `sed` rewrites whole patterns and
can wrap text around what it matched. `tr ',' '\n'` turns commas into newlines.
`sed 's/.*/  & VARCHAR,/'` wraps each line — `.*` matches the whole line, `&`
reinserts what matched.

---

## Pipes & Redirection

| Symbol | Does |
|---|---|
| `\|` | Pipe — send one command's output into the next command's input |
| `>` | Redirect output to a file, **overwriting** it |
| `>>` | Redirect output to a file, **appending** to it |
| `\` at line end | Continue one command onto the next line |
| `2>/dev/null` | Throw away error messages (keeps output clean) |

**`>` vs `>>` is the one to burn in.** One arrow replaces the whole file.
Two arrows add to the end. Mixing these up wipes files.

**The pipe is the core Unix idea.** Each tool does one small thing to a stream of
text; chain them to build something larger:

```bash
gzcat file.csv.gz | head -1 | tr ',' '\n' | wc -l
# decompress → first line → one word per line → count them
```

---

## System & Misc

| Command | Does |
|---|---|
| `which foo` | Where does command `foo` live on disk (silent if not installed) |
| `clear` | Wipe the screen |
| `echo "text"` | Print text |
| `pbcopy` | Pipe text to the macOS clipboard (`cat file \| pbcopy`) |
| `code .` | Open current directory in VS Code |
| `code file` | Open a specific file in VS Code |

---

## Terminal Shortcuts

| Keys | Does |
|---|---|
| `↑` / `↓` | Scroll through command history |
| `Ctrl + R` | **Search** command history — type a fragment, Enter to run |
| `Tab` | Autocomplete file/folder names (also prevents typos) |
| `Ctrl + U` | Delete the entire current line |
| `Ctrl + W` | Delete the last word |
| `Ctrl + A` / `Ctrl + E` | Jump to start / end of line |
| `Ctrl + C` | Abandon current line, fresh prompt (safe — runs nothing) |
| `Ctrl + L` | Clear screen |
| `Option + ←/→` | Move by word (Mac) |
| ``Ctrl + ` `` | Toggle VS Code terminal open/closed |

**The two that save the most time:** `↑` to recall, `Tab` to autocomplete.

---

## Git

| Command | Does |
|---|---|
| `git status` | Where does everything stand — **run constantly** |
| `git add file` | Stage a specific file |
| `git add .` | Stage everything changed (only after reading `git status`) |
| `git commit -m "msg"` | Commit staged changes to local repo |
| `git push` | Send local commits to GitHub |
| `git clone URL` | Download a repo and wire up the remote |
| `git remote -v` | Show what remotes are configured |
| `git log --oneline` | Compact commit history |

**Commit messages in the imperative** — "Add X", "Fix Y" — completing the sentence
*"This commit will…"*. Convention across nearly every codebase.

---

## Habits Worth Keeping

- **`git status` before `git add .`** — know what you're staging
- **`pwd` when confused** — half of all terminal confusion is being in the wrong folder
- **Retype pasted commands that fail nonsensically** — pasted text can carry
  invisible non-breaking spaces that break argument parsing
- **Silence means success** — most Unix commands print nothing when they work and
  only speak up on failure

---

## Permissions & Security

| Command | Does |
|---|---|
| `chmod 600 file` | Owner read+write only — for private keys and secrets |
| `chmod 644 file` | Owner read+write, others read — normal files |
| `ls -l` | Show permissions, owner, size, date |

Permissions read as `-rw-------` (600) or `-rw-r--r--` (644). Owner / group / others,
each with read(4) write(2) execute(1) summed.

---

## Cryptography (openssl)

**`openssl`** is the standard toolkit for keys, certificates, and encryption.

```bash
# Generate a 2048-bit RSA private key in PKCS#8 format (what Snowflake wants)
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out ~/.snowflake/rsa_key.p8 -nocrypt

# Derive the public key from the private key
openssl rsa -in ~/.snowflake/rsa_key.p8 -pubout -out ~/.snowflake/rsa_key.pub
```

- `genrsa 2048` — generate a 2048-bit RSA private key
- `pkcs8 -topk8` — convert to PKCS#8, the format Snowflake requires
- `-nocrypt` — no passphrase on the key
- `-pubout` — output the public half

**The public key is derived from the private key**, never the reverse. That
asymmetry is the whole basis of the scheme.

**Strip the PEM wrapper and copy to clipboard** (Snowflake wants bare key material):
```bash
grep -v "^-----" ~/.snowflake/rsa_key.pub | tr -d '\n' | pbcopy
```
- `grep -v` — **invert match**: print lines that do NOT match
- `^-----` — regex for "line starts with five dashes"
- `tr -d '\n'` — delete newlines, collapsing to one line

---

## Finding Files

```bash
find . -type f -not -path "./target/*" -not -path "./logs/*" | sort
```

- `find .` — walk the tree from here
- `-type f` — files only, not directories
- `-not -path "./target/*"` — exclude a subtree
- `| sort` — alphabetize

Better than `ls`-ing into every folder when you want a full inventory.

---

## Copying & Deleting

| Command | Does |
|---|---|
| `cp a b` | Copy |
| `rm file` | Delete a file — refuses to delete directories |
| `rm -rf folder` | **Recursive + force delete. No undo. No trash.** |

**`rm -rf` is the most dangerous command in Unix.** `-r` recurses into folders, `-f`
suppresses all confirmation. Pointed at the wrong path it destroys everything below
it silently.

**Always `pwd` before `rm -rf`.** Confirm you are where you think you are.

Prefer plain `rm` for files — it refuses to touch a directory, which is a useful
guardrail.

---

## Command Substitution

```bash
cp ~/.dbt/profiles.yml ~/.dbt/profiles.yml.backup-$(date +%Y%m%d)
```

**`$(command)`** runs the command and substitutes its *output* into the line. Here
`date +%Y%m%d` produces `20260726`, giving a dated backup filename.

Dated backups beat overwriting a single `.bkp` file every time.

---

## Reading Long Help Output

```bash
dbt init --help | head -40
```

When `--help` floods the screen, pipe it to `head` — the usage line and the key flags
are almost always at the top.

**When a command rejects your arguments, read `--help` before searching.** It is
authoritative for the exact version installed on your machine. Syntax changes between
major versions, and tutorials go stale.

---

## Heredocs — Writing Files From the Terminal

```bash
cat > models/staging/stg_loans.sql << 'EOF'
with source as (
    select * from {{ source('raw', 'accepted_loans') }}
)
select * from source


---

## Heredocs — Writing Files From the Terminal

```bash
cat > models/staging/stg_loans.sql << 'HEREDOC_END'
with source as (
    select * from raw_table
)
select * from source
HEREDOC_END
```

- `cat > file` — redirect into the file, **overwriting** it
- `cat >> file` — **append** instead
- `<< 'WORD'` — a **heredoc**: everything until a line containing only `WORD` becomes
  the input
- **Quote the delimiter** to stop the shell interpreting `$`, backticks, or Jinja
  braces inside the content

**Why bother when you have an editor:** no save step to forget. If an edit
mysteriously has no effect, an unsaved editor buffer is the first suspect — writing
straight to disk removes that failure mode entirely.

`EOF` is the conventional delimiter but any word works. **Gotcha:** if the content
itself contains the delimiter word, the heredoc ends early. Use a distinctive
delimiter when writing files that contain heredocs.

---

## Verifying an Edit Landed

```bash
grep "from loans_only" models/staging/stg_loans.sql
```

`grep` prints matching lines and stays silent when there are none. A quick way to
confirm a specific change is really in the file — faster than reading the whole thing.

Useful companions:
```bash
cat file          # see the whole thing
ls -la folder     # check file sizes; 0 means empty
head -3 file      # top
tail -3 file      # bottom
```

**When something behaves as if your change did not happen, verify the file on disk
before debugging anything else.** Unsaved buffers, edits appended to the wrong place,
and empty files account for most of these.

---

## Two Languages, Two Places

| Runs in the terminal | Runs in Snowflake |
|---|---|
| `dbt run`, `dbt test`, `dbt build` | `select`, `create table`, `copy into` |
| `git`, `ls`, `cd`, `cat`, `grep` | anything SQL |

Pasting SQL into the shell gives `zsh: parse error near ...`. Easy mix-up with two
panes open — SQL goes in a `.sql` file and runs via the Snowflake extension play
button.


---

## Git — Branches and Pull Requests

| Command | Does |
|---|---|
| `git branch` | list branches; `*` marks current |
| `git checkout -b feature/name` | create a branch and switch to it |
| `git checkout main` | switch to an existing branch |
| `git push -u origin branch-name` | push a new branch and link it to the remote |
| `git push` | after linking, this is enough |
| `git pull` | fetch and merge the remote's commits |
| `git branch -d branch-name` | delete a merged branch (refuses if unmerged) |
| `git branch -D branch-name` | delete regardless — no safety net |

**The full loop:**
```bash
git checkout -b feature/add-ci      # branch
# ... edit files ...
git add .
git commit -m "Add CI workflow"
git push -u origin feature/add-ci   # first push creates the remote branch
# ... open PR on GitHub, CI runs, merge ...
git checkout main
git pull                            # bring the merged commits down
git branch -d feature/add-ci        # clean up
```

**`-u origin branch` is only needed on the first push.** After that the branch is
linked and plain `git push` works.

---

## Git — Diagnostics

| Command | Does |
|---|---|
| `git check-ignore -v <path>` | which `.gitignore` rule is excluding this file |
| `git show --stat HEAD` | files changed in the last commit |
| `git log --oneline` | compact history |
| `git ls-files \| grep NAME` | is Git currently tracking this file |
| `diff fileA fileB` | compare two files; silence means identical |

**`git check-ignore -v` is the tool for "why is Git not tracking this?"** It names the
file and line number of the rule doing it.

---

## The Pager

Git pipes list-like output through `less`. You will land in a screen full of `~` with
`(END)` at the bottom.

**Press `q` to quit.** Space scrolls, `/` searches.

Turn it off for a specific command:
```bash
git config --global pager.branch false
```

**`--no-pager` is a flag on `git`, not on the subcommand** — `git --no-pager branch`,
not `git branch --no-pager`.
