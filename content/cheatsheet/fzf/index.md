---
title: "fzf Cheatsheet"
date: 2026-10-26T16:30:00+02:00
draft: false
description: "fzf, the command-line fuzzy finder: install on RHEL, Ubuntu and macOS, shell key bindings, search syntax, options, environment variables, quick aliases and a block of ready-made aliases and functions for files, git, processes, AWS, Kubernetes, SSH and Docker that works in bash and zsh."
tags: ["fzf", "bash", "zsh", "shell"]
categories: ["Cheatsheet"]
---

`fzf` is an interactive filter for the command line. It reads a list of lines (files, processes, branches, history), lets you narrow it by typing, and prints the line you choose. It works with any command that prints lines, so it is the glue behind many small shell helpers.

The commands and functions below ran with fzf 0.74.5 on macOS, under bash 3.2.57 (the macOS `/bin/bash`, the oldest bash they have to work with) and zsh 5.9, with ripgrep 15.2.0, fd 10.5.0 and bat 0.26.1.

## 1. Install

```bash
# Debian / Ubuntu
sudo apt install fzf

# RHEL family, Fedora (the package is in the Fedora repositories, on RHEL it may need EPEL)
sudo dnf install fzf

# macOS (Homebrew)
brew install fzf

# Any Linux or macOS, from source
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
~/.fzf/install

fzf --version
```

Distribution packages can be old. The `--bash` and `--zsh` shell integration below needs fzf **0.48.0 or newer**.

### fzf on RHEL and Ubuntu: versions and files

| OS | Where fzf comes from | Version | `fzf --bash` works? | Key bindings file | Completion |
|----|----------------------|---------|---------------------|-------------------|------------|
| RHEL 7 | Not in the CentOS 7 repositories or the EPEL 7 archive. Use the git installer | any | with the installer's files | `~/.fzf/shell/key-bindings.bash` | `~/.fzf/shell/completion.bash` |
| RHEL 8, 9, 10 | Not in BaseOS, AppStream or CRB. **EPEL** (`sudo dnf install epel-release`, then `sudo dnf install fzf`) | 0.58.0 | yes | `/usr/share/fzf/shell/key-bindings.bash` | `/etc/bash_completion.d/fzf` |
| Ubuntu 22.04 | `universe` | 0.29.0 | **no** | `/usr/share/doc/fzf/examples/key-bindings.bash` | `/usr/share/bash-completion/completions/fzf` |
| Ubuntu 24.04 | `universe` | 0.44.1 | **no** | `/usr/share/doc/fzf/examples/key-bindings.bash` | `/usr/share/bash-completion/completions/fzf` |
| Ubuntu 26.04 | `universe` | 0.67.0 | yes | `/usr/share/doc/fzf/examples/key-bindings.bash` | `/usr/share/doc/fzf/examples/completion.bash` |

Ubuntu 25.04 and 25.10 both have 0.60.3. The `~/.fzf.bash` file of the legacy line in section 2 is **created only by the git installer** (`~/.fzf/install`, unless you pass `--bin`). A package install never creates it, so that line does nothing after `apt install` or `dnf install`.

### The helper tools: versions and command names

The article uses `fd`, `rg` (ripgrep) and `bat` as optional helpers. None of them is in the base RHEL repositories of any version. The packages are `fd-find`, `ripgrep` and `bat`.

| OS | fd | ripgrep | bat |
|----|----|---------|-----|
| RHEL 7 | not found | not found | not found |
| RHEL 8 (EPEL) | 8.7.0, command `fd` | 14.1.1, command `rg` | 0.24.0, command `bat` |
| RHEL 9 (EPEL) | 10.4.2, command `fd` | 15.2.0, command `rg` | 0.26.1, command `bat` |
| RHEL 10 (EPEL) | 10.4.2, command `fd` | 15.2.0, command `rg` | 0.26.1, command `bat` |
| Ubuntu 22.04 | 8.3.1, command **`fdfind`** | 13.0.0, command `rg` | 0.19.0, command **`batcat`** |
| Ubuntu 24.04 | 9.0.0, command **`fdfind`** | 14.1.0, command `rg` | 0.24.0, command **`batcat`** |
| Ubuntu 26.04 | 10.3.0, command **`fdfind`** | 15.1.0, command `rg` | 0.25.0, command **`batcat`** |

On Debian and Ubuntu the commands are `fdfind` and `batcat`, because the names `fd` and `bat` were already taken by other packages. The setup block in section 6 looks for both names, so it works on Ubuntu without symlinks.

The RHEL rows come from the EPEL repository metadata (x86_64); "not in the base repositories" comes from the BaseOS, AppStream and CRB (PowerTools on 8) repositories of Rocky Linux 8, 9 and 10 and the CentOS 7 vault, which carry the same packages as RHEL. The Ubuntu rows come from the Ubuntu archive (Launchpad) and the file lists of the `.deb` packages. Versions move, so check them again before you depend on one.

## 2. Shell Integration and Key Bindings

```bash
# ~/.bashrc  (fzf 0.48.0 or newer)
eval "$(fzf --bash)"

# ~/.zshrc   (fzf 0.48.0 or newer)
source <(fzf --zsh)

# Older fzf (below 0.48.0), installed with the git installer (it writes ~/.fzf.bash)
[ -f ~/.fzf.bash ] && source ~/.fzf.bash

# Older fzf installed from a package: source the file that the package ships (see section 1)
[ -f /usr/share/fzf/shell/key-bindings.bash ] && source /usr/share/fzf/shell/key-bindings.bash                 # RHEL 8, 9, 10 (EPEL)
[ -f /usr/share/doc/fzf/examples/key-bindings.bash ] && source /usr/share/doc/fzf/examples/key-bindings.bash   # Ubuntu 22.04, 24.04
```

Reload the shell (`source ~/.bashrc`). Three key bindings are added:

| Keys | Action |
|------|--------|
| `CTRL-R` | Fuzzy-search the command history and insert the result |
| `CTRL-T` | Insert a file or directory path into the command line |
| `ALT-C` | Pick a subdirectory and `cd` into it |

On macOS, `ALT-C` types a special character unless the terminal treats Option as Meta (in iTerm2: Profiles, Keys, "Left Option key: Esc+"; in Terminal.app: "Use Option as Meta key").

## 3. Search Syntax (Typed in the Query Box)

| Typed | Meaning |
|-------|---------|
| `git push` | Both terms match, each fuzzy (AND) |
| `'wild` | Exact match, no fuzzy matching |
| `^core` | Starts with `core` |
| `.md$` | Ends with `.md` |
| `!test` | Does not contain `test` |
| `^src \| ^app` | Starts with `src` or `app` (OR, spaces around the bar) |

Fuzzy means the letters must appear in order but not next to each other: `scm` matches `src/core.md`. Use the exact form (`'`) when fuzzy matches are too loose.

```bash
# Start with a query already typed
find . -type f | fzf --query "'.log$ !archive"
fzf -q "query"
```

With `fzf --filter` on a list of nine file names: `core md` found `src/core.md`, `'wild` found only `wild/wildcard.txt`, `^src` found `src/core.md` and `src/util.py`, `.md$` found `README.md` and `src/core.md`, `!test` removed the one test file, `^src | ^app` found the `src` and `app` entries, and `'.log$ !archive` found `notes.log` and `logs/app.log` but not `archive/old.log`.

## 4. Options

| Option | Effect |
|--------|--------|
| `--height 40%` | Use the bottom 40% of the screen instead of the whole terminal |
| `--layout=reverse` | Input line on top, candidates below |
| `--border` | Draw a border |
| `-m`, `--multi` | Multi-select: mark rows with `TAB`, the selection prints one per line |
| `--preview 'cmd {}'` | Show a preview window. `{}` is the highlighted line, `{1}` its first field |
| `-q`, `--query` | Initial query |
| `-f`, `--filter` | Non-interactive: print the matches for the query and exit (good for scripts and tests) |
| `--tac` | Reverse the input order |
| `--no-sort` | Keep the input order instead of sorting by match score |
| `--select-1` | If only one line matches, select it without asking |
| `--exit-0` | Exit if nothing matches |
| `--ansi` | Process ANSI color codes in the input (needed for `git log --color=always`) |

## 5. Environment Variables

```bash
# ~/.bashrc
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'
export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"      # CTRL-T does not read FZF_DEFAULT_COMMAND
```

| Variable | Effect |
|----------|--------|
| `FZF_DEFAULT_OPTS` | Options added to every `fzf` run |
| `FZF_DEFAULT_COMMAND` | The command that produces the list for a plain `fzf` (no pipe). `rg --files` is another common choice |
| `FZF_CTRL_T_COMMAND` | The command that produces the list for `CTRL-T`. It does **not** fall back to `FZF_DEFAULT_COMMAND` |
| `FZF_ALT_C_COMMAND` | The same for `ALT-C` (directories) |

When `FZF_CTRL_T_COMMAND` and `FZF_ALT_C_COMMAND` are not set, `CTRL-T` and `ALT-C` use fzf's built-in walker (files and directories for `CTRL-T`, directories for `ALT-C`), so setting only `FZF_DEFAULT_COMMAND` changes a plain `fzf` and nothing else. `FZF_DEFAULT_COMMAND` must be a **real binary**. An alias does not work there, and if the binary is missing the list is empty. `fd` is a separate package (`fd-find`), and on Debian and Ubuntu its command is `fdfind` (see the table in section 1).

## 6. Aliases and Functions

Every alias and function below has its own block, so you can copy only the ones you want into `~/.bashrc` or `~/.zshrc`. All of them work in bash and zsh. Paste the setup block first and the others after it: it turns on the key bindings and the default options, and `fp`, `fa` and `fr` use the preview commands it defines.

### Setup

The setup skips everything if `fzf` is not installed. It finds `bat` or `batcat` and `fd` or `fdfind` for the previews and the candidate list.

```bash
# ---- fzf setup, works in bash and zsh ----
if command -v fzf >/dev/null 2>&1; then
  # key bindings: CTRL-R history, CTRL-T file path, ALT-C cd (fzf 0.48.0 or newer)
  if [ -n "$ZSH_VERSION" ]; then source <(fzf --zsh); elif [ -n "$BASH_VERSION" ]; then eval "$(fzf --bash)"; fi

  export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'

  # Debian and Ubuntu install bat as "batcat" and fd as "fdfind": find whichever name exists
  __fzf_bat=; __fzf_fd=
  for __c in bat batcat; do command -v "$__c" >/dev/null 2>&1 && { __fzf_bat=$__c; break; }; done
  for __c in fd fdfind; do command -v "$__c" >/dev/null 2>&1 && { __fzf_fd=$__c; break; }; done
  unset __c

  # candidate list for plain fzf and CTRL-T, only if the real binary exists (an alias does not work here)
  if [ -n "$__fzf_fd" ]; then
    export FZF_DEFAULT_COMMAND="$__fzf_fd --type f --hidden --exclude .git"
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"   # CTRL-T has its own variable
  fi

  # preview commands: bat when it exists, the first 50 lines otherwise
  if [ -n "$__fzf_bat" ]; then
    __fzf_view="$__fzf_bat --color=always --style=numbers {}"
    __fzf_view_line="$__fzf_bat --color=always --highlight-line {2} {1}"
  else
    __fzf_view="head -n 50 {}"
    __fzf_view_line="head -n 50 {1}"
  fi
fi
```

### Overview

| Name | Kind | What it does |
|------|------|--------------|
| `fm` | alias | `fzf --multi`, multi-select |
| `fp` | alias | File picker with a `bat` or `batcat` preview (the first 50 lines if neither exists) |
| `fgl` | alias | Browse commits, preview the diff of the highlighted one |
| `fvim` | alias | `vim "$(fzf)"`: open the picked file in vim |
| `fkill9` | alias | `kill -9` the picked process |
| `fco` | alias | `git checkout` the picked branch (a remote branch gives a detached HEAD) |
| `fdir` | alias | `cd` into the picked directory |
| `frmi` | alias | `rm -i` the picked files (breaks on names with spaces) |
| `fpcat` | alias | File picker with a `cat` preview |
| `fe [query]` | function | Open a file in `$EDITOR`, jump straight to it if only one matches (a safer `fvim`) |
| `fcd [dir]` | function | `cd` into a subdirectory, skipping `.git` (a safer `fdir`) |
| `fkill [signal]` | function | Pick processes, send `TERM` (or the signal you give, `fkill 9` for `-9`) (a safer `fkill9`) |
| `fgb` | function | Check out a local or remote branch, strips `remotes/origin/` (a safer `fco`) |
| `frm` | function | Delete picked files with `rm -i`, safe for names with spaces (a safer `frmi`) |
| `fh` | function | Pick a past command and print it (`CTRL-R`) |
| `fa [query]` | function | Pick a Markdown file of the current git repository (from any folder of it) with a `bat` or `batcat` preview and open it in `$EDITOR` |
| `fr <pattern>` | function | Search file contents, preview the match, open the file at that line. Uses `rg` when it exists, otherwise `grep -rnI` (skipping `.git`) |
| `fga` | function | Stage files picked from the modified and untracked ones (`TAB` for several), safe for names with spaces |
| `fgc [message]` | function | Stage **everything** (modified, deleted, new and untracked files) and commit it, after a yes/no check |
| `fgs` | function | Browse stashes with a diff preview, then show the chosen one |
| `faws` | function | Pick an AWS CLI profile and export `AWS_PROFILE` for the current shell |
| `fkx` | function | Print a kubectl context name, for one command: `kubectl --context "$(fkx)" get pods` |
| `fkc` | function | Switch the current kubectl context (needs `fkx`) |
| `fssh` | function | Pick a host from `~/.ssh/config` (wildcard entries skipped) and connect |
| `fport` | function | List listening TCP ports and print the chosen line (the PID is the second column) |
| `_fdc` | function | Helper for the three Docker functions: pick running containers, print their names |
| `fdl` | function | Follow the logs of a container (needs `_fdc`) |
| `fdx` | function | Open a shell in a container, bash if it exists, else sh (needs `_fdc`) |
| `fds` | function | Stop containers, `TAB` for several (needs `_fdc`) |

### Aliases

> **Warning:** the quick aliases `fkill9`, `frmi` and `fco` act on whatever you select. `kill -9` cannot be handled by the process, so unsaved data is lost. `rm` removes files for good (there is no trash), and the unquoted `$(fzf -m)` in `frmi` breaks a file name with a space into several arguments. `fco` on a remote branch leaves a detached HEAD. If you press ESC, fzf prints nothing and some of them then run with an empty argument. The functions `fkill`, `frm` and `fgb` do the same jobs without these problems.

#### fm: multi-select

```bash
alias fm='fzf --multi'                                   # TAB marks rows, one per line on output
```

#### fp: file picker with preview

Uses `$__fzf_view` from the setup block.

```bash
alias fp="fzf --preview '$__fzf_view'"                   # file picker with preview
```

#### fgl: browse commits

```bash
alias fgl="git log --oneline --color=always | fzf --ansi --preview 'git show --color=always {1}'"   # browse commits
```

#### fvim: open a file in vim

```bash
alias fvim='vim "$(fzf)"'                                # open a file in vim
```

#### fkill9: kill -9 a process

```bash
alias fkill9='kill -9 "$(ps -ef | fzf | awk "{print \$2}")"'   # pick a process, kill -9 it
```

#### fco: check out a branch

```bash
alias fco='git checkout "$(git branch --all | fzf | tr -d " *")"'  # pick a branch and check it out
```

#### fdir: cd into a directory

```bash
alias fdir='cd "$(find . -type d | fzf)"'                # pick a directory and cd into it
```

#### frmi: delete files with a prompt

```bash
alias frmi='rm -i $(fzf -m)'                             # pick files, delete them with a prompt
```

#### fpcat: file picker with a cat preview

```bash
alias fpcat="fzf --preview 'cat {}'"                     # file picker with a plain cat preview
```

### Functions

#### fe: open a file in $EDITOR

```bash
# fe [query]: open the chosen file in $EDITOR
fe() { local f; f=$(fzf --query "$1" --select-1 --exit-0) && [ -n "$f" ] && ${EDITOR:-vim} "$f"; }
```

#### fcd: cd into a subdirectory

```bash
# fcd [dir]: cd into a subdirectory
fcd() { local d; d=$(command find "${1:-.}" -type d -not -path '*/.git/*' 2>/dev/null | fzf) && [ -n "$d" ] && cd "$d"; }
```

#### fkill: signal processes

```bash
# fkill [signal]: pick processes (TAB for several) and signal them, default TERM
fkill() {
  local pids
  pids=$(command ps -ef | sed 1d | fzf -m --header 'TAB marks, ENTER kills' | awk '{print $2}')
  [ -n "$pids" ] && echo "$pids" | xargs kill "-${1:-TERM}"
}
```

`fkill` sends `TERM` by default, so the process can shut down cleanly, and it accepts several processes with `TAB`. fzf matches fuzzily, so a short word can highlight unrelated processes: look at the highlighted lines before pressing ENTER, and use the exact form (`'name`) to narrow the list. A process owned by another user answers "Operation not permitted" and nothing happens.

#### fgb: check out a branch

```bash
# fgb: check out a branch (local or remote)
fgb() {
  local b
  b=$(git branch --all | grep -v HEAD | sed 's#^[* ]*##; s#^remotes/[^/]*/##' | sort -u | fzf) && [ -n "$b" ] && git checkout "$b"
}
```

`fgb` removes the `remotes/<name>/` prefix, because `git checkout origin/x` would give a detached HEAD, while `git checkout x` creates a tracking branch.

#### frm: delete files with a prompt

```bash
# frm: pick files (TAB for several) and delete them, asking for each (rm -i)
frm() {
  local sel f files=()
  sel=$(fzf -m) || return
  while IFS= read -r f; do [ -n "$f" ] && files+=("$f"); done <<< "$sel"
  [ "${#files[@]}" -gt 0 ] && rm -i -- "${files[@]}"
}
```

`frm` reads the selection line by line into an array, so a name with spaces stays one argument, and it passes `--` so a name that starts with a dash is not read as an option.

#### fh: pick a command from history

```bash
# fh: pick a command from history and print it (edit it, then run)
fh() { fc -rl 1 | fzf --no-sort | sed 's/^[[:space:]]*[0-9]*[[:space:]*]*//'; }
```

#### fa: open a Markdown file of the repository

Uses `$__fzf_view` from the setup block.

```bash
# fa [query]: pick a Markdown file of the current git repository (from any folder of it) and open it
fa() {
  local root f
  root=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "not in a git repo" >&2; return 1; }
  f=$(cd "$root" && git ls-files '*.md' | fzf --query "$1" --preview "$__fzf_view") \
    && [ -n "$f" ] && ${EDITOR:-vim} "$root/$f"
}
```

#### fr: search file contents

Uses `$__fzf_view_line` from the setup block.

```bash
# fr <pattern>: search file contents (ripgrep, or grep if rg is missing), preview the match, open the file at that line
fr() {
  local sel file line
  sel=$( { if command -v rg >/dev/null 2>&1; then rg --line-number --no-heading --color=always "$@"; else grep -rnI --exclude-dir=.git --color=always -e "$@" .; fi; } \
    | fzf --ansi --delimiter : \
          --preview "$__fzf_view_line") || return
  [ -n "$sel" ] || return
  file=${sel%%:*}; line=${sel#*:}; line=${line%%:*}
  ${EDITOR:-vim} "+$line" "$file"
}
```

`fr` takes one pattern. Extra options for `rg` (for example `-i` or `-g '*.md'`) work when `rg` is installed, but not in the `grep` fallback.

#### fga: stage picked files

```bash
# fga: stage files picked from the modified and untracked ones (TAB for several)
fga() {
  local sel f files=()
  sel=$(git ls-files --modified --others --exclude-standard | sort -u | fzf -m) || return
  while IFS= read -r f; do [ -n "$f" ] && files+=("$f"); done <<< "$sel"
  [ "${#files[@]}" -gt 0 ] && git add -- "${files[@]}" && git status --short
}
```

#### fgc: stage everything and commit

```bash
# fgc [message]: stage ALL changes (modified, deleted, new and untracked) and commit them, after a yes/no check
fgc() {
  local msg="$*" answer
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "not in a git repo" >&2; return 1; }
  [ -n "$(git status --porcelain)" ] || { echo "nothing to commit"; return 0; }
  git status --short
  if [ -z "$msg" ]; then printf 'Commit message: '; IFS= read -r msg; fi
  [ -n "$msg" ] || { echo "empty message, nothing done" >&2; return 1; }
  answer=$(printf 'yes\nno\n' | fzf --height 20% --header "Stage ALL changes above and commit \"$msg\"?")
  [ "$answer" = yes ] && git add -A && git commit -m "$msg"
}
```

`fgc` stages everything the repository does not ignore. It runs `git add -A`, which covers the whole working tree even when you run it from a subdirectory, new and untracked files included. Read the status list before you answer yes: a `.env` file, a key, a build folder or a large file that is not in `.gitignore` goes into the commit. Answering no (or leaving fzf with ESC) changes nothing, and an empty message stops it. For a selective commit use `fga` and then `git commit`.

#### fgs: browse stashes

```bash
# fgs: pick a stash and show it (use "git stash apply <name>" to restore)
fgs() {
  local s
  s=$(git stash list | fzf --preview 'git stash show -p --color=always $(echo {} | cut -d: -f1)' | cut -d: -f1) \
    && [ -n "$s" ] && git stash show -p --color=always "$s"
}
```

#### faws: pick an AWS profile

```bash
# faws: pick an AWS CLI profile and export it for this shell
faws() {
  local p
  p=$(aws configure list-profiles | fzf --header 'AWS_PROFILE') && [ -n "$p" ] && export AWS_PROFILE="$p" && echo "AWS_PROFILE=$p"
}
```

`faws` only exports the profile name. For an SSO profile you still log in with `aws sso login --profile "$AWS_PROFILE"`.

#### fkx: print a kubectl context

```bash
# fkx: print a kubectl context name, for one-off use: kubectl --context "$(fkx)" get pods
fkx() { kubectl config get-contexts -o name | fzf --header 'kubectl context'; }
```

#### fkc: switch the kubectl context

Needs `fkx`.

```bash
# fkc: switch the current kubectl context (this edits your kubeconfig for every terminal)
fkc() { local c; c=$(fkx) && [ -n "$c" ] && kubectl config use-context "$c"; }
```

Prefer `fkx` to `fkc`. `kubectl config use-context` edits the kubeconfig, so the new context applies to every terminal and every later command. If the current context can be a production cluster, a one-off `--context "$(fkx)"` is safer.

#### fssh: connect to a host from ~/.ssh/config

```bash
# fssh: pick a host from ~/.ssh/config and connect
fssh() {
  local h
  h=$(awk 'tolower($1)=="host" { for (i=2; i<=NF; i++) if ($i !~ /[*?!]/) print $i }' ~/.ssh/config 2>/dev/null | sort -u | fzf --header 'ssh host') \
    && [ -n "$h" ] && ssh "$h"
}
```

#### fport: list listening ports

```bash
# fport: list listening TCP ports and print the chosen line (PID is column 2)
fport() { lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | sed 1d | fzf --header 'COMMAND PID ... NAME'; }
```

`fport` only prints a line. To free a port, find the PID with `fport`, then `kill <pid>` (or use `fkill`).

#### _fdc: pick containers (helper)

The three Docker functions below need this helper.

```bash
# _fdc: pick running containers and print their names (helper for fdl, fdx, fds)
_fdc() { docker ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}' | fzf "$@" | cut -f1; }
```

#### fdl: follow container logs

```bash
# fdl: follow the logs of a container
fdl() { local c; c=$(_fdc) && [ -n "$c" ] && docker logs -f --tail 100 "$c"; }
```

#### fdx: open a shell in a container

```bash
# fdx: open a shell in a container, bash if it exists, else sh
fdx() { local c; c=$(_fdc) && [ -n "$c" ] && docker exec -it "$c" sh -c 'command -v bash >/dev/null && exec bash || exec sh'; }
```

#### fds: stop containers

```bash
# fds: stop containers (TAB for several)
fds() { local sel c cs=(); sel=$(_fdc -m) || return; while IFS= read -r c; do [ -n "$c" ] && cs+=("$c"); done <<< "$sel"; [ "${#cs[@]}" -gt 0 ] && docker stop "${cs[@]}"; }
```

`fdx` and `fds` act on running containers only (`docker ps`). `fds` stops what you mark, so look at the marked rows before pressing ENTER.

### How the Functions Are Written

- **They do nothing on ESC.** `fe`, `fcd`, `fgb` and `frm` check that fzf returned something, so they never run a command on an empty selection.
- **Selections are read with a here-string.** `frm`, `fga` and `fds` first store fzf's output (`sel=$(fzf -m)`) and then read it with `<<< "$sel"`. The shorter `done < <(fzf -m)` works in bash but not in zsh: there fzf never appears, so nothing gets deleted, staged or stopped.
- **Your aliases leak into functions.** Bash expands aliases when a function is defined, so an alias such as `alias find='find . -name'` or `alias ps='ps aux'` (common in `~/.bash_aliases`) changes the `find` and `ps` calls inside `fcd` and `fkill`: they stop working. That is why those two use `command find` and `command ps`. If you add your own functions, put `command` in front of any command that you have aliased.
- **In zsh, `$EDITOR` is not split into words.** `fe`, `fa` and `fr` run `${EDITOR:-vim} ...`, which works in bash for `EDITOR='code --wait'` but fails in zsh with `fe: command not found: code --wait`. In zsh use an editor that is a single word, or a small wrapper script.

## 7. Gotchas

- fzf reads from a pipe when there is one, and runs `FZF_DEFAULT_COMMAND` (or a built-in `find`) only when there is none. In scripts without a terminal, pipe the list in yourself.
- **Ubuntu and Debian rename two tools:** `bat` is `batcat` and `fd` is `fdfind`. The setup block in section 6 handles both names. Commands that you type yourself, such as `fzf --preview 'bat {}'`, need the real name or a symlink (`ln -s "$(command -v batcat)" ~/.local/bin/bat`).
- A plain `fzf` lists files, not directories. Use `find . -type d | fzf` or `ALT-C`. (`CTRL-T` lists files and directories.)
- `{}` in a preview is quoted for the shell by fzf, but a line that contains single quotes can still confuse a complex preview command. Prefer `{1}`, `{2}` fields for tabular input.
- Old fzf versions (below 0.48.0) have no `--bash` and `--zsh`. Use the installer script, which writes `~/.fzf.bash`.
- macOS has no `timeout`, and the BSD `xargs` has no `-d`. The functions above avoid both.
- `ps -ef` output differs by system. On macOS and Linux the PID is the second column, which is what `fkill` takes.

The commands and options come from the tutorial at penguin-gym-linux.com and were rewritten and extended here, not copied.
