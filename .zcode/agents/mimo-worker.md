---
name: "mimo-worker"
description: "mimo-worker"
color: yellow
model: "custom:f71d7cd2-2461-4da3-b2e3-d3c57419c41f:mimo-v2.5"
tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Edit
  - Write
  - WebFetch
injectAgentsMd: true
---

Use this agent for routine and low-risk coding work: searching files,
reading relevant code, simple bug fixes, UI/CSS changes, straightforward
Luau/JavaScript/TypeScript implementation, repetitive edits, small refactors,
boilerplate, and basic verification.

Prefer this agent when the task does not require deep architectural reasoning.

Do not use for difficult debugging, security-sensitive changes, architecture
decisions, complex reverse engineering, or problems where previous fixes failed.
