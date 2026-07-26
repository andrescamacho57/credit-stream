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
