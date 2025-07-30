# Claude Loop Project

A Docker-based automated task execution system using Claude AI to process and complete tasks defined in `.claude/plan.md`.

## Demo

![Demo](./demo.gif)

## Overview

This project provides two main scripts for interacting with Claude AI in a sandboxed Docker environment:

- **`ccl`** (Claude Code Loop) - Runs an automated loop that processes tasks from `.claude/plan.md`
- **`ccsb`** (Claude Code Sandbox) - Executes single Claude commands with full tool access

## Prerequisites

1. **Docker**
2. **Claude CLI**
3. **Gemini CLI** (optional) - For documentation queries / gemini-cli mcp (https://github.com/jamubc/gemini-mcp-tool)
4. **User Home Directory** - Scripts must be run from within your home directory for security
5. **Linux** (or WSL) - with user 1000:1000

## Security Warning

- While rootless docker is very safe, it still has access to the internet and you local network and can possibly cause (limited) havoc.

## Setup

### 1. Build the Docker Image

```bash
docker compose build
```

### 2. Configure Claude CLI

Ensure you have:
- `~/.claude.json` - Claude CLI configuration
- `~/.claude/` - Claude settings directory

### 3. Configure Gemini CLI (Optional)

If using gemini-cli for documentation queries:
- `~/.gemini/` - Gemini settings
- `GEMINI_API_KEY` environment variable

### 4. symlink (or move) to /bin
```bash
ln -s ccl /bin/ccl
ln -s ccsb /bin/ccsb
```

## Usage

### CCL (Claude Code Loop)

Automatically processes tasks defined in `.claude/plan.md`:

```bash
ccl
```

**Features:**
- Reads tasks from `.claude/plan.md`
- Updates task statuses: `(Not Started)` → `(In Progress)` → `(Completed)/(Aborted)`
- Continues until all tasks show `(Completed)`
- Creates `/tmp/plan_complete` when finished
- Pretty formatted output with progress tracking

**Task Status Format:**
```markdown
- (Status) Task description
```

Status options: `Not Started | In Progress | Aborted | Completed`

### CCSB (Claude Code Sandbox)

Execute claude in a sandbox with all permissions.

```bash
ccsb
```

## Plan File Structure

The `.claude/plan.md` file defines tasks to be executed:

```markdown
# Project Name

## IMPORTANT (instructions for Claude when in ccl mode, does not apply to ccsb)
- Project-specific guidelines
- Tool preferences
- Constraints

## PLAN

### Section 1
- Task 1 description
- Task 2 description

### Section 2  
- Task 3 description

## POST TASK TASKS
- Cleanup tasks
- Final commits
- Documentation updates
```

## Tips

- You can ask ccsb to run claude-loop
- You can ask claude to keep a work-log such as:
```markdown
- Append work to .claude/work-log.md, never read entire file into context with format $(date): <task>\n\n
- tail work-log.md before starting
- Focus on words with !! for accuracy
- Look for (Changes Needed) and view all the changes requested below
```
- Changes Needed example
```markdown
### Some Tasks Topic
- (Completed) Task1
- (Changes Needed) Original task to build a snowman
  - You built a snowman without a head, add a head
```

## Security Features

- **Home Directory Restriction**: Scripts only run from within user home directory
- **Docker Isolation**: All Claude operations run in isolated container
- **Non-root Execution**: Container runs as user `1000:1000`
- **Limited File Access**: Only mounted directories are accessible

## Troubleshooting

### Common Issues

1. **"Must be run from within user home directory"**
   - Ensure you're running the script from a subdirectory of `$HOME`

2. **Docker permission errors**
   - Check Docker is running and user has permissions
   - Verify volume mounts point to existing directories

3. **Claude CLI not configured**
   - Run `claude` to set up claude
   - Ensure `~/.claude.json` exists

## License

MIT
