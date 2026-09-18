# LibriAudio - Claude AI Configuration

## Overview

This folder contains configuration files for Claude AI to understand and work with the LibriAudio project.

## Files

| File | Purpose |
|------|---------|
| `settings.json` | Project settings for Claude Code |

## settings.json

```json
{
  "projectName": "LibriAudio",
  "projectType": "flutter",
  "filePatterns": ["lib/**/*.dart"],
  "ignoredPatterns": ["build/**", ".dart_tool/**", "pubspec.lock"],
  "contextFiles": ["CLAUDE.md", "docs/AI_CLAUDE_DOCUMENTATION.md", "docs/APP_FOLDER_STRUCTURE.md"]
}
```

### Configuration Options

- **projectName**: Name of the project
- **projectType**: Type of project (`flutter`, `react`, `node`, etc.)
- **filePatterns**: Glob patterns for files to include in context
- **ignoredPatterns**: Glob patterns for files to exclude from context
- **contextFiles**: Files to always include in context

## Usage

When Claude AI works with this project, it will:

1. Use `CLAUDE.md` as the main documentation source
2. Reference `docs/AI_CLAUDE_DOCUMENTATION.md` for technical details
3. Use `docs/APP_FOLDER_STRUCTURE.md` for folder structure understanding
4. Only include files matching `lib/**/*.dart` in context
5. Exclude files matching `build/**` and `.dart_tool/**`

---

**Last Updated**: 2026-09-18