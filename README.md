# claude-code-context-statusline

**Always see how much of your context window you've used.**

```
[Opus 4.8] ▓▓▓░░░░░░░ 33% 334k/1M  ·  ~/code/my-project (main)
```

One line, left-packed. Context first — where your eye already is — then the directory and
branch.

Claude Code doesn't show your context usage by default. It only warns you once you're
already near the limit — and by then auto-compact is about to fire and you've lost the
chance to `/handoff` cleanly or wrap up a phase on your own terms.

## What you get

- **A bar, a percentage, and the raw token count** (`334k/1M`), updated every turn.
- **Colour that warns you early.** Green under 70%, **amber at 70%**, **red at 85%** — so
  there's a band where you can still make a decision instead of being surprised.
- **Directory and git branch**, packed in right after. Not right-aligned — see the note
  below on why that doesn't work.
- **No cost display** by default. Turn it on if you want it (see [Options](#options)).

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/tokyovo/claude-code-context-statusline/main/install.sh | bash
```

Then restart Claude Code.

<details>
<summary>Prefer to do it by hand?</summary>

```bash
mkdir -p ~/.claude
curl -fsSL https://raw.githubusercontent.com/tokyovo/claude-code-context-statusline/main/statusline.sh \
  -o ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
```

Then add this to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh",
    "padding": 0
  }
}
```

</details>

## Requirements

- **Claude Code ≥ 2.1.132.** Older versions don't send context data to the status line.
  Check with `claude --version`.
- **`jq`** — `brew install jq` on macOS, `sudo apt install jq` on Debian/Ubuntu.
- **bash** and **git** (git only for the branch name; it degrades gracefully without it).

## Options

Set these as environment variables to change the behaviour:

| Variable | Default | What it does |
| --- | --- | --- |
| `STATUSLINE_BAR_WIDTH` | `10` | Characters in the bar |
| `STATUSLINE_WARN_AT` | `70` | Percentage at which the bar turns amber |
| `STATUSLINE_CRIT_AT` | `85` | Percentage at which it turns red |
| `STATUSLINE_SHOW_COST` | `0` | Set to `1` to append the session cost in USD |

Or just edit `~/.claude/statusline.sh` — it's a short bash script and it re-runs on every
turn, so there's nothing to restart while you're tweaking it.

## How it works

Before each turn, Claude Code pipes a JSON blob to your status line command on stdin and
renders whatever it prints. The useful part looks like this:

```json
{
  "model": { "display_name": "Opus 4.8" },
  "workspace": { "current_dir": "/home/you/code/my-project" },
  "context_window": {
    "used_percentage": 38.2,
    "remaining_percentage": 61.8,
    "total_input_tokens": 382104,
    "context_window_size": 1000000
  },
  "cost": { "total_cost_usd": 1.42 }
}
```

`used_percentage` is **pre-calculated** — which is the whole reason this script is short.
Earlier approaches had to find the session transcript on disk and sum token counts out of
the JSONL by hand. That's no longer necessary.

### Why not right-align the path?

Tempting, and it *looks* like it should work: Claude Code exports **`$COLUMNS`** to the
script's environment, so you can pad the line out to the terminal width. Don't — **Claude
Code clips the status line before the real terminal edge**, so anything you push out to
column `$COLUMNS` gets its tail truncated (`~/workspace/personal (m…`). Keep it left-packed
and nothing is ever cut.

Two other things worth knowing if you're writing your own: `/dev/tty` is **not** available
to the status line process, so `tput cols </dev/tty` and `stty size` both fail. And the
JSON carries more than the docs list — `effort`, `fast_mode`, `thinking`, `rate_limits`,
`session_name`, `transcript_path` are all in there.

## Uninstall

```bash
jq 'del(.statusLine)' ~/.claude/settings.json > /tmp/s && mv /tmp/s ~/.claude/settings.json
rm ~/.claude/statusline.sh
```

The installer also drops a timestamped backup at `~/.claude/settings.json.bak.*` before it
touches anything, so you can always restore whatever you had before.

## A note on why the amber band matters

Claude Code auto-compacts when you run out of room — it summarises the earlier turns and
carries on. That's usually fine, but not always: compacting in the middle of a phase can
lose the thread, and there are workflows where you'd much rather stop and hand off
deliberately than have the conversation silently rewritten underneath you.

The other reason to watch the number: models reason less sharply as the window fills, well
before it's actually full. Seeing 74% in amber is a nudge to wrap up the current thought
rather than start a new one.

## Licence

MIT
