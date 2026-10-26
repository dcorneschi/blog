---
title: "fzf Cheatsheet"
date: 2026-10-26T16:30:00+02:00
draft: false
description: "fzf, the command-line fuzzy finder: install on RHEL, Ubuntu and macOS, shell key bindings, search syntax, options, environment variables, and ready-made aliases and functions for files, git, AWS, Kubernetes, SSH, ports, systemd and Docker, one block each, that work in bash and zsh."
tags: ["fzf", "bash", "zsh", "shell"]
categories: ["Cheatsheet"]
---

`fzf` is an interactive filter for the command line. It reads a list of lines (files, processes, branches, history), lets you narrow it by typing, and prints the line you choose. It works with any command that prints lines, so it is the glue behind many small shell helpers.

The commands and functions below ran with fzf 0.74.5 on macOS, under bash 3.2.57 (the macOS `/bin/bash`, the oldest bash they have to work with) and zsh 5.9, with bat 0.26.1.

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

### bat: versions and command names

The `fp` preview uses `bat` when it is installed. It is not in the base RHEL repositories of any version; the package is `bat`.

| OS | bat |
|----|-----|
| RHEL 7 | not found |
| RHEL 8 (EPEL) | 0.24.0, command `bat` |
| RHEL 9 (EPEL) | 0.26.1, command `bat` |
| RHEL 10 (EPEL) | 0.26.1, command `bat` |
| Ubuntu 22.04 | 0.19.0, command **`batcat`** |
| Ubuntu 24.04 | 0.24.0, command **`batcat`** |
| Ubuntu 26.04 | 0.25.0, command **`batcat`** |

On Debian and Ubuntu the command is `batcat`, because the name `bat` was already taken by another package. The preview of `fp` in section 6 tries both names, so it works on Ubuntu without a symlink.

The RHEL rows come from the EPEL repository metadata (x86_64); "not in the base repositories" comes from the BaseOS, AppStream and CRB (PowerTools on 8) repositories of Rocky Linux 8, 9 and 10 and the CentOS 7 vault, which carry the same packages as RHEL. The Ubuntu rows come from the Ubuntu archive (Launchpad) and the file lists of the `.deb` packages. Versions move, so check them again before you depend on one.

## 2. Shell Integration and Key Bindings

```bash
# ~/.bashrc  (fzf 0.48.0 or newer)
eval "$(fzf --bash)"

# ~/.zshrc   (fzf 0.48.0 or newer)
source <(fzf --zsh)

# ~/.config/fish/config.fish
fzf --fish | source

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

### Fuzzy Completion with `**`

The same shell integration adds completion: type `**` where an argument goes and press `TAB`, and fzf picks it.

| Typed | Picks |
|-------|-------|
| `vim **<TAB>` | Files under the current directory (works after any command) |
| `vim ../**<TAB>` | Files under the parent directory |
| `cd **<TAB>` | Directories |
| `kill -9 **<TAB>` | A process; inserts its PID |
| `ssh **<TAB>` | A host from `~/.ssh/config`, `~/.ssh/known_hosts`, `/etc/ssh/ssh_config` or `/etc/hosts` |

To use another trigger than `**`, set it in your shell config, for example `export FZF_COMPLETION_TRIGGER='~~'`.

## 3. Search Syntax (Typed in the Query Box)

| Typed | Meaning |
|-------|---------|
| `git push` | Both terms match, each fuzzy (AND) |
| `'wild` | Exact match, no fuzzy matching |
| `'wild'` | Exact match on word boundaries: `wild` and `a wild b`, not `wildcard` |
| `^core` | Starts with `core` |
| `.md$` | Ends with `.md` |
| `!test` | Does not contain `test` |
| `!^test` | Does not start with `test` |
| `^src \| ^app` | Starts with `src` or `app` (OR, spaces around the bar) |

Case is smart by default: a query in lowercase ignores case, and one uppercase letter makes it case-sensitive (`core` finds `Core.md` and `core.md`, `Core` only `Core.md`). `-i` always ignores case, `+i` never does. With `-e` every term is exact, and `'` then makes a term fuzzy.

### Keys Inside fzf

| Keys | Action |
|------|--------|
| `CTRL-J`, `CTRL-K`, `Down`, `Up` | Move down and up |
| `CTRL-N`, `CTRL-P` | Move to the next or previous match (with `--history`, browse the query history instead) |
| `ENTER` | Accept the highlighted line (all marked lines with `-m`) |
| `ESC`, `CTRL-C`, `CTRL-G`, `CTRL-Q` | Quit without selecting |
| `TAB`, `Shift-TAB` | Mark or unmark a line and move (with `-m`) |
| `CTRL-W`, `CTRL-U` | Delete the word before the cursor, or the whole query |
| `Shift-Up`, `Shift-Down` | Scroll the preview |

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
| `-1`, `--select-1` | If only one line matches, select it without asking |
| `-0`, `--exit-0` | Exit if nothing matches |
| `--ansi` | Process ANSI color codes in the input (needed for `git log --color=always`) |
| `-e`, `--exact` | Exact matching for every term (`'` makes a term fuzzy) |
| `-i`, `+i` | Always ignore case, or always match case (default: smart case) |
| `--header '<text>'` | A fixed line of text above the list |
| `--preview-window right,50%` | Position and size of the preview; `up`, `down`, `left`, sizes in % or lines |
| `--preview-window hidden` | Start with the preview hidden (show it with a `toggle-preview` binding) |
| `-d`, `--delimiter :` | Split lines into fields at `:` (default: whitespace) |
| `-n`, `--nth 2` | Search only field 2 |
| `--with-nth 2..` | Show only fields 2 and later (the output is still the whole line) |
| `--print0` | End each output line with NUL instead of a newline, for `xargs -0` |

### Placeholders

Used in `--preview` and in `--bind` commands. fzf puts each value in single quotes.

| Placeholder | Value |
|-------------|-------|
| `{}` | The highlighted line |
| `{1}`, `{2}` | Field 1, field 2 (see `--delimiter`) |
| `{+}` | Every marked line (the highlighted one if none is marked) |
| `{q}` | The current query |

### Key Bindings with --bind

```bash
fzf --preview 'cat {}' --bind 'ctrl-/:toggle-preview'   # CTRL-/ shows and hides the preview
fzf --bind 'enter:become(vim {})'                        # ENTER replaces fzf with vim on the chosen file
fzf --bind 'ctrl-o:execute(less {})'                     # CTRL-O opens less, then returns to fzf
fzf --bind 'ctrl-r:reload(ls)'                           # CTRL-R replaces the list with new output
```

`become` ends fzf and runs the command in its place, so nothing is printed. `execute` runs it and comes back to the list.

## 5. Environment Variables

```bash
# ~/.bashrc
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'
export FZF_DEFAULT_COMMAND="find . -type f -not -path '*/.git/*'"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"      # CTRL-T does not read FZF_DEFAULT_COMMAND
```

| Variable | Effect |
|----------|--------|
| `FZF_DEFAULT_OPTS` | Options added to every `fzf` run |
| `FZF_DEFAULT_COMMAND` | The command that produces the list for a plain `fzf` (no pipe). `rg --files` is another common choice |
| `FZF_CTRL_T_COMMAND` | The command that produces the list for `CTRL-T`. It does **not** fall back to `FZF_DEFAULT_COMMAND` |
| `FZF_ALT_C_COMMAND` | The same for `ALT-C` (directories) |

When `FZF_CTRL_T_COMMAND` and `FZF_ALT_C_COMMAND` are not set, `CTRL-T` and `ALT-C` use fzf's built-in walker (files and directories for `CTRL-T`, directories for `ALT-C`), so setting only `FZF_DEFAULT_COMMAND` changes a plain `fzf` and nothing else. `FZF_DEFAULT_COMMAND` must be a **real binary**. An alias does not work there, and if the binary is missing the list is empty.

## 6. Aliases and Functions

Every alias and function below has its own block, so you can copy only the ones you want into `~/.bashrc` or `~/.zshrc`. To take all of them at once, use [All in One Block](#all-in-one-block) at the end of this section. All of them work in bash and zsh, and each one works on its own, except where the text says it needs another block. The key bindings come from section 2 and the default options from section 5.

### Overview

| Name | Kind | What it does |
|------|------|--------------|
| `fm` | alias | `fzf --multi`, multi-select |
| `fp` | alias | File picker with a `bat` or `batcat` preview (the first 50 lines if neither exists) |
| `fgl` | alias | Browse commits, preview the diff of the highlighted one |
| `fe [query]` | function | Open a file in `$EDITOR`, jump straight to it if only one matches |
| `fcd [dir]` | function | `cd` into a subdirectory, skipping `.git` |
| `fgb` | function | Check out a local or remote branch, strips `remotes/origin/` |
| `fga` | function | Stage files picked from the modified and untracked ones (`TAB` for several), safe for names with spaces |
| `fgc [message]` | function | Stage **everything** (modified, deleted, new and untracked files) and commit it, after a yes/no check |
| `fgs` | function | Browse stashes with a diff preview, then show the chosen one |
| `faws` | function | Pick an AWS CLI profile and export `AWS_PROFILE` for the current shell |
| `fkc` | function | Switch the current kubectl context |
| `fssh` | function | Pick a host from `~/.ssh/config` (wildcard entries skipped) and connect |
| `fport` | function | List listening TCP ports and print the chosen line (the PID is the second column) |
| `fsys [action]` | function | Pick a systemd service: show its status, follow its logs (`fsys logs`) or run an action (`fsys restart`) |
| `_fdc` | function | Helper for the three Docker functions: pick running containers, print their names |
| `fdl` | function | Follow the logs of a container (needs `_fdc`) |
| `fdx` | function | Open a shell in a container, bash if it exists, else sh (needs `_fdc`) |
| `fds` | function | Stop containers, `TAB` for several (needs `_fdc`) |

### Aliases

#### fm: multi-select

```bash
alias fm='fzf --multi'                                   # TAB marks rows, one per line on output
```

#### fp: file picker with preview

The preview uses `bat`, or `batcat` on Debian and Ubuntu, and the first 50 lines when neither is installed.

```bash
# fp: file picker with preview (bat, batcat, or the first 50 lines)
alias fp="fzf --preview 'if command -v bat >/dev/null; then bat --color=always --style=numbers {}; elif command -v batcat >/dev/null; then batcat --color=always --style=numbers {}; else head -n 50 {}; fi'"
```

#### fgl: browse commits

```bash
alias fgl="git log --oneline --color=always | fzf --ansi --preview 'git show --color=always {1}'"   # browse commits
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

#### fgb: check out a branch

```bash
# fgb: check out a branch (local or remote)
fgb() {
  local b
  b=$(git branch --all | grep -v HEAD | sed 's#^[* ]*##; s#^remotes/[^/]*/##' | sort -u | fzf) && [ -n "$b" ] && git checkout "$b"
}
```

`fgb` removes the `remotes/<name>/` prefix, because `git checkout origin/x` would give a detached HEAD, while `git checkout x` creates a tracking branch.

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

#### fkc: switch the kubectl context

```bash
# fkc: switch the current kubectl context (this edits your kubeconfig for every terminal)
fkc() { local c; c=$(kubectl config get-contexts -o name | fzf --header 'kubectl context') && [ -n "$c" ] && kubectl config use-context "$c"; }
```

`kubectl config use-context` edits the kubeconfig, so the new context applies to every terminal and every later command. If the current context can be a production cluster, pick the context for one command instead: `kubectl --context "$(kubectl config get-contexts -o name | fzf)" get pods`.

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

`fport` only prints a line. To free a port, find the PID with `fport`, then `kill <pid>`.

#### fsys: manage a systemd service

```bash
# fsys [action]: pick a systemd service; status by default, "logs" follows its journal,
# any other systemctl action (start, stop, restart, enable, disable, ...) runs with sudo
fsys() {
  local act=${1:-status} u
  u=$( { systemctl list-units --type=service --all --no-legend --plain | awk '$2 != "not-found" {print $1}'
         systemctl list-unit-files --type=service --no-legend | awk '{print $1}'; } \
       | grep -v '@\.service$' | sort -u \
       | fzf --header "systemctl $act" --preview 'SYSTEMD_COLORS=1 systemctl status --no-pager {}') || return
  [ -n "$u" ] || return
  case $act in
    status) systemctl status --no-pager "$u" ;;
    logs)   journalctl -u "$u" -f -n 100 ;;
    *)      if [ "$(id -u)" -eq 0 ]; then systemctl "$act" "$u"; else sudo systemctl "$act" "$u"; fi ;;
  esac
}
```

| Run | Does |
|-----|------|
| `fsys` | `systemctl status` of the picked service |
| `fsys logs` | Follow its journal (`journalctl -u <unit> -f`, the last 100 lines first); `CTRL-C` stops |
| `fsys restart` | `sudo systemctl restart` it; also `start`, `stop`, `enable`, `disable` or any other `systemctl` action |

The list holds the loaded services and the installed ones that are not loaded (so a disabled service can be started too), with a live `systemctl status` preview. It leaves out units that no longer exist (`not-found`) and templates such as `getty@.service`, which can't be started without an instance name. As root it runs the action without `sudo`. `fsys` needs systemd, so it works on Linux, not on macOS; it was tested on Debian 12 with systemd 252.

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

### All in One Block

The same aliases and functions as above, in one block to paste into `~/.bashrc` or `~/.zshrc` in a single step.

```bash
# ---- fzf aliases and functions, works in bash and zsh ----

# ---- aliases ----
alias fm='fzf --multi'                                   # TAB marks rows, one per line on output
# fp: file picker with preview (bat, batcat, or the first 50 lines)
alias fp="fzf --preview 'if command -v bat >/dev/null; then bat --color=always --style=numbers {}; elif command -v batcat >/dev/null; then batcat --color=always --style=numbers {}; else head -n 50 {}; fi'"
alias fgl="git log --oneline --color=always | fzf --ansi --preview 'git show --color=always {1}'"   # browse commits

# ---- functions ----
# fe [query]: open the chosen file in $EDITOR
fe() { local f; f=$(fzf --query "$1" --select-1 --exit-0) && [ -n "$f" ] && ${EDITOR:-vim} "$f"; }

# fcd [dir]: cd into a subdirectory
fcd() { local d; d=$(command find "${1:-.}" -type d -not -path '*/.git/*' 2>/dev/null | fzf) && [ -n "$d" ] && cd "$d"; }

# fgb: check out a branch (local or remote)
fgb() {
  local b
  b=$(git branch --all | grep -v HEAD | sed 's#^[* ]*##; s#^remotes/[^/]*/##' | sort -u | fzf) && [ -n "$b" ] && git checkout "$b"
}

# fga: stage files picked from the modified and untracked ones (TAB for several)
fga() {
  local sel f files=()
  sel=$(git ls-files --modified --others --exclude-standard | sort -u | fzf -m) || return
  while IFS= read -r f; do [ -n "$f" ] && files+=("$f"); done <<< "$sel"
  [ "${#files[@]}" -gt 0 ] && git add -- "${files[@]}" && git status --short
}

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

# fgs: pick a stash and show it (use "git stash apply <name>" to restore)
fgs() {
  local s
  s=$(git stash list | fzf --preview 'git stash show -p --color=always $(echo {} | cut -d: -f1)' | cut -d: -f1) \
    && [ -n "$s" ] && git stash show -p --color=always "$s"
}

# faws: pick an AWS CLI profile and export it for this shell
faws() {
  local p
  p=$(aws configure list-profiles | fzf --header 'AWS_PROFILE') && [ -n "$p" ] && export AWS_PROFILE="$p" && echo "AWS_PROFILE=$p"
}

# fkc: switch the current kubectl context (this edits your kubeconfig for every terminal)
fkc() { local c; c=$(kubectl config get-contexts -o name | fzf --header 'kubectl context') && [ -n "$c" ] && kubectl config use-context "$c"; }

# fssh: pick a host from ~/.ssh/config and connect
fssh() {
  local h
  h=$(awk 'tolower($1)=="host" { for (i=2; i<=NF; i++) if ($i !~ /[*?!]/) print $i }' ~/.ssh/config 2>/dev/null | sort -u | fzf --header 'ssh host') \
    && [ -n "$h" ] && ssh "$h"
}

# fport: list listening TCP ports and print the chosen line (PID is column 2)
fport() { lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | sed 1d | fzf --header 'COMMAND PID ... NAME'; }

# fsys [action]: pick a systemd service; status by default, "logs" follows its journal,
# any other systemctl action (start, stop, restart, enable, disable, ...) runs with sudo
fsys() {
  local act=${1:-status} u
  u=$( { systemctl list-units --type=service --all --no-legend --plain | awk '$2 != "not-found" {print $1}'
         systemctl list-unit-files --type=service --no-legend | awk '{print $1}'; } \
       | grep -v '@\.service$' | sort -u \
       | fzf --header "systemctl $act" --preview 'SYSTEMD_COLORS=1 systemctl status --no-pager {}') || return
  [ -n "$u" ] || return
  case $act in
    status) systemctl status --no-pager "$u" ;;
    logs)   journalctl -u "$u" -f -n 100 ;;
    *)      if [ "$(id -u)" -eq 0 ]; then systemctl "$act" "$u"; else sudo systemctl "$act" "$u"; fi ;;
  esac
}

# _fdc: pick running containers and print their names (helper for fdl, fdx, fds)
_fdc() { docker ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}' | fzf "$@" | cut -f1; }

# fdl: follow the logs of a container
fdl() { local c; c=$(_fdc) && [ -n "$c" ] && docker logs -f --tail 100 "$c"; }

# fdx: open a shell in a container, bash if it exists, else sh
fdx() { local c; c=$(_fdc) && [ -n "$c" ] && docker exec -it "$c" sh -c 'command -v bash >/dev/null && exec bash || exec sh'; }

# fds: stop containers (TAB for several)
fds() { local sel c cs=(); sel=$(_fdc -m) || return; while IFS= read -r c; do [ -n "$c" ] && cs+=("$c"); done <<< "$sel"; [ "${#cs[@]}" -gt 0 ] && docker stop "${cs[@]}"; }
```

### How the Functions Are Written

- **They do nothing on ESC.** `fe`, `fcd` and `fgb` check that fzf returned something, so they never run a command on an empty selection.
- **Selections are read with a here-string.** `fga` and `fds` first store fzf's output (`sel=$(fzf -m)`) and then read it with `<<< "$sel"`. The shorter `done < <(fzf -m)` works in bash but not in zsh: there fzf never appears, so nothing gets staged or stopped.
- **Your aliases leak into functions.** Bash expands aliases when a function is defined, so an alias such as `alias find='find . -name'` (common in `~/.bash_aliases`) changes the `find` call inside `fcd`: it stops working. That is why `fcd` uses `command find`. If you add your own functions, put `command` in front of any command that you have aliased.
- **In zsh, `$EDITOR` is not split into words.** `fe` runs `${EDITOR:-vim} ...`, which works in bash for `EDITOR='code --wait'` but fails in zsh with `fe: command not found: code --wait`. In zsh use an editor that is a single word, or a small wrapper script.

## 7. Gotchas

- fzf reads from a pipe when there is one, and runs `FZF_DEFAULT_COMMAND` (or a built-in `find`) only when there is none. In scripts without a terminal, pipe the list in yourself.
- **Ubuntu and Debian rename `bat` to `batcat`.** The preview in `fp` handles both names. Commands that you type yourself, such as `fzf --preview 'bat {}'`, need the real name or a symlink (`ln -s "$(command -v batcat)" ~/.local/bin/bat`).
- A plain `fzf` lists files, not directories. Use `find . -type d | fzf` or `ALT-C`. (`CTRL-T` lists files and directories.)
- `{}` in a preview is quoted for the shell by fzf, but a line that contains single quotes can still confuse a complex preview command. Prefer `{1}`, `{2}` fields for tabular input.
- Old fzf versions (below 0.48.0) have no `--bash` and `--zsh`. Use the installer script, which writes `~/.fzf.bash`.

The commands and options come from the tutorial at penguin-gym-linux.com and were rewritten and extended here, not copied.
