# Gallery

Status: Superseded
Last updated: 2026-07-17

Superseded by [Photo Pedal Library](pedal-library.md), which is the only planned Gallery/Library feature spec for future visual Library behavior. This file is retained only as historical context and must not be used as implementation authority.

## Goal

Allow users to browse, replay, rename, delete, create, and select saved pedals.

## Current Context

Only the latest pedal is persisted. See [Data model](../../docs/DATA_MODEL.md).

## Functional Requirements

- Persist reusable pedals and processed covers.
- Browse, play, open, rename, delete, create, import, and select a pedal for a future board.

## Non-Goals

- Folders, tags, advanced search, cloud sync, social feeds, destructive image editing.

## Acceptance Criteria

- Pedals survive relaunch and preserve saved musical output.

## Open Questions

- Storage layout, migration from latest-pedal storage, and original-image retention.
