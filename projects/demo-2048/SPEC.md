# Spec

## Goal
Deliver a single-file HTML 2048 game demo that runs locally without any build tools.

## Non-goals
- Server-side logic or persistence beyond localStorage.
- Multi-page routing or frameworks.

## Requirements
- R1: Provide a playable 4x4 2048 game in one HTML file.
- R2: Support keyboard input (arrow keys) and touch swipe on mobile.
- R3: Include score and best score (localStorage).
- R4: Provide a "New Game" restart flow.
- R5: Keep all assets inline (no external dependencies).

## Acceptance Criteria
- AC1: Opening `projects/demo-2048/demo-2048.html` in a browser starts the game.
- AC2: Arrow keys and swipe moves tiles.
- AC3: Score updates on merges and best score persists between reloads.
- AC4: Game over and win overlays appear appropriately.

## Notes
- This project is a demo to validate the refactored framework flow.
