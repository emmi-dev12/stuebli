# Stübli

A lightweight, agent-native 3D workspace for designing rooms you can actually live in.

Stübli starts with rearranging an existing bedroom: recreate its measurements, furnish it with real products, compare layouts, and explore how people move through the space.

## Product direction

- Built for other people as well as its creator, initially targeting macOS.
- Precise measurements and a highly realistic visual target inspired by Unreal Engine visuals; rendering performance must be validated on the target Mac mini.
- Local modeling and rendering initially, with a small installation and controlled asset storage.
- External agents such as Codex and Claude inspect and edit the scene directly. No built-in chat assistant.
- Structured scene queries and small, targeted edits to reduce agent context and token costs.
- Users switch between a top-down floor plan, direct 3D manipulation, and exact numeric input.
- Agents ask project-specific questions, propose layouts, select or create objects, and place them. Users can rearrange the result.
- Input may combine measurements, sketches, and photos, depending on what the user has.
- Furniture matches existing possessions or products people can buy. Agents ask before suggesting custom-built pieces.
- IKEA is the intended starting product catalog. Full catalog coverage is a longer-term ambition; initial scope, sourcing, asset rights, and update strategy remain to be resolved.

## First end-to-end milestone

1. Reconstruct one existing bedroom with exact dimensions, doors, and windows.
2. Add owned furniture and a small verified set of IKEA products, identifying approximate visual models explicitly.
3. Allow an external agent to create and edit alternative layouts.
4. Support manual rearrangement, dimension editing, undo, and layout comparison.
5. Walk through the room and inspect door swings, drawer access, chair clearance, and access around beds.
6. Explore two-person sharing, waking up, and entering or leaving throughout the day using explicit routines and assumptions.

## Decisions still to make

- Target hardware, memory, storage, and performance budgets.
- Rendering and geometry technology, validated through a small prototype.
- Agent integration protocol, scene representation, and edit validation.
- How incomplete or conflicting room measurements are handled.
- Product-data and 3D-asset sources and licensing.
- Scope of routine testing versus later simulation.
- Distribution, business model, and Git hosting.

Future expansion may include printable gadgets, custom objects, and broader home modeling. No application code or technology stack has been selected yet.
