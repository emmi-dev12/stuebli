# Building Stübli in public

## 2026-09-07 — A bedroom first

We started by wanting a smaller, easier 3D tool: something an external AI agent can operate directly, without a big installation or built-in chat interface.

The first useful project is rearranging an existing bedroom shared by two people. The workflow mixes exact measurements with realistic exploration. The agent asks questions for each project, proposes alternatives, and leaves the user free to rearrange the result.

The name became **Stübli**, with a Bernese character. The first catalog is IKEA Switzerland.

### Product research

We checked 12 exact variants against official product pages. The biggest lesson was to separate product titles from assembled dimensions: MALM mattress sizes, PAX nominal frame sizes, and KALLAX rounded labels all differ from the dimensions needed for placement.

Product facts and visual models have separate confidence. We have sourced dimensions; our procedural meshes remain approximate. Missing movement measurements stay unknown.

### First implementation

The initial app uses SwiftUI/AppKit and a SceneKit viewport, with no external runtime dependencies. An independent scene module backs the app and CLI. It includes measured placement, catalog identity, undo/redo, JSON persistence, external reloads, and cooperative locking with stale-write checks.

Two-person route tests start with conservative geometry rather than an invented behavioural simulation. The room shows a result and its assumptions.

The local Command Line Tools SDK exposed a SwiftUI macro without its plugin and did not contain XCTest. The app explicitly selects SwiftUI's existing State property wrapper, and its dependency-free core checks run as a small executable.

### What remains uncertain

Photorealistic rendering, asset licensing, more detailed models, articulated furniture, complete daily routines, and public distribution all need further work. This first prototype is a foundation to use and evaluate, not a claim to have replaced Blender or matched Unreal Engine.
