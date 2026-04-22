<!-- AUTO-GENERATED from .claude/ — do not edit directly. Run: bash .claude/scripts/sync-claude.sh -->
---
name: open-pr
description: Create a PR from the current branch, request Copilot review, and walk through comments.
---
# Create PR & Copilot Review

## Your Role

You handle the full PR lifecycle after implementation is complete. You create the PR, request Copilot review, walk through review comments with the user, and close out the issue.

**Prerequisites:** The user has already:
- Implemented and tested the code (via `/do-task`)
- Changes are committed to the feature branch (the implementation agent commits directly)

---

## Phase 1: PR Creation

### 1. Verify Branch Has a Linked Issue

Check the current branch and find its linked issue:

```bash
# Get current branch name
git branch --show-current

# The branch was created via 'gh issue develop', so the name contains the issue number
# e.g., "42-add-http-tracing" -> issue #42
```

If the issue number cannot be determined from the branch name, ask the user:

```
AskUserQuestion(
  title="Link PR to Issue",
  questions=[{
    id: "issue-number",
    prompt: "Which GitHub Issue should this PR close? Enter the issue number.",
    options: [
      {id: "specify", label: "I'll type the issue number"}
    ]
  }]
)
```

### 2. Read the Issue for Context

```bash
gh issue view <number> --json title,body,labels
```

Use the issue title, summary, and acceptance criteria to draft the PR.

### 3. Create the PR

#### PR Title

Determine the PR title prefix from the branch name:

| Branch Prefix | PR Title Prefix |
|---------------|-----------------|
| `feat/`       | `feat:`         |
| `bug/`        | `fix:`          |
| `fix/`        | `fix:`          |
| `docs/`       | `docs:`         |
| `test/`       | `test:`         |
| `hotfix/`     | `fix:`          |
| `task/`       | `task:`         |

For branches created via `gh issue develop` (e.g., `42-add-http-tracing`), infer the prefix from the issue labels: `feature` -> `feat:`, `bug` -> `fix:`, `task` -> `task:`. If ambiguous, default to `feat:`.

#### PR Body

Read the template at `.claude/templates/pr-body.md` and fill in placeholders:

| Placeholder | How to fill |
|-------------|-------------|
| `{{ISSUE_NUMBER}}` | The linked issue number |
| `{{SUMMARY}}` | 1-3 bullet points from the issue summary and what was implemented |
| `{{FEATURE}}`, `{{BUGFIX}}`, `{{DOCS}}`, `{{REFACTOR}}`, `{{TASK}}` | Set to `x` for the matching type (from branch prefix or issue labels), ` ` for the rest |
| `{{BREAKING_CHANGES}}` | Describe breaking changes, or `None.` if there are none |
| `{{FILES_CHANGED}}` | Markdown table of files changed with a brief description of each change (use `git diff --stat` to enumerate) |
| `{{NEW_TESTS}}` | List of new or modified test files with what they cover, or `None.` if no tests were added |

#### Create

Determine the correct base branch. Feature branches typically target `integration/vX.Y`.

Create the PR directly:

```bash
# Use heredoc for multi-line PR body (avoids shell escaping issues)
gh pr create \
  --title "<prefix>: [description from issue] (#<issue-number>)" \
  --body "$(cat <<'EOF'
[filled-in PR template content here]
EOF
)"
```

Use a heredoc or `--body-file` with process substitution for reliable multi-line content. No intermediate approval is needed — the user confirmed intent by invoking `/open-pr`.

### 4. Post Status Comment on Issue

```bash
PR_NUM=$(gh pr view --json number -q .number)
gh issue comment <issue-number> --body "PR #$PR_NUM created. Copilot review requested."
```

### 5. Request Copilot Review

```bash
gh pr edit $PR_NUM --add-reviewer "@copilot"
```

---

## Phase 2: Copilot Review Walkthrough

### 1. Wait for Copilot

Tell the user:

> "PR #[number] created and Copilot review has been requested. Let me know when Copilot has finished reviewing (say 'copilot done' or similar)."

**Wait for the user to confirm Copilot is done before proceeding.**

### 2. Pull Review Comments

Once the user confirms:

```bash
# Get the repo owner/name
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)

# Fetch PR review comments (include node_id for thread resolution)
gh api repos/$REPO/pulls/<pr-number>/comments \
  --jq '.[] | {id: .id, node_id: .node_id, path: .path, line: .line, body: .body, user: .user.login}'

# Fetch PR reviews (for top-level review summaries)
gh api repos/$REPO/pulls/<pr-number>/reviews \
  --jq '.[] | {id: .id, state: .state, body: .body, user: .user.login}'
```

### 2b. Build Thread Resolution Map

Query all review threads for the PR via GraphQL. Build a map from comment `node_id` to thread `id` so each thread can be resolved after replying:

```bash
gh api graphql -f query='
  query($owner: String!, $repo: String!, $pr: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $pr) {
        reviewThreads(first: 100) {
          nodes {
            id
            isResolved
            comments(first: 1) {
              nodes { id }
            }
          }
        }
      }
    }
  }
' -f owner="<owner>" -f repo="<repo>" -F pr=<pr-number>
```

Parse the response to create a lookup: `comment_node_id -> thread_id`. This is used in Step 3 to resolve threads after replying.

### 3. Walk Through Each Comment

Process each Copilot comment sequentially using the same pattern as `/review_finding`:

For each comment, use one `AskUserQuestion` call:

1. **Describe the issue** — What Copilot flagged and why it matters.
2. **Show the code** — Read the referenced file and line to show the current code.
3. **Present options** via `AskUserQuestion`:

```
AskUserQuestion(
  title="Copilot Review — Comment [N] of [total]",
  questions=[{
    id: "copilot-comment-<id>",
    prompt: "File: <path>:<line>\n\nCopilot says:\n> <comment body>\n\nCurrent code:\n```\n<code snippet>\n```\n\n[Agent's assessment of whether this is valid and what the fix would be]",
    options: [
      {id: "fix", label: "Fix now: [brief description of the fix]"},
      {id: "better", label: "Better approach: [agent proposes alternative]"},
      {id: "skip", label: "Skip (low risk / disagree with Copilot)"},
      {id: "defer", label: "Defer (create a separate issue for this)"}
    ]
  }]
)
```

4. **Act on the user's choice, then reply and resolve (MANDATORY for every disposition):**

   - **Fix now:** Implement the fix, show the change, tell the user to review and commit. Reply:
     ```bash
     gh api repos/$REPO/pulls/comments/<comment-id>/replies \
       -f body="Fixed — <brief description of the change>."
     ```

   - **Better approach:** Implement the alternative, show the change, tell the user to review and commit. Reply:
     ```bash
     gh api repos/$REPO/pulls/comments/<comment-id>/replies \
       -f body="Addressed with alternative approach — <description>."
     ```

   - **Skip:** Reply with rationale (mandatory, not optional):
     ```bash
     gh api repos/$REPO/pulls/comments/<comment-id>/replies \
       -f body="Acknowledged — skipping. Rationale: <reason>."
     ```

   - **Defer:** Create a new issue, then reply with the reference:
     ```bash
     gh issue create --title "TASK: [description from Copilot comment]" --body "..." --label "task"
     gh api repos/$REPO/pulls/comments/<comment-id>/replies \
       -f body="Deferred to #<new-issue-number>."
     ```

5. **Resolve the review thread (MANDATORY after every reply):**

   Using the thread ID from the map built in Step 2b:
   ```bash
   THREAD_ID=<looked up from comment_node_id -> thread_id map>
   gh api graphql -f query='
     mutation($threadId: ID!) {
       resolveReviewThread(input: {threadId: $threadId}) {
         thread { isResolved }
       }
     }
   ' -f threadId="$THREAD_ID"
   ```

   If the GraphQL call fails (e.g., permissions), log a warning and continue — the reply itself is sufficient to show the comment was addressed.

6. **Move to next comment** and repeat.

### 4. After All Comments Resolved

Once every comment has been handled (fixed, skipped, or deferred):

1. Run the full test suite to verify fixes haven't broken anything:
   ```bash
   {{toolchain.test_cmd_full}}
   ```
2. Run formatting and linting:
   ```bash
   {{toolchain.format_cmd}}
   {{toolchain.lint_cmd}}
   ```
3. Tell the user to review and commit any remaining changes.
4. Post status comment on the issue:
   ```bash
   gh issue comment <issue-number> --body "Copilot review resolved. All comments addressed."
   ```

---

## Phase 3: Closure

### 1. Confirm Ready to Merge

Tell the user:

> "All Copilot review comments have been resolved. Please verify all changes are committed, then merge the PR. The linked issue (#[number]) will auto-close when the PR merges (via 'Closes #[number]' in the PR body)."

### 2. Update Local Cache (Local Mode Only)

In local mode, update `.claude/features/ticket_tracker.md` to reflect the issue is complete:

```markdown
| #42 | TASK: Feature X | completed | PR #55 merged |
```

In GitHub mode, skip this step. The PR merge auto-closes the linked issue via "Closes #N" in the PR body, and `gh issue list` reflects the updated state.

### 3. Done

Prompt the user for the next step:

```
AskUserQuestion(
  title="PR Ready — Next Step",
  questions=[{
    id: "next-action",
    prompt: "Issue #[number] is ready for merge. After merging, the issue will auto-close. Want to pick up the next task?",
    options: [
      {id: "do-task", label: "Yes — start /do-task to pick the next issue"},
      {id: "new-task", label: "Plan new work — start /new-task"},
      {id: "done", label: "Done for now"}
    ]
  }]
)
```

If **do-task**: immediately execute the `/do-task` workflow inline.
If **new-task**: immediately execute the `/new-task` workflow inline.
If **done**: respond with "PR ready for merge. Use `/do-task` or `/new-task` when you're ready."
