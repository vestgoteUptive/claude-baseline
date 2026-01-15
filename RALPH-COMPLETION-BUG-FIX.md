# Ralph Multi-Story Completion Bug Fix

## Issue Report

**Reported:** Ralph stopped after completing 1 of 2 stories, despite `--max-iterations 5`

**Environment:**
```bash
./external/ralph/ralph/ralph.sh --work-dir . --agent claude --max-iterations 5
```

**PRD:** 2 user stories (US-002, US-003)

**Observed Behavior:**
- ✅ Iteration 1: Completed US-002
- ✅ Printed `<RALPH_DONE/>`
- ❌ Ralph exited: "Ralph finished in 1 iteration(s)."
- ❌ US-003 never started

**Expected Behavior:**
- ✅ Iteration 1: Complete US-002
- ✅ Iteration 2: Complete US-003
- ✅ Print `<RALPH_DONE/>` after both complete
- ✅ Ralph exits

---

## Root Cause

### Problem in `prompt.md`

The prompt instructed the agent to print the completion token **after completing each story**:

```markdown
### 8. Signal Completion

When your story passes all checks and is committed:

**Print this exact token on its own line:**

<RALPH_DONE/>

This tells Ralph to proceed to the next iteration.
```

This was **incorrect** because:
1. Agent completes one story ✅
2. Agent prints `<RALPH_DONE/>` ✅
3. Ralph sees the token and **exits immediately** ❌
4. Remaining stories never get processed ❌

### Why This Happened

Ralph's loop logic in `ralph.sh:181-186`:

```bash
if detect_done "$OUTPUT_LOG" "$COMPLETION_TOKEN"; then
  echo "✅ Completion token detected: $COMPLETION_TOKEN"
  echo "Ralph finished in $ITER iteration(s)."
  exit 0  # ← Exits immediately when token found
fi
```

The completion token means **"all work is done, exit now"**, not **"this iteration is done, continue"**.

---

## The Fix

### Updated `prompt.md`

Changed section 8 to properly check if all stories are complete:

```markdown
### 8. Check if All Stories Complete

After committing your story and updating prd.json, **check if there are more stories to do**:

```bash
# Count incomplete stories
INCOMPLETE=$(jq '[.userStories[] | select(.passes == false)] | length' prd.json)

if [ "$INCOMPLETE" -eq 0 ]; then
  echo "✅ All stories complete!"
  echo "<RALPH_DONE/>"
else
  echo "✅ Story complete. $INCOMPLETE story(ies) remaining."
  echo "Ralph will start the next iteration automatically."
fi
```

**IMPORTANT:**
- Only print `<RALPH_DONE/>` when **ALL** stories in prd.json have `"passes": true`
- If there are more stories to do, do NOT print the completion token
- Ralph will automatically start the next iteration to handle remaining stories
```

### Updated Examples

Both example workflows now include the completion check:

```bash
# After updating prd.json
INCOMPLETE=$(jq '[.userStories[] | select(.passes == false)] | length' prd.json)
if [ "$INCOMPLETE" -eq 0 ]; then
  echo "✅ All stories complete!"
  echo "<RALPH_DONE/>"
else
  echo "✅ US-001 complete. $INCOMPLETE story(ies) remaining."
fi
```

### Updated "Remember" Section

```markdown
## Remember

- **One story per iteration**
- **Quality checks must pass**
- **Commit when complete**
- **Update prd.json**
- **Check for remaining stories** ← NEW
- **Only print `<RALPH_DONE/>` when ALL stories complete** ← NEW
```

---

## How It Works Now

### Correct Multi-Story Flow

**Iteration 1:**
1. Agent finds US-002 (first incomplete story)
2. Implements US-002
3. Commits changes
4. Updates prd.json: `US-002.passes = true`
5. Checks: `INCOMPLETE = 1` (US-003 remains)
6. Prints: "✅ US-002 complete. 1 story(ies) remaining."
7. **Does NOT print `<RALPH_DONE/>`**
8. Ralph starts iteration 2

**Iteration 2:**
1. Agent finds US-003 (next incomplete story)
2. Implements US-003
3. Commits changes
4. Updates prd.json: `US-003.passes = true`
5. Checks: `INCOMPLETE = 0` (no stories remain)
6. Prints: "✅ All stories complete!"
7. **Prints `<RALPH_DONE/>`**
8. Ralph exits successfully

---

## Testing the Fix

### Before (Broken)

```bash
$ ./ralph/ralph.sh --agent claude --max-iterations 5
Ralph starting...
== Iteration 1 ==
...agent completes US-002...
<RALPH_DONE/>
✅ Completion token detected
Ralph finished in 1 iteration(s).

# US-003 never started! ❌
```

### After (Fixed)

```bash
$ ./ralph/ralph.sh --agent claude --max-iterations 5
Ralph starting...
== Iteration 1 ==
...agent completes US-002...
✅ US-002 complete. 1 story(ies) remaining.
Ralph will start the next iteration automatically.

== Iteration 2 ==
...agent completes US-003...
✅ All stories complete!
<RALPH_DONE/>
✅ Completion token detected
Ralph finished in 2 iteration(s).

# Both stories completed! ✅
```

---

## What You Should Do

### 1. Update Your Ralph Submodule

```bash
cd your-project
git submodule update --remote external/ralph
```

Or if Ralph is in a different location:
```bash
cd external/ralph
git pull origin main
```

### 2. Re-run Your PRD

```bash
cd /path/to/your-project
./external/ralph/ralph/ralph.sh --work-dir . --agent claude --max-iterations 5
```

Expected behavior:
- ✅ Iteration 1: Completes US-002
- ✅ Iteration 2: Completes US-003
- ✅ Exits after both complete

### 3. Verify Stories Are Complete

```bash
cat prd.json | jq '.userStories[] | {id, title, passes}'
```

Should show:
```json
{
  "id": "US-002",
  "title": "Cookie upload.",
  "passes": true
}
{
  "id": "US-003",
  "title": "Cookie user create update delete.",
  "passes": true
}
```

---

## Additional Notes

### Max Iterations Still Applies

Even with the fix, `--max-iterations` is still respected:

```bash
# If you have 5 stories but set --max-iterations 3
./ralph/ralph.sh --max-iterations 3

# Ralph will complete 3 stories and exit with warning:
# "Reached max iterations (3) without completing."
```

### State Directory

Ralph's state directory `.ralph/` will contain:
- `runs/1.log` - Output from iteration 1 (US-002)
- `runs/2.log` - Output from iteration 2 (US-003)
- `effective_prompt.md` - The full prompt sent to the agent
- `context.md` - Your project-specific context (if created)

### Manual Override

If you need to stop after one story for testing:

```bash
# Run just one iteration
./ralph/ralph.sh --max-iterations 1

# Check what was done
git log --oneline -3
cat prd.json | jq '.userStories[] | select(.passes == true)'
```

---

## Commit Details

**Branch:** `claude/add-llm-tools-ralph-Ngy3W`

**Commit:** `0c97391`

**Message:** "Fix Ralph completion logic for multi-story PRDs"

**Files Changed:**
- `ralph/prompt.md` (35 additions, 12 deletions)

**Changes:**
1. Section 8: "Signal Completion" → "Check if All Stories Complete"
2. Added jq command to count incomplete stories
3. Conditional completion token printing
4. Updated both examples
5. Updated "Remember" section

---

## FAQ

### Q: Why didn't Ralph loop automatically before?

**A:** The completion token (`<RALPH_DONE/>`) told Ralph "I'm completely done with everything" rather than "I'm done with this iteration". Ralph has no other way to know if you want to continue, so it trusted the agent's signal and exited.

### Q: Can I still manually stop after one story?

**A:** Yes! Use `--max-iterations 1`:
```bash
./ralph/ralph.sh --max-iterations 1
```

### Q: What if the agent forgets to check for remaining stories?

**A:** With this prompt update, the agent should consistently check. But if you hit the max iterations, Ralph will warn you and you can resume:
```bash
# Resume with higher limit
./ralph/ralph.sh --max-iterations 10
```

The agent will pick up from where it left off since git history and prd.json persist.

### Q: Does this work with Amp and OpenCode too?

**A:** Yes! The `prompt.md` is agent-agnostic. All agents (Claude, Amp, OpenCode) receive the same instructions and should follow the same completion logic.

---

## Summary

**Problem:** Ralph stopped after 1 story because the prompt incorrectly told agents to print the completion token after each story.

**Solution:** Updated prompt to check for remaining incomplete stories and only print the token when all stories are complete.

**Result:** Ralph now properly handles multi-story PRDs and will loop through all stories until complete or max iterations reached.

**Action Required:** Update your Ralph submodule and re-run your PRD.

---

## References

- **Commit:** 0c97391
- **Branch:** claude/add-llm-tools-ralph-Ngy3W
- **File:** ralph/prompt.md
- **Lines Changed:** Section 8, Examples 1-2, Remember section
