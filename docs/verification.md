# Verification

## Commands

All tool binaries resolve through `~/.rokit/bin` using `rokit.toml` pins.
Roblox definitions used by the analyzer are generated local state; fetch them with
`scripts/luau-lsp/fetch-roblox-types.ps1` when needed.

```powershell
.\scripts\verify\tests.ps1
.\scripts\verify\types.ps1
.\scripts\verify\analyze.ps1
.\scripts\verify\selene.ps1
.\scripts\verify\stylua.ps1
```

Tests load a rewritten test copy of the actual Pesde entry implementation and its canonical type
module. No runtime implementation is mocked. The test copy stays inside the Promise workspace.
The original Minerva `Promise.all` contract case is preserved in this package.

## Extraction receipt - 2026-09-15

- Eight behavioral cases cover synchronous/deferred resolution, observation, first settlement,
  rejection, executor failure, multiple awaiters, cancellation, ordered `all` results and rejection cleanup.
- The accepted type example checks typed constructors, observers, awaits and combining promises.
- Four negative cases reject wrong resolution values, wrong await types, wrong observer types and private fields.
- The Promise algorithm is unchanged by extraction; only import ownership, public type exports and an outdated comment changed.
- Minerva's 30 integration cases pass with the extracted package through a test-only dependency mapping.
- Structural audit: two runtime modules, one internal require, 13 development-place nodes,
  no duplicate module/sibling paths, empty source directories, or authored `any`.
- Git setup, commits, publishing and Pesde installs have not been performed. No lockfile is hand-authored.

Final static/style results: zero analyzer diagnostics, zero Selene errors/warnings/parse errors,
and StyLua passes. `luauExtras.yml` supplies Luau's optional assert-message signature to the pinned
Selene standard library, matching Minerva's tooling setup without disabling a lint category. This package uses only
Luau table/coroutine behavior and adds no Roblox service lifecycle or networking to verify in Studio.
Minerva's RemoteEvent integration still needs its separate Studio gate before game adoption.
