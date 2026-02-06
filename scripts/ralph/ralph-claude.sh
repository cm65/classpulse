#!/bin/bash
# Ralph for Claude Code - Long-running AI agent loop
# Usage: ./ralph-claude.sh [max_iterations]

set -e

MAX_ITERATIONS=${1:-10}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PRD_FILE="$SCRIPT_DIR/prd.json"
PROGRESS_FILE="$SCRIPT_DIR/progress.txt"
PROMPT_FILE="$SCRIPT_DIR/prompt.md"
ARCHIVE_DIR="$SCRIPT_DIR/archive"
LAST_BRANCH_FILE="$SCRIPT_DIR/.last-branch"
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/ralph-$(date +%Y%m%d-%H%M%S).log"

# Create logs directory
mkdir -p "$LOG_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function - writes to BOTH console AND log file
log() {
  # 1. Echo to screen (with colors)
  echo -e "$1"
  # 2. Append to log file (colors stripped for clean text)
  echo -e "$1" | sed 's/\x1b\[[0-9;]*m//g' >> "$LOG_FILE"
}

# Initialize log file with header
echo "═══════════════════════════════════════════════════════" > "$LOG_FILE"
echo "  Ralph for Claude Code - Full Transcript" >> "$LOG_FILE"
echo "  Started: $(date)" >> "$LOG_FILE"
echo "  Log File: $LOG_FILE" >> "$LOG_FILE"
echo "═══════════════════════════════════════════════════════" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

log "${BLUE}═══════════════════════════════════════════════════════${NC}"
log "${BLUE}  Ralph for Claude Code${NC}"
log "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Logging to: $LOG_FILE${NC}"

# Check for claude CLI
if ! command -v claude &> /dev/null; then
    echo -e "${RED}Error: claude CLI not found${NC}"
    echo "Please install Claude Code: https://claude.ai/code"
    exit 1
fi

# Check for jq
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq not found${NC}"
    echo "Please install jq: brew install jq"
    exit 1
fi

# Archive previous run if branch changed
if [ -f "$PRD_FILE" ] && [ -f "$LAST_BRANCH_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  LAST_BRANCH=$(cat "$LAST_BRANCH_FILE" 2>/dev/null || echo "")

  if [ -n "$CURRENT_BRANCH" ] && [ -n "$LAST_BRANCH" ] && [ "$CURRENT_BRANCH" != "$LAST_BRANCH" ]; then
    DATE=$(date +%Y-%m-%d)
    FOLDER_NAME=$(echo "$LAST_BRANCH" | sed 's|^ralph/||')
    ARCHIVE_FOLDER="$ARCHIVE_DIR/$DATE-$FOLDER_NAME"

    echo -e "${YELLOW}Archiving previous run: $LAST_BRANCH${NC}"
    mkdir -p "$ARCHIVE_FOLDER"
    [ -f "$PRD_FILE" ] && cp "$PRD_FILE" "$ARCHIVE_FOLDER/"
    [ -f "$PROGRESS_FILE" ] && cp "$PROGRESS_FILE" "$ARCHIVE_FOLDER/"
    echo "   Archived to: $ARCHIVE_FOLDER"

    # Reset progress file for new run
    echo "# Ralph Progress Log" > "$PROGRESS_FILE"
    echo "Started: $(date)" >> "$PROGRESS_FILE"
    echo "---" >> "$PROGRESS_FILE"
  fi
fi

# Track current branch
if [ -f "$PRD_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  if [ -n "$CURRENT_BRANCH" ]; then
    echo "$CURRENT_BRANCH" > "$LAST_BRANCH_FILE"
  fi
fi

# Initialize progress file if it doesn't exist
if [ ! -f "$PROGRESS_FILE" ]; then
  echo "# Ralph Progress Log" > "$PROGRESS_FILE"
  echo "Started: $(date)" >> "$PROGRESS_FILE"
  echo "" >> "$PROGRESS_FILE"
  echo "## Codebase Patterns" >> "$PROGRESS_FILE"
  echo "(Patterns will be added as they are discovered)" >> "$PROGRESS_FILE"
  echo "" >> "$PROGRESS_FILE"
  echo "---" >> "$PROGRESS_FILE"
fi

# Get project info
PROJECT_NAME=$(jq -r '.project // "Unknown"' "$PRD_FILE")
BRANCH_NAME=$(jq -r '.branchName // "main"' "$PRD_FILE")
TOTAL_STORIES=$(jq '.userStories | length' "$PRD_FILE")
COMPLETED_STORIES=$(jq '[.userStories[] | select(.passes == true)] | length' "$PRD_FILE")

log ""
log "Project: ${GREEN}$PROJECT_NAME${NC}"
log "Branch:  ${GREEN}$BRANCH_NAME${NC}"
log "Stories: ${GREEN}$COMPLETED_STORIES${NC} / ${TOTAL_STORIES} complete"
log "Max iterations: ${YELLOW}$MAX_ITERATIONS${NC}"
log ""

# Main loop
for i in $(seq 1 $MAX_ITERATIONS); do
  # Check remaining stories
  REMAINING=$(jq '[.userStories[] | select(.passes == false)] | length' "$PRD_FILE")

  if [ "$REMAINING" -eq 0 ]; then
    log ""
    log "${GREEN}═══════════════════════════════════════════════════════${NC}"
    log "${GREEN}  All stories complete!${NC}"
    log "${GREEN}═══════════════════════════════════════════════════════${NC}"
    log "Full transcript saved to: $LOG_FILE"
    exit 0
  fi

  # Get next story
  NEXT_STORY=$(jq -r '[.userStories[] | select(.passes == false)] | sort_by(.priority) | .[0] | "\(.id): \(.title)"' "$PRD_FILE")

  log ""
  log "${BLUE}═══════════════════════════════════════════════════════${NC}"
  log "${BLUE}  Iteration $i of $MAX_ITERATIONS${NC}"
  log "${BLUE}  Next: $NEXT_STORY${NC}"
  log "${BLUE}  Remaining: $REMAINING stories${NC}"
  log "${BLUE}═══════════════════════════════════════════════════════${NC}"
  log ""

  # Build the prompt for Claude
  CLAUDE_PROMPT="Read and execute the instructions in scripts/ralph/prompt.md

Key files:
- PRD: scripts/ralph/prd.json
- Progress: scripts/ralph/progress.txt

Work on the next incomplete story (passes: false) with highest priority.
After completing the story, update prd.json to set passes: true.

Current project directory: $PROJECT_DIR"

  # Run claude with the prompt
  # Using -p for print mode (non-interactive) and --dangerously-skip-permissions for autonomous operation
  cd "$PROJECT_DIR"

  # Create a temporary file for output capture
  OUTPUT_FILE=$(mktemp)

  # Run claude in print mode with permissions bypassed
  # Log iteration header to transcript
  echo "" >> "$LOG_FILE"
  echo "═══════════════════════════════════════════════════════" >> "$LOG_FILE"
  echo "  ITERATION $i - $(date)" >> "$LOG_FILE"
  echo "  Story: $NEXT_STORY" >> "$LOG_FILE"
  echo "═══════════════════════════════════════════════════════" >> "$LOG_FILE"
  echo "" >> "$LOG_FILE"

  # Run claude and capture full output to both screen and log file
  claude -p --dangerously-skip-permissions "$CLAUDE_PROMPT" 2>&1 | tee -a "$LOG_FILE" | tee "$OUTPUT_FILE" || true

  # Log iteration footer
  echo "" >> "$LOG_FILE"
  echo "--- End of Iteration $i ---" >> "$LOG_FILE"

  # Check for completion signal in output
  if grep -q "COMPLETE" "$OUTPUT_FILE" 2>/dev/null; then
    rm -f "$OUTPUT_FILE"
    log ""
    log "${GREEN}═══════════════════════════════════════════════════════${NC}"
    log "${GREEN}  Ralph completed all tasks!${NC}"
    log "${GREEN}  Finished at iteration $i of $MAX_ITERATIONS${NC}"
    log "${GREEN}═══════════════════════════════════════════════════════${NC}"
    log "Full transcript saved to: $LOG_FILE"
    exit 0
  fi

  rm -f "$OUTPUT_FILE"

  # Check if story was completed by reading prd.json
  NEW_COMPLETED=$(jq '[.userStories[] | select(.passes == true)] | length' "$PRD_FILE")

  if [ "$NEW_COMPLETED" -gt "$COMPLETED_STORIES" ]; then
    COMPLETED_STORIES=$NEW_COMPLETED
    log "${GREEN}Story completed! Progress: $COMPLETED_STORIES / $TOTAL_STORIES${NC}"
  else
    log "${YELLOW}Story may not have completed. Check progress.txt for details.${NC}"
  fi

  log ""
  log "Iteration $i complete. Continuing in 3 seconds..."
  sleep 3
done

log ""
log "${YELLOW}═══════════════════════════════════════════════════════${NC}"
log "${YELLOW}  Ralph reached max iterations ($MAX_ITERATIONS)${NC}"
log "${YELLOW}  Stories completed: $COMPLETED_STORIES / $TOTAL_STORIES${NC}"
log "${YELLOW}  Check scripts/ralph/progress.txt for status${NC}"
log "${YELLOW}═══════════════════════════════════════════════════════${NC}"
log "Full transcript saved to: $LOG_FILE"
exit 1
