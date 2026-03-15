---
description: Record a demo video of the current feature branch, upload to Dropbox, and optionally post to a PR
---

Record a demo video for the current feature branch.

1. First, determine the current git branch name and find any associated open PR using `gh pr list --head <branch>`.

2. Run the demo recording script:
   ```
   ./scripts/record-demo.sh --dropbox
   ```
   If there is an open PR for this branch, add `--pr <number>` to automatically post the video as a PR comment.

3. If the build or tests fail, diagnose the issue and report it to the user. Common issues:
   - Simulator not booted: the script handles this automatically
   - Build failures: check for compilation errors
   - Test failures: the video still gets recorded, note which tests failed

4. After the script completes, report:
   - The Dropbox share link for the video
   - Whether it was posted to a PR (and which one)
   - Any test failures that occurred during recording

If the user specifies a PR number as an argument, use that instead of auto-detecting.
