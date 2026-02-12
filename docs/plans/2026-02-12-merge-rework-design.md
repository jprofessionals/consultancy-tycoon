# Merge Conflict Rework Design

## Overview

Replace the current binary left/right coin-flip merge conflict with a realistic three-panel merge flow: LOCAL, REMOTE, and RESULT.

## Data Model

### MergeConflict (Resource)

```
base_lines: Array[String]              # shared/non-conflicting context lines
conflict_chunks: Array[ConflictChunk]  # contested sections interleaved with base_lines
chunk_positions: Array[int]            # line index in base where each chunk appears
```

### ConflictChunk (inner class or Resource)

```
local_lines: Array[String]      # local branch version
remote_lines: Array[String]     # remote branch version
correct_resolution: String      # "local", "remote", "both", or "" (any valid)
both_order: String              # "local_first" or "remote_first" (when correct is "both")
```

## Conflict Generation

### Tier scaling
- **Tier 1**: 1 chunk, correct_resolution = "" (any pick works)
- **Tier 2**: 1-2 chunks, one may have a correct answer
- **Tier 3+**: 2-4 chunks, most have correct answers

### Two sources

**Algorithmic (easy/routine):** Take a base snippet, create trivial local/remote variants:
- Rename a variable on one side
- Change a constant value
- Add/remove a comment line
- Reorder parameters

**Curated (tricky):** Hand-written conflict pairs where only one resolution is logically correct:
- Local adds null-checking that remote's code path needs
- Remote fixes a bug that local's version still has
- Both sides add different needed functionality

Pool size: ~20-30 curated conflicts, unlimited algorithmic.

## Merge Flow

1. **Conflict triggers** (same chance calc as today, after review approval)
2. **IDE switches to merge view** — three-column layout: LOCAL | RESULT | REMOTE
3. **Auto-merge (Ctrl+A)** — non-conflicting base lines fill into RESULT. Conflict chunks stay highlighted.
4. **Resolve chunks one by one** — current chunk highlighted. Player picks:
   - **Ctrl+L** — Accept local
   - **Ctrl+R** — Accept remote
   - **Ctrl+B** — Accept both
5. **All resolved** — correct picks → task completes. Wrong pick on tricky chunk → FIXING state (1-2 fixes).

## UI Layout

### Three-panel merge view (replaces code_display during CONFLICT state)

```
┌─────────────┬─────────────┬─────────────┐
│   LOCAL      │   RESULT    │   REMOTE    │
│             │             │             │
│  var x = 1  │  (empty)    │  var x = 2  │
│  validate() │             │  check()    │
│             │             │             │
└─────────────┴─────────────┴─────────────┘
```

- LOCAL and REMOTE: read-only, show full file with conflict chunks highlighted
- RESULT: builds up as player resolves — base lines appear on auto-merge, chunk lines on pick
- Current chunk has bright border/highlight on all three panels
- Resolved chunks dim/green in LOCAL/REMOTE, show resolved text in RESULT

### Notification area

Shows current state:
- Before auto-merge: "MERGE CONFLICT — Ctrl+A to auto-merge"
- During resolution: "2 conflicts remaining — Ctrl+L local / Ctrl+R remote / Ctrl+B both"
- On wrong pick: flashes red briefly before entering FIXING

### Keyboard shortcuts

- **Ctrl+A** — Auto-merge (resolve non-conflicting lines)
- **Ctrl+L** — Accept local for current chunk
- **Ctrl+R** — Accept remote for current chunk
- **Ctrl+B** — Accept both for current chunk
- Clickable buttons also available as alternative

## Changes to CodingLoop

- `conflict_correct_side: String` → `merge_conflict: MergeConflict` (holds full conflict data)
- `_setup_conflict()` → uses MergeConflictFactory to generate conflict
- `resolve_conflict(chosen_side)` → `resolve_merge_chunk(resolution: String)` processes one chunk at a time
- New signal: `merge_chunk_resolved(chunk_index: int, was_correct: bool)`
- New signal: `merge_auto_merged()` (base lines resolved)
- `conflict_appeared` signal updated to pass MergeConflict instead of two strings

## Changes to IDEInterface

- New `_build_merge_view()` creates the three-column layout
- `_show_conflict_ui()` reworked to show merge view instead of two buttons
- `_unhandled_input()` handles Ctrl+A/L/R/B during CONFLICT state
- Merge view hidden/shown based on state (replaces code_display when active)

## Files to create/modify

### New files
- `src/data/merge_conflict.gd` — MergeConflict + ConflictChunk data classes
- `src/data/merge_conflict_factory.gd` — Generation logic (algorithmic + curated pool)

### Modified files
- `src/logic/coding_loop.gd` — Replace old conflict logic with chunk-based resolution
- `src/ide/ide_interface.gd` — Three-panel merge UI, new keyboard shortcuts
- `src/logic/ai_tool_runner.gd` — AI merge resolver works with new system
- `test/unit/test_coding_loop.gd` — Update conflict tests
- New: `test/unit/test_merge_conflict.gd` — Test factory + resolution logic
