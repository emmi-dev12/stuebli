# Prototype verification — 7 September 2026

Verified locally on an Apple Silicon Mac with Swift 6.4 Command Line Tools.

## Automated checks

`swift run stubli-checks` (or the release check executable) passes six groups:

- All 12 catalog records load; example scene validation and JSON round trip.
- Exact PAX dimensions and rejection of edits to locked catalog dimensions.
- Rotated footprint collisions, separated rotated rectangles and touching edges.
- Invalid room/object geometry, duplicate IDs and blocked-door warnings.
- Rejection of stale saves; invalid candidates cannot change the file or leave a lock.
- A reachable route and a route blocked by a room-spanning obstacle.

`scripts/check-cli.py` passes against the executable inside the installed app:

- Catalog search, sample creation and scene/object reads.
- Product dimension locks and whole-batch validation.
- Valid atomic patch, rejection/rollback of a patch containing a missing ID.
- Catalog addition, explicit custom conversion and resizing.
- Footprint warnings and route queries.

The bundled product JSON was compared byte-for-byte with the canonical catalog. The application bundle passed `codesign --verify --deep --strict`. Local ad-hoc signing is not notarization.

## Native UI checks

Observed the running app through its actual window:

- Floor plan, example dimensions, seven scene objects and catalog-backed inspector.
- Editing a desk's X coordinate and applying it; undo returns to its saved position.
- Verified product dimensions are disabled in the inspector.
- Both example people receive routes to the doorway.
- An external CLI patch changes the open room title and the GUI reports the reload; restored the example afterwards.
- 3D view, corrected lighting and eye-level view with ceiling.
- Walk mode receives keyboard focus; turning and forward movement visibly move the view.
- The final app launches from `/Applications/Stübli.app`.

The first render exposed a lighting defect with physically based materials; environment and fill lighting corrected it. Walk mode now receives focus directly and exposes an accessibility element.

## Size and limits

The local installed bundle uses approximately 1.7 MB on disk (including app, CLI, catalog and icon). Build caches are separate and can be removed after packaging. No peak-memory or frame-time benchmark is claimed.

This is a working first prototype, with approximate furniture meshes. Photorealistic quality, official 3D assets, dynamic furniture clearances, daily routines, arbitrary room shapes, older-macOS runtime testing and notarized public distribution remain unfinished.

## Hosted CI

The public GitHub connection does not have the `workflow` scope. The proposed Actions configuration is saved as `docs/ci-workflow.example.yml`; hosted CI is not enabled. All results above are local checks, not GitHub Actions results.
