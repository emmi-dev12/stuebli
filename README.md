# Stübli

A small 3D workshop for figuring out how your room should work.

Stübli began with a bedroom: exact measurements, two people sharing the space, and an AI agent helping rearrange furniture. You should be able to ask Codex or Claude for a layout, move things yourself, and walk into the result.

**We're building in public. This is an early native macOS prototype.** It has a working floor-plan editor, locally rendered 3D view, walkthrough, and agent CLI. The new material and furniture pass makes the room much more recognizable; photorealism and convincing day simulation remain goals.

## What works today

- Edit a rectangular room, its south doorway, and north window in metres.
- Browse 12 specific IKEA Switzerland variants, with official source links and verified assembled dimensions.
- Place and drag furniture in the floor plan or directly in 3D; use the inspector for exact positions.
- Orbit the room, or explore at eye level with collision-aware movement.
- Open supported drawers and wardrobe doors, see their operating clearance, and include that clearance in route checks.
- Switch between a neutral daylight preview and a warm evening preview.
- Add adjustable person envelopes and check routes to the open doorway.
- Undo and redo scene edits, capture a comparison layout, and save permanent alternatives as separate files.
- Give an external agent a JSON file and a small CLI. No built-in chat, account, cloud renderer, or telemetry.
- Reload valid external edits automatically when the editor has no unsaved changes. Stale app/CLI saves are rejected.

The first room is an **example**, not a reconstruction of your actual bedroom. Enter your measurements before using it for planning.

## Get running

Requires macOS 14 or newer and Swift 6 to build. Apple Silicon is the currently tested architecture. A full Xcode installation is not required on the development machine; the checks also run with Command Line Tools.

```sh
git clone https://github.com/emmi-dev12/stuebli.git
cd stuebli
swift run stubli-checks
./scripts/package.sh
open dist/Stübli.app
```

To install, drag `dist/Stübli.app` into Applications. Builds are locally ad-hoc signed; this is not yet a notarized public distribution. The script builds against your installed SDK. Older supported macOS versions have not yet been runtime-tested.

The app uses SwiftUI, AppKit, and SceneKit supplied by macOS. SceneKit is the current prototype renderer; achieving our realism target may require a different rendering backend. The scene format and agent interface are deliberately independent of it.

## Use it with an agent

Click **Agent file path** in the editor, save your changes, and give that path to your agent. The bundled CLI is at `/Applications/Stübli.app/Contents/MacOS/stubli` after installation.

```sh
swift run stubli catalog MALM
swift run stubli sample /tmp/bedroom.stubli.json
swift run stubli inspect /tmp/bedroom.stubli.json
swift run stubli check /tmp/bedroom.stubli.json
```

An agent can request one object, update one field, or apply a batch rather than reading screenshots and clicking menus. See [the agent interface](docs/agent-interface.md) for the full workflow and examples.

## Measurements and realism

“160×200” on a bed can describe its mattress, not its footprint. The catalog stores assembled measurements separately from marketing labels. IKEA product dimensions are locked. **Make custom to resize** explicitly detaches the catalog identity.

The 3D furniture is generated locally from detailed procedural geometry. Its outer dimensions follow the catalog, but its interior structure, joinery, upholstery and finishes are approximate. There are no official IKEA meshes or photographs in the bundle. [Catalog sources and limitations](catalog/ikea-ch/README.md).

The bundled oak, fabric-normal and studio-lighting maps are CC0 assets from [Poly Haven](https://polyhaven.com), stored locally so the app never needs the network to render. Exact URLs, hashes and license records live in `Sources/Stubli/Resources/Materials/provenance.json`.

Route checks use a 10 cm grid and a conservative body envelope, with the other person stationary and the doorway open. Open drawers and wardrobe doors become route obstacles. This is a way to find obvious friction, not a claim to simulate human behaviour. Simultaneous movement, dressing and waking-up routines are not automated yet.

## Local files

The first saved example lives in `~/Library/Application Support/Stuebli/Bedroom.stubli.json`. You can save projects anywhere you choose. Room files are not uploaded. The Git repository excludes personal `*.stubli.json` files by default, except explicitly included public examples.

## The road ahead

- Editable irregular room shapes, more doors/windows, and physically based lighting beyond the two preview moods.
- Agent-proposed alternatives through a more capable transactional scene API.
- More product-specific door/drawer articulation, activity clearances, and two-person routines.
- Photos and sketches as measured reconstruction inputs.
- A larger verified product catalog, efficient asset caching, and eventually custom printable objects.

Follow [the development journal](docs/journey.md), [product direction](PRODUCT.md), and GitHub issues. The source is public; an open-source license and contribution policy have not yet been chosen. Stübli is independent of IKEA.
