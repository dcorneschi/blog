---
title: "Ghostty Cheatsheet"
date: 2026-11-04T17:00:00+02:00
draft: false
description: "Ghostty terminal reference: install, config file locations, the ghostty +actions CLI, default shortcuts on macOS and Linux side by side, a validated example config, keybind syntax with prefixes, sequences, chains and key tables, themes with light and dark mode and Liquid Glass, fonts and ligatures, custom shaders, the quick terminal and its size, shell integration and SSH terminfo, notifications, clipboard, scrollback and troubleshooting. Checked with Ghostty 1.4.0."
tags: ["ghostty", "terminal", "macos", "linux"]
categories: ["Cheatsheet"]
---

[Ghostty](https://ghostty.org) is a GPU-accelerated terminal emulator with a native UI on each platform (AppKit and Metal on macOS, GTK and OpenGL on
Linux). It works with zero configuration; everything else is one plain-text config file. The commands and outputs below are from **Ghostty 1.4.0** on
macOS; Linux shortcuts are taken from the 1.4.0 source (`src/config/Config.zig`).

## 1. Install and Config Location

```bash
brew install --cask ghostty          # macOS
sudo pacman -S ghostty               # Arch Linux
sudo snap install ghostty --classic  # Ubuntu and other snap systems
```

Other Linux distributions have packages too (Fedora COPR, Gentoo, NixOS, Alpine, ...); see the install page linked at the end.

```text
$ ghostty +version
Ghostty 1.4.0

Version
  - version: 1.4.0
  - channel: stable
Build Config
  - Zig version   : 0.17.0
  - build mode    : .fast
  - app runtime   : .none
  - font engine   : .coretext
  - renderer      : renderer.generic.Renderer(renderer.Metal)
  - libxev        : kqueue
```

On macOS the `ghostty` binary is at `/Applications/Ghostty.app/Contents/MacOS/ghostty`; shell integration adds that directory to `PATH` inside Ghostty.

| File | Where |
|------|-------|
| Config (all platforms) | `$XDG_CONFIG_HOME/ghostty/config.ghostty`, usually `~/.config/ghostty/config.ghostty` |
| Config (macOS, also read) | `~/Library/Application Support/com.mitchellh.ghostty/config.ghostty` |
| Your themes | `~/.config/ghostty/themes/` |
| Built-in themes (macOS) | `/Applications/Ghostty.app/Contents/Resources/ghostty/themes/` |
| Built-in themes (Linux) | `share/ghostty/themes/` under the install prefix |

On macOS Ghostty also reads the Application Support file. `ghostty +edit-config` opens whichever of the two exists and is non-empty (Application
Support if neither is) in `$VISUAL` or `$EDITOR`.

## 2. The `ghostty +action` CLI

| Command | What it does |
|---------|--------------|
| `ghostty +version` | Version and build details |
| `ghostty +show-config` | Your settings that differ from the defaults |
| `ghostty +show-config --default --docs` | Every option, its default and its documentation (4,334 lines in 1.4.0) |
| `ghostty +explain-config font-size` | Documentation of one option or keybind action |
| `ghostty +validate-config` | Check the config; `--config-file=<path>` for another file |
| `ghostty +edit-config` | Open the config file in your editor |
| `ghostty +list-keybinds --default` | All default shortcuts, in config syntax |
| `ghostty +list-actions --docs` | All keybind actions, with documentation |
| `ghostty +list-themes` | Theme preview (TUI); `--plain`, `--color=dark` or `light`, `--path` |
| `ghostty +list-fonts --family "JetBrains Mono"` | Fonts Ghostty can find, in the order it would pick them |
| `ghostty +show-face --string='a→✓🙂'` | Which font renders each character |
| `ghostty +list-colors` | Named RGB colors usable in the config |
| `ghostty +ssh <host>` | `ssh` with Ghostty's terminfo and environment set up |
| `ghostty +ssh-cache` | List or prune the hosts that already have the terminfo |
| `ghostty +crash-report` | List crash reports |
| `ghostty +boo` | The animation from the Ghostty website, in the terminal |

Every config option also works as a flag: `--font-size=16`, `--theme="Rose Pine"`. On macOS the terminal itself cannot be started from the CLI; use
`open -na Ghostty.app --args --font-size=16`. On Linux, `ghostty -e top` opens a window running `top`.

## 3. Default Shortcuts

macOS uses <kbd>Cmd</kbd>; Linux uses <kbd>Ctrl</kbd>+<kbd>Shift</kbd> where <kbd>Ctrl</kbd> alone would collide with the shell (<kbd>Ctrl</kbd>+<kbd>C</kbd>
must stay SIGINT).

### Windows, tabs and splits

| Action | macOS | Linux |
|--------|-------|-------|
| New window | `cmd+n` | `ctrl+shift+n` |
| New tab | `cmd+t` | `ctrl+shift+t` |
| Close the focused split (or its tab or window if it is the last) | `cmd+w` | – |
| Close tab / window / all windows | `cmd+alt+w` / `cmd+shift+w` / `cmd+alt+shift+w` | `ctrl+shift+w` / `alt+f4` / – |
| Next / previous tab | `cmd+shift+]` / `cmd+shift+[`, `ctrl+tab` / `ctrl+shift+tab` | `ctrl+page_down` / `ctrl+page_up`, `ctrl+shift+right` / `left`, `ctrl+tab` / `ctrl+shift+tab` |
| Go to tab 1 to 8, last tab | `cmd+1` … `cmd+8`, `cmd+9` | `alt+1` … `alt+8`, `alt+9` |
| Move tab left / right | – | `ctrl+shift+page_up` / `ctrl+shift+page_down` |
| Split right / down | `cmd+d` / `cmd+shift+d` | `ctrl+shift+o` / `ctrl+shift+e` |
| Focus split by direction | `cmd+alt+arrows` | `ctrl+alt+arrows` |
| Focus previous / next split | `cmd+[` / `cmd+]` | `ctrl+super+[` / `ctrl+super+]` |
| Resize split by 10 cells | `cmd+ctrl+arrows` | `ctrl+shift+super+arrows` |
| Equalize splits | `cmd+ctrl+=` | – |
| Zoom split (toggle) | `cmd+shift+enter` | `ctrl+shift+enter` |
| Fullscreen | `cmd+enter`, `cmd+ctrl+f` | `ctrl+enter` |
| Quit | `cmd+q` | `ctrl+shift+q` |

### Text, scrolling and search

| Action | macOS | Linux |
|--------|-------|-------|
| Copy / paste | `cmd+c` / `cmd+v` | `ctrl+shift+c` (also `ctrl+insert`) / `ctrl+shift+v` |
| Paste the selection | `cmd+shift+v` | `shift+insert` |
| Select all | `cmd+a` | `ctrl+shift+a` |
| Extend the selection | `shift+arrows`, `shift+page_up`/`page_down`, `shift+home`/`end` | `shift+arrows` (the others scroll) |
| Font size bigger / smaller / reset | `cmd+=` / `cmd+-` / `cmd+0` | `ctrl+=` / `ctrl+-` / `ctrl+0` |
| Scroll to top / bottom | `cmd+home` / `cmd+end` | `shift+home` / `shift+end` |
| Scroll a page | `cmd+page_up` / `cmd+page_down` | `shift+page_up` / `shift+page_down` |
| Previous / next prompt (shell integration) | `cmd+up` / `cmd+down`, `cmd+shift+up` / `down` | `ctrl+shift+up` / `ctrl+shift+down` |
| Clear screen and scrollback | `cmd+k` | – |
| Search | `cmd+f`; `cmd+g` / `cmd+shift+g` next / previous; `escape` ends | `ctrl+shift+f`; `escape` ends |
| Search for the selection | `cmd+e` | – |
| Screen contents to a file: copy path / paste path / open | `cmd+ctrl+shift+j` / `cmd+shift+j` / `cmd+alt+shift+j` | `ctrl+shift+super+j` / `ctrl+shift+j` / `ctrl+alt+shift+j` |

### Ghostty itself

| Action | macOS | Linux |
|--------|-------|-------|
| Command palette | `cmd+shift+p` | `ctrl+shift+p` |
| Open config | `cmd+,` | `ctrl+,` |
| Reload config | `cmd+shift+,` | `ctrl+shift+,` |
| Terminal inspector | `cmd+alt+i` | `ctrl+shift+i` |
| Undo / redo closing a tab, split or window | `cmd+z` (also `cmd+shift+t`) / `cmd+shift+z` | – |

On macOS, line editing works like other Mac apps: `cmd+left` / `cmd+right` send `Ctrl+A` / `Ctrl+E` (start and end of line), `cmd+backspace` sends
`Ctrl+U`, and `alt+left` / `alt+right` move by word. `ghostty +list-keybinds --default` prints the full list for your platform.

**Check before you trust a cheatsheet.** Many published Ghostty cheatsheets list their author's own bindings. A common pattern is to start the config with
`keybind = clear` (removes every default) and bind everything again, for example `Cmd+Ctrl+arrows` to move between splits, where the default moves with
`Cmd+Alt+arrows` and `Cmd+Ctrl+arrows` resizes. `ghostty +list-keybinds` (without `--default`) shows what your own config actually has.

Defaults that are often mixed up (macOS):

| You press | It does | Not this, which is on |
|-----------|---------|-----------------------|
| `cmd+enter` | Fullscreen | Zoom the split: `cmd+shift+enter` |
| `cmd+shift+d` | Split down | – (there is no default "duplicate tab") |
| `cmd+arrow_up` / `down` | Jump to the previous / next prompt | Move between splits: `cmd+alt+arrows` |
| `cmd+ctrl+arrows` | Resize the split | Move between splits: `cmd+alt+arrows` |
| `cmd+k` | Clear the screen and scrollback | Search: `cmd+f` |

**Rearrange with the mouse.** Tabs can be dragged in the tab bar or out into their own window. Since 1.4.0 splits can be dragged too, by the handle
that appears when you hover over a split; `drag-handle = auto` (default), `always` or `never` controls it.

## 4. The Config File

One `key = value` per line, `#` for comments, no sections. Repeatable keys (`keybind`, `palette`, `font-family`, `config-file`) add one more value each
time; an empty value (`font-family =`) resets the list.

```bash
ghostty +validate-config                             # check the default config file
ghostty +validate-config --config-file=./test.ghostty
ghostty +show-config                                 # what you changed, as Ghostty understood it
ghostty +show-config --default --docs | less         # every option with its documentation
ghostty +explain-config scrollback-limit-bytes        # one option
ghostty +explain-config --keybind=new_split           # one action
```

Reload with `cmd+shift+,` (Linux `ctrl+shift+,`) after editing; `+edit-config` does not reload by itself. Most options apply at once, a few only to
new windows or tabs (padding, scrollback limits), and `quick-terminal-position` on macOS needs a full restart.

`config-file` includes other files. A `?` prefix makes the include optional, and **includes are read after the whole file** they appear in, so
their values win no matter where the line is:

```text
config-file = ?local.ghostty
```

## 5. An Example Config

`~/.config/ghostty/config.ghostty`; `ghostty +validate-config` accepts it without a message (exit code 0):

```text
# Font
font-family = JetBrains Mono
font-size = 14
font-feature = -calt, -liga, -dlig

# Colors: follow the system light or dark mode
theme = light:Rose Pine Dawn,dark:Rose Pine
background-opacity = 0.95
background-blur = true

# Window
window-padding-x = 8
window-padding-y = 6
window-padding-balance = true
window-save-state = always
macos-titlebar-style = tabs
macos-option-as-alt = true

# Behaviour
copy-on-select = clipboard
mouse-hide-while-typing = true
confirm-close-surface = false
scrollback-limit-bytes = 100000000
shell-integration-features = ssh-env,ssh-terminfo,no-cursor
notify-on-command-finish = unfocused
notify-on-command-finish-after = 30s
notify-on-command-finish-action = bell,notify
clipboard-read = ask

# Quick terminal on Cmd+` from anywhere
keybind = global:super+grave_accent=toggle_quick_terminal
quick-terminal-position = top
quick-terminal-autohide = true

# tmux-style splits: Ctrl+a, then a key
keybind = ctrl+a>backslash=new_split:right
keybind = ctrl+a>minus=new_split:down
keybind = ctrl+a>h=goto_split:left
keybind = ctrl+a>j=goto_split:down
keybind = ctrl+a>k=goto_split:up
keybind = ctrl+a>l=goto_split:right
keybind = ctrl+a>z=toggle_split_zoom
keybind = ctrl+a>ctrl+a=text:\x01

# Shift+Enter sends a newline (Claude Code, other TUIs)
keybind = shift+enter=text:\n

# Copy only when something is selected, otherwise Ctrl+C reaches the program
keybind = performable:ctrl+c=copy_to_clipboard

# A resize mode: Ctrl+a r, then arrows, Escape to leave
keybind = ctrl+a>r=activate_key_table:resize
keybind = resize/arrow_left=resize_split:left,20
keybind = resize/arrow_right=resize_split:right,20
keybind = resize/arrow_up=resize_split:up,20
keybind = resize/arrow_down=resize_split:down,20
keybind = resize/escape=deactivate_key_table

# Chained actions: new tab, then split it
keybind = super+shift+n=new_tab
keybind = chain=new_split:right

# Machine-specific settings, if the file exists
config-file = ?local.ghostty
```

- `macos-titlebar-style = tabs` puts the tabs in the title bar; the other values are `native`, `transparent` (default) and `hidden`.
- `window-save-state = always` restores windows, tabs and splits at the next start (macOS only).
- `scrollback-limit-bytes` is **per terminal**, default 50 MB; idle history is compressed in memory.
- `ctrl+a>ctrl+a=text:\x01` keeps a way to send a real `Ctrl+A` (start of line in the shell) now that it is a prefix.

## 6. Keybind Syntax

```text
keybind = [prefix:]trigger=action[:parameter]
```

| Part | Examples | Meaning |
|------|----------|---------|
| Modifiers | `ctrl`, `shift`, `alt` (`opt`, `option`), `super` (`cmd`, `command`) | Any order, each once; `fn` is not supported |
| Keys | `a`, `arrow_up`, `page_down`, `enter`, `escape`, `backslash`, `minus`, `grave_accent`, `f4` | A character (`a`) follows the keyboard layout; a W3C key code (`key_a` or `KeyA`, `digit_1`) is the physical key and wins over the character |
| `physical:` | `super+physical:one=goto_tab:1` | Match the key position; the prefix goes on the key, after the modifiers (`physical:ctrl+a` is invalid) |
| `catch_all` | `ctrl+catch_all=ignore` | Any key not bound otherwise |
| Sequence | `ctrl+a>n=new_window` | Press `ctrl+a`, release, then `n`; no timeout |
| `global:` | `global:cmd+grave_accent=toggle_quick_terminal` | Works when Ghostty is not focused (macOS: needs Accessibility permission) |
| `all:` | `all:cmd+k=clear_screen` | Run on every terminal, not just the focused one |
| `unconsumed:` | `unconsumed:ctrl+a=reload_config` | Run the action **and** send the key to the program |
| `performable:` | `performable:ctrl+c=copy_to_clipboard` | Only consume the key if the action can run (here: a selection exists) |
| `chain=` | `keybind = chain=goto_split:left` | Add one more action to the previous keybind (1.3.0+) |
| Key table | `resize/escape=deactivate_key_table` | Bindings active only after `activate_key_table:resize` (1.3.0+) |

| Action | What it sends or does |
|--------|----------------------|
| `text:\x15` | A string, Zig escape syntax (`\x15` is `Ctrl+U`, `\n` a newline) |
| `csi:A` | `ESC [` + text (`csi:A` is cursor up) |
| `esc:d` | `ESC` + text (`esc:d` deletes the next word) |
| `ignore` | Swallow the key |
| `unbind` | Remove a default binding so the key reaches the program |
| `keybind = clear` | Remove **all** bindings so far, defaults included |

**Open the screen or the whole history in an editor.** The `write_*_file` actions save to a temporary file and `copy` or `paste` its path, or `open`
it with the OS default for text files (`open` on macOS, `xdg-open` on Linux):

```text
keybind = super+shift+o=write_screen_file:open
keybind = super+alt+o=write_scrollback_file:open
```

Set the default text editor for `.txt` files in Finder (Get Info, Open with, Change All) or `xdg-mime` to land in your own editor.

`ghostty +list-actions` lists the 88 actions of 1.4.0. The common ones: `new_split:right|down|left|up|auto`, `goto_split:left|right|up|down|previous|next`,
`resize_split:<direction>,<cells>`, `toggle_split_zoom`, `equalize_splits`, `goto_tab:<n>`, `move_tab:<offset>`, `jump_to_prompt:-1`,
`write_scrollback_file:open`, `toggle_quick_terminal`, `toggle_command_palette`, `prompt_tab_title`, `toggle_readonly`, `reload_config`.

A sequence with `>` on the command line needs quotes: `--keybind='ctrl+a>n=new_window'`. Defining a sequence on a prefix that was bound before
(`ctrl+a`) replaces that binding.

## 7. Themes and Fonts

```text
$ ghostty +list-themes --plain | wc -l
     819
$ ghostty +list-themes --plain --color=dark | wc -l
     637
$ ghostty +list-themes --plain --color=light | wc -l
     182
$ ghostty +list-themes --plain --path | grep 'Rose Pine Dawn'
Rose Pine Dawn (resources) /Applications/Ghostty.app/Contents/Resources/ghostty/themes/Rose Pine Dawn
```

- In a terminal, `ghostty +list-themes` opens a live preview; `F1` shows its keys, `Esc` leaves.
- `theme = light:Rose Pine Dawn,dark:Rose Pine` follows the system appearance; both halves are required.
- Names are case-sensitive and use the file name without the `(resources)` tag. A path (`theme = /path/to/file`) also works.
- A theme is just a config file. Colors you set after it (`background`, `foreground`, `palette = 4=#7aa2f7`) override it. Only use theme files you trust.
- `background-blur` needs `background-opacity` below 1: `true` (intensity 20) or a number. On **macOS 26**, `macos-glass-regular` or
  `macos-glass-clear` use the system's Liquid Glass effect instead.

Fonts: the default is the built-in **JetBrains Mono**, with Nerd Font symbols included, so no patched font is needed for prompt icons.

```text
$ ghostty +show-face --string='a→✓🙂'
U+61 « a » found in face “JetBrains Mono”.
U+2192 « → » found in face “JetBrains Mono”.
U+2713 « ✓ » found in face “JetBrains Mono”.
U+1F642 « 🙂 » found in face “Apple Color Emoji”.
```

| Option | Example | Use |
|--------|---------|-----|
| `font-family` | `font-family = "Fira Code"` | Repeat for fallbacks; `font-family-bold`, `-italic`, `-bold-italic` per style |
| `font-size` | `font-size = 13.5` | Points; half points give odd pixel sizes on Retina |
| `font-feature` | `font-feature = -calt, -liga, -dlig` | Turn ligatures off (`-calt` alone for programming ligatures) |
| `font-thicken` | `font-thicken = true` | Heavier strokes on macOS |
| `font-synthetic-style` | `font-synthetic-style = false` | Do not fake bold or italic when the font lacks them (or `no-bold`, ...; `bold-italic` must be turned off separately) |
| `adjust-cell-height` | `adjust-cell-height = 10%` | Line spacing |
| `font-codepoint-map` | `font-codepoint-map = U+E000-U+F8FF=Symbols Nerd Font` | A font for a Unicode range |

### Custom Shaders

`custom-shader` runs a GLSL fragment shader (Shadertoy style, a `mainImage` function) over the terminal. Ghostty passes extras such as the cursor
position, color and style and the time of the last cursor move, which is what the popular cursor-trail and cursor-warp shaders use:

```text
custom-shader = shaders/cursor_warp.glsl
custom-shader-animation = true
```

- The path is relative to the config directory; repeat the option to stack shaders, in order.
- A broken shader is only reported in the log and can leave the window **black**: comment out `custom-shader` and reload.
- `custom-shader-animation`: `true` (default) animates in the focused terminal only, `always` in every terminal (more CPU), `false` renders only when
  the screen changes, so nothing animates.

## 8. Quick Terminal

A drop-down terminal that slides in from a screen edge. There is **no default shortcut**; bind one, usually global:

```text
keybind = global:super+grave_accent=toggle_quick_terminal
quick-terminal-position = top
quick-terminal-size = 40%
quick-terminal-screen = main
quick-terminal-autohide = true
quick-terminal-animation-duration = 0.2
```

- `quick-terminal-position`: `top` (default), `bottom`, `left`, `right` or `center`.
- `quick-terminal-size`: `%` of the screen or `px`, a bare number is an error. One value sets the height for `top`/`bottom` (the width for `left`/`right`);
  a second value after a comma sets the other side: `50%,500px`, or `70%,70%` for a floating window with `position = center`.
- `quick-terminal-screen`: `main` (default), `mouse` (the screen under the pointer) or `macos-menu-bar`.
- `quick-terminal-animation-duration = 0` turns the slide off.
- `quick-terminal-autohide`: hide when it loses focus; default `true` on macOS, `false` on Linux.

- One quick terminal at a time; its state survives hiding but not an app restart.
- macOS: no tabs in the quick terminal; Accessibility permission is needed for the `global:` binding.
- Linux: Wayland compositors with `wlr-layer-shell` only (not GNOME, not X11); global shortcuts through the XDG Global Shortcuts portal (KDE 5.27+,
  GNOME 48+).

## 9. Shell Integration and SSH

Ghostty injects its shell integration automatically for **bash, zsh, fish, elvish and nushell**. It gives prompt marks (`jump_to_prompt`), the working
directory for new tabs and splits, titles, a bar cursor at the prompt, and "is a command running?" for close confirmations.

```text
shell-integration = detect
shell-integration-features = ssh-env,ssh-terminfo,no-cursor
```

`shell-integration` is `detect` (by the shell's file name), `none`, or a fixed `bash`, `zsh`, `fish`, `elvish` or `nushell`.

Defaults in 1.4.0: `cursor,no-sudo,title,no-ssh-env,no-ssh-terminfo,path`. Features you do not list keep their default; prefix `no-` to turn one off.

| Feature | Effect |
|---------|--------|
| `cursor` | Bar cursor at the prompt |
| `sudo` | `sudo` keeps Ghostty's terminfo |
| `title` | Window title from the shell |
| `ssh-env` | `ssh` sends `TERM=xterm-256color`, `COLORTERM`, `TERM_PROGRAM`, `TERM_PROGRAM_VERSION` |
| `ssh-terminfo` | On the first connection, installs the `xterm-ghostty` terminfo on the host with `tic`, then keeps `TERM=xterm-ghostty` |
| `path` | Adds the `ghostty` binary's directory to `PATH` |

With either SSH feature on, `ssh` runs through `ghostty +ssh`. Hosts that already got the terminfo are cached:

```bash
ghostty +ssh-cache                       # list
ghostty +ssh-cache --remove=user@host    # force a reinstall next time
ghostty +ssh-cache --prune=30d
```

**The classic problem**: without those features, `TERM=xterm-ghostty` reaches a server that does not know it, and `vim`, `less`, `htop` or `clear`
complain `unknown terminal "xterm-ghostty"` (or `missing or unsuitable terminal`). Copy the entry once by hand:

```bash
infocmp -x xterm-ghostty | ssh user@host -- tic -x -
```

On macOS, `infocmp` needs `TERMINFO=/Applications/Ghostty.app/Contents/Resources/terminfo` outside Ghostty. On a fresh Debian 13 host:

```text
before: tput: unknown terminal "xterm-ghostty"
"<stdin>", line 2, col 31, terminal 'xterm-ghostty': older tic versions may treat the description field as an alias
after:  256 colors
```

The `tic` line is a warning, not an error. Alternatively set `term = xterm-256color` in the config for every session, at the cost of the extra
features `xterm-ghostty` describes.

## 10. Notifications, Clipboard and Scrollback

| Option | Default | Notes |
|--------|---------|-------|
| `notify-on-command-finish` | `never` | `unfocused` or `always`; needs shell integration (1.3.0+) |
| `notify-on-command-finish-after` | `5s` | Only for commands that ran longer, e.g. `30s`, `1m30s` |
| `notify-on-command-finish-action` | `bell,no-notify` | **Only the bell by default**: add `notify` for a desktop notification (`bell,notify`) |
| `clipboard-read` | `ask` | Programs reading the clipboard through OSC 52: `ask`, `allow`, `deny` |
| `clipboard-write` | `allow` | Programs writing to it (tmux and Neovim copy over SSH this way) |
| `clipboard-paste-protection` | `true` | Confirms pastes that contain newlines or control characters |
| `clipboard-paste-bracketed-safe` | `true` | No confirmation when the program has bracketed paste on (shells, editors), since it will not run the pasted lines |
| `copy-on-select` | `none` on macOS, `primary` on Linux | `clipboard` copies a selection to the system clipboard; `both` (1.4.0) to both clipboards on Linux |
| `scrollback-limit-bytes` | `50000000` | Per terminal; `unlimited` possible; compressed when idle |
| `scrollback-limit-lines` | `unlimited` | Whichever limit is reached first trims history |
| `scrollback-compression` | `true` | Compresses history pages while idle, typically to 10–30% of their memory; the limits still count the uncompressed size, so you keep the same amount of history |
| `scrollbar` | `system` | `never` to hide it |
| `confirm-close-surface` | `true` | `always` confirms even at an idle prompt, `false` never |
| `link-previews` | `true` | `osc8` shows them only for real hyperlinks |

## 11. Troubleshooting

`+validate-config` names the file, the line and the problem (paths shortened here):

```text
$ ghostty +validate-config --config-file=broken.ghostty
…/broken.ghostty:1:font-size: invalid value "big"
…/broken.ghostty:2:windw-padding-x: unknown field
…/broken.ghostty:4:keybind: unknown error error.InvalidAction
theme "No Such Theme" not found, tried path "~/.config/ghostty/themes/No Such Theme"
theme "No Such Theme" not found, tried path "/Applications/Ghostty.app/Contents/Resources/ghostty/themes/No Such Theme"
```

The exit code is 1, so it works in a dotfiles CI check.

| Problem | Fix |
|---------|-----|
| `cursor-style = block` has no effect at the prompt | Shell integration sets a bar cursor at the prompt: add `shell-integration-features = no-cursor`. Styles: `block`, `bar`, `underline`, `block_hollow`; `cursor-style-blink = false` stops blinking |
| `invalid value "top        # top, ..."` | Comments must be on their own line: `#` after a value becomes part of the value |
| `unknown terminal "xterm-ghostty"` over SSH | `shell-integration-features = ssh-terminfo` or the `infocmp \| ssh ... tic -x -` line above |
| `Alt+b` / `Alt+f` print `∫` / `ƒ` on macOS | `macos-option-as-alt = true` (or `left`); it is on by default only for the U.S. layouts |
| After `macos-option-as-alt = true`, Option no longer types `~`, `@`, `[` (German and other layouts) | Use `left`, so the right Option still types characters, or bind the one you miss: `keybind = alt+n=text:~` |
| New tabs open next to the current one, you want them last | `window-new-tab-position = end` (default `current`) |
| `Shift+Enter` submits instead of a new line in a TUI | `keybind = shift+enter=text:\n` |
| A program never sees a shortcut | A Ghostty default uses it: `keybind = <trigger>=unbind`, then reload |
| Config change has no effect | Reload (`cmd+shift+,`); check `+show-config` to see what Ghostty understood; padding and scrollback apply to new terminals |
| Theme not found | Names are case-sensitive and must match `+list-themes --plain` without `(resources)` |
| Global shortcut does nothing on macOS | System Settings, Privacy & Security, Accessibility: allow Ghostty, then reload |
| Ligatures in code | `font-feature = -calt` |
| Wrong font for a character | `ghostty +show-face --string='…'`, then `font-codepoint-map` |
| What does a key send? | Terminal inspector (`cmd+alt+i`, Linux `ctrl+shift+i`) shows key events and their encoding |
| Colors look wrong in tmux | In `~/.tmux.conf`: `set -as terminal-features ',xterm-ghostty:RGB'` |

## See Also

- [Ghostty documentation](https://ghostty.org/docs) and [configuration reference](https://ghostty.org/docs/config/reference)
- [Keybind actions](https://ghostty.org/docs/config/keybind/reference)
- [Installing Ghostty](https://ghostty.org/docs/install/binary)
- [Terminfo and SSH](https://ghostty.org/docs/help/terminfo)
- [tmux Cheatsheet](/cheatsheet/tmux/)
- [fzf Cheatsheet](/cheatsheet/fzf/)
