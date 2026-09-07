# Working with Stübli as an external agent

Use the bundled `stubli` executable, or `swift run stubli` from the source repository. Run `stubli --help` for commands. All processing is local. Prefer structured reads and small batch edits; no screenshot is needed to move an object or check its size.

## Coordinate contract

- Metres; object positions are footprint centres.
- Origin: southwest corner of the room. X points east, Z points north, Y points up.
- All current objects stand on the floor. Width is local X; depth is local Z.
- Rotation in degrees follows the right-hand rule around +Y. At zero rotation the product front faces south. Positive 90 degrees turns its front west.
- Room doorway is on the south wall; window is on the north wall.
- Product IDs are distinct from scene instance IDs. Multiple instances may share one catalog ID.

## Workflow

1. Ask the user about the current project: measurements, existing furniture, preferred activities, people, and what may change.
2. Ask them to save local changes; obtain the file path from the editor's **Agent file path** button.
3. Inspect the scene. Keep a backup before a substantial rearrangement.
4. Query the catalog only for relevant products; inspect individual object IDs as needed.
5. Apply a small edit or one atomic batch. Check the result and explain assumptions.
6. The clean GUI reloads external edits automatically. If local edits exist, it offers reload or save-a-copy recovery instead of discarding them.

```sh
stubli catalog MICKE
stubli inspect "$SCENE" "$OBJECT_ID"
stubli set "$SCENE" "$OBJECT_ID" rotation 90
stubli add "$SCENE" ikea-ch-80213074
stubli check "$SCENE"
stubli routes "$SCENE"
```

## Batch patch

Write a JSON patch file, then run `stubli patch "$SCENE" changes.json`:

```json
{
  "name": "Layout B",
  "room": {"width": 4.8, "depth": 4.2},
  "updates": [
    {"id": "COPY_A_REAL_INSTANCE_ID", "x": 2.1, "z": 3.0, "rotation": 0}
  ]
}
```

The whole candidate scene is validated before an atomic write. Unknown fields, missing IDs, invalid dimensions and resized catalog items are rejected. App and CLI saves cooperate on a temporary `.lock` directory and compare the previously read file bytes. A stale snapshot cannot overwrite another app/CLI save. Direct manual editors must avoid concurrent writes. A crashed writer can leave a lock directory; inspect running writers before removing that lock manually.

## Product truth

Catalog dimensions cannot be edited while an object retains its catalog ID. Only use `stubli custom "$SCENE" "$OBJECT_ID"` after the user accepts a custom/modified object. The user specifically wants purchasable products and must be asked before custom-building proposals.

The catalog identifies official source pages and the research date, not stock or validated mesh accuracy. Drawer travel is known for only the MALM three-drawer chest in the initial set. Missing measurements are unknown. Do not invent hinge clearances from a nominal width or treat drawer interior depth as travel.

## Checks and limits

Footprint warnings use oriented rectangles for furniture intersections, and conservative axis-aligned checks near room walls/door approaches. Route checks use a circular body envelope on a 10 cm grid, four-neighbour search, stationary other objects and an assumed-open door. Results can be conservative in tight passages. They target the door approach, not a complete exit beyond the room. Route checks support rooms up to 15 m and 100 objects. General scenes support 500 objects; very large scenes are not performance-tested.

The in-app walkthrough uses a 40 cm square viewer footprint and an eye height up to 1.65 m; this differs from adjustable person-envelope route checks. Neither is an accessibility or building-code certification.

The app does not spawn agents or embed chat. Existing Codex/Claude tools invoke the CLI. Small queries and patches are intended to reduce context use; token savings have not been benchmarked.
