# Promise package guide

Use VoxelMMO's `voxel-mmo-conventions` skill first and `vmmo-roblox` for compatible lifecycle and
verification rules. Their source is in the sibling VoxelMMO/ServiceDev/.agents/skills directory.

- Promise is a small shared primitive. Its actual implementation is the Pesde library entry.
- Runtime lives in `src/components/promise/shared/`; canonical types mirror it under `src/types/`.
- Export public types from their canonical owner. Do not export PromiseImpl or allocate type-view wrappers.
- `utils` is a category, never a child category such as `components/utils`. Shared helper functions
  that belong inside this single implementation can remain local functions.
- Preserve current settlement, observer, awaiting and cancellation semantics; extraction is not a
  redesign of Promise behavior. `andThen` and `catch` observe and return the same promise.
- No Roblox services, automatic scheduler, networking, or Minerva dependency belongs here.
- Use the Rokit-pinned guarded scripts in `scripts/verify/`; format only an explicit task-owned file list.
- Keep tests and test copies outside `src/`. Use the actual public entry for behavioral and type tests.
- Update package-owned Markdown when public behavior, imports or ownership changes.
- If a verification gate produces no usable answer after three attempts, stop and report.
- The user owns Git setup, commits, publishing, and Pesde installation for this extraction.
