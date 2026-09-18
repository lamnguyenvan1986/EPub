# LibriAudio - Claude AI Configuration

## Overview

This folder contains configuration files for Claude AI to understand and work with the LibriAudio project.

## Files

| File | Purpose |
|------|---------|
| `settings.json` | Project settings for Claude Code |
| `README.md` | This file |

## settings.json

```json
{
  "projectName": "LibriAudio",
  "projectType": "flutter",
  "filePatterns": ["lib/**/*.dart"],
  "ignoredPatterns": ["build/**", ".dart_tool/**", "pubspec.lock"],
  "contextFiles": [
    "CLAUDE.md",
    "MEMORY.md",
    "FOLDER_TREE.txt",
    "INSTALL_RUN_GUIDE.md",
    "docs/PROJECT_SUMMARY.md",
    "docs/AI_CLAUDE_DOCUMENTATION.md",
    "docs/APP_FOLDER_STRUCTURE.md",
    "docs/ARCHITECTURE.md",
    "pubspec.yaml"
  ]
}
```

### Configuration Options

- **projectName**: Name of the project
- **projectType**: Type of project (`flutter`, `react`, `node`, etc.)
- **filePatterns**: Glob patterns for files to include in context
- **ignoredPatterns**: Glob patterns for files to exclude from context
- **contextFiles**: Files to always include in context

## Context Files - Mục đích từng file

| File | Mục đích | Dành cho |
|------|----------|----------|
| `CLAUDE.md` | Documentation tổng hợp cho Claude AI | AI, Developer |
| `MEMORY.md` | Facts ngắn gọn về project | AI, Developer |
| `FOLDER_TREE.txt` | Cây thư mục dạng text | Overview nhanh |
| `INSTALL_RUN_GUIDE.md` | Hướng dẫn cài đặt và chạy | Người mới |
| `docs/PROJECT_SUMMARY.md` | Tổng kết dự án | AI, Manager |
| `docs/AI_CLAUDE_DOCUMENTATION.md` | Tài liệu kỹ thuật cho AI | AI, Developer |
| `docs/APP_FOLDER_STRUCTURE.md` | Cấu trúc thư mục chi tiết | Developer |
| `docs/ARCHITECTURE.md` | Kiến trúc hệ thống | Developer, Architect |
| `pubspec.yaml` | Dependencies & config | Flutter |

## Usage

When Claude AI works with this project, it sẽ:

1. Use `CLAUDE.md` as the main documentation source
2. Reference `MEMORY.md` for quick facts
3. Use `FOLDER_TREE.txt` for folder structure overview
4. Use `INSTALL_RUN_GUIDE.md` for setup instructions
5. Use `docs/PROJECT_SUMMARY.md` for project summary
6. Reference technical docs for detailed information
7. Only include files matching `lib/**/*.dart` in context
8. Exclude files matching `build/**` and `.dart_tool/**`

---

**Last Updated**: 2026-09-18
