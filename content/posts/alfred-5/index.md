---
title: "Alfred 5 for DevOps: Launcher, Powerpack and Workflows"
date: 2026-10-31T11:30:00+02:00
draft: false
description: "Alfred 5.8.1 on macOS 27.2: what is free and what needs the Powerpack, what changed across the 5.x releases, everyday keywords, where the settings live, and scripting Alfred with AppleScript."
tags: ["alfred", "macos", "automation"]
categories: ["devops"]
---

[Alfred](https://www.alfredapp.com/) is a keyboard launcher for macOS by Running with Crayons. You press a
hotkey (⌥Space by default), type a few letters, and Alfred opens the app, file, web search or workflow
you meant. Spotlight does part of this, but Alfred learns from what you pick, and with the paid
**Powerpack** it also does clipboard history, snippets and workflows: small automations you
start with a keyword or hotkey.

This post covers Alfred **5.8.1** (build 2349) on macOS 27.2 (Apple M4).

## Install and Version

```sh
brew install --cask alfred
```

```console
$ brew info --cask alfred | head -3
==> alfred (Alfred): 5.8.1,2349 (auto_updates)
Application launcher and productivity software
https://www.alfredapp.com/

$ defaults read "/Applications/Alfred 5.app/Contents/Info" CFBundleShortVersionString
5.8.1
$ defaults read "/Applications/Alfred 5.app/Contents/Info" CFBundleIdentifier
com.runningwithcrayons.Alfred
$ defaults read "/Applications/Alfred 5.app/Contents/Info" LSMinimumSystemVersion
10.14
$ du -sh "/Applications/Alfred 5.app"
 18M	/Applications/Alfred 5.app
$ lipo -archs "/Applications/Alfred 5.app/Contents/MacOS/Alfred"
x86_64 arm64
```

The app is 18 MB and Universal (Intel and Apple Silicon), and it still runs on macOS 10.14. The cask is
marked `auto_updates`: Alfred updates itself, so `brew upgrade` skips it unless you pass `--greedy`.

## Free vs Powerpack

The app itself is free. The Powerpack is a license key that unlocks the rest; there is no subscription.

| | Free | Powerpack |
|---|---|---|
| App launching, file search, web searches, calculator, dictionary | Yes | Yes |
| System commands (sleep, empty trash, eject, ...) | Yes | Yes |
| Clipboard history (text, images, file paths) | | Yes |
| Snippets with auto-expansion | | Yes |
| Workflows and the Alfred Gallery | | Yes |
| Universal Actions, File Navigation and file actions | | Yes |
| Terminal / shell commands (`>`) | | Yes |
| Contacts viewer, Music mini player, 1Password bookmarks | | Yes |
| Custom themes, preference sync | | Yes |
| **Price** | Free | £34 (v5 license) or £59 (Mega Supporter, free lifetime upgrades) |

Prices are from the [Powerpack page](https://www.alfredapp.com/powerpack/) in October 2026. A v5
license covers all 5.x releases. The 5.8 changelog already mentions "preparation for Alfred 6", which
a v5 license would not cover. Mega Supporter includes it.

## What Changed in 5.x

Alfred 5.0 came out in 2022, and the 5.x line has been updated ever since. These are the
main points from the [changelog](https://www.alfredapp.com/changelog/):

| Version | Date | Highlights |
|---|---|---|
| 5.0 | 2022 | New workflow editor with an object palette, Prefabs, workflow **User Configuration**, a debugger, Run Shortcut object, new default themes |
| 5.0.6 | 2022 | Alfred Gallery (early access): install and update workflows from Alfred, Homebrew dependencies |
| 5.1 | 2023 | **Automation Tasks** (ready-made actions such as trash a path), Clipboard History Quick Look |
| 5.5 | Mar 18, 2024 | Grid, Text, Image and PDF views for workflows, "View in Alfred" Universal Action, output caching |
| 5.5.1 | Sep 13, 2024 | macOS Sequoia, Passwords app support in Clipboard History |
| 5.6 | Feb 24, 2025 | Workflow variables in more places, workflow list sorted by category |
| 5.7 | Sep 15, 2025 | macOS Tahoe, rewritten System Settings search, AppleScript options to reveal workflows |
| 5.8 | Sep 11, 2026 | macOS 27 optimisations, preparation for Alfred 6 |
| 5.8.1 | Sep 24, 2026 | Bug fixes (the version used here) |

For workflow authors, the most useful changes are **User Configuration**, the **Gallery** and
**Automation Tasks**. User Configuration gives each installed workflow a settings sheet, so you no
longer edit variables by hand. The Gallery installs reviewed workflows and updates them for you.
Automation Tasks replace many small scripts that only moved, trashed or renamed a file.

## Everyday Keywords

With the default settings, these work in the Alfred box:

| Type | Does |
|---|---|
| `term` | Opens the best match: an app, a System Settings pane, a preference |
| `'` or Space, then a name | Quick file search (Spotlight index) |
| `open name`, `find name`, `in text` | Opens a file, reveals it in Finder, or searches file contents |
| `~` or `/` | Starts File Navigation in your home folder or at the root |
| `2*1024` | Calculator. The result is copied with Return |
| `define word`, `spell word` | Dictionary |
| `google k8s probes` | Web search. Custom searches use `{query}` in a URL |
| `> kubectl get pods` | Runs the command in your terminal app (Powerpack) |
| ⌥⌘C | Clipboard History viewer (Powerpack, off until you enable it) |

Two settings help on a DevOps laptop:

- In **Features → Default Results → Search Scope**, add `~/Code` (or wherever your repos live) and
  exclude `node_modules`-heavy folders. Otherwise file results become noisy.
- In **Features → Terminal**, choose iTerm2, Ghostty or a custom AppleScript, so `>` opens your terminal
  instead of Terminal.app (see [the terminal comparison](/posts/macos-terminal-emulators-compared/)).

## Where Alfred Keeps Its Settings

Everything you configure, including workflows, sits in one `Alfred.alfredpreferences` bundle:

```console
$ ls ~/Library/Application\ Support/Alfred
Alfred.alfredpreferences  Assistant  Automation  Databases  Gallery  Plugins
Workflow Data  history.json  powerpack.L2L74VCQGQ.dat  prefs.json  usage.data

$ ls ~/Library/Application\ Support/Alfred/Alfred.alfredpreferences
preferences  remote  workflows
```

Each workflow is a folder `workflows/user.workflow.<UUID>` with an `info.plist` and its scripts.
**Advanced → Set preferences folder** moves the whole bundle to Dropbox, iCloud Drive or a git
checkout. That is how sync works: there is no Alfred cloud. Settings that only make sense on one Mac (hotkeys
tied to that keyboard, for example) stay under `preferences/local/<hash>`, so two Macs can share the bundle.

## Scripting Alfred

Alfred has an AppleScript dictionary (`Alfred.sdef` in the app bundle). Its commands are `search`,
`action`, `browse`, `run trigger`, `reload workflow`, `reveal workflow`, `set configuration`,
`remove configuration` and `set theme`. All of them work through `osascript`, so a dotfiles script, a
Makefile or a Stream Deck button can drive Alfred. For example, this opens Alfred with text already typed:

```sh
osascript -e 'tell application id "com.runningwithcrayons.Alfred" to search "kubectl "'
```

## Alfred vs Spotlight vs Raycast

| | Spotlight | Alfred 5 | Raycast |
|---|---|---|---|
| Price | Built in | Free, Powerpack £34 / £59 one-time | Free, Pro subscription |
| Extensions | Shortcuts actions | Workflows (any script language, JSON out) | Extensions in TypeScript/React |
| Offline, no account | Yes | Yes | Account needed for some features |
| Clipboard history, snippets | Clipboard history since macOS 26 | Powerpack | Free |
| Settings in a folder you own | No | Yes (`Alfred.alfredpreferences`) | No (cloud sync is Pro) |

Alfred suits people who want a one-time purchase, no account, and settings they can keep in git.

## Sources

- [Alfred](https://www.alfredapp.com/) and [Powerpack](https://www.alfredapp.com/powerpack/)
- [Alfred changelog](https://www.alfredapp.com/changelog/)
- The AppleScript dictionary: `/Applications/Alfred 5.app/Contents/Resources/Alfred.sdef`
