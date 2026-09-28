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
.\scripts\verify\benchmark.ps1 -OutFile .verification/benchmark.txt
.\scripts\verify\benchmark.ps1 -Native -OutFile .verification/benchmark-native.txt
```

The default test command runs the eight original behavior cases and five allocation/lifecycle
cases in both interpreter and native modes (18 total executions). The latter check lazy subscription storage, release after settlement, nested observer
ordering, waiting coroutines, cancellation reentrancy, and direct settled factories. The new
suite and benchmark load original source in memory without generated runtime directories.

## Allocation benchmark - 2026-09-27

Measured in Lune 0.10.5 on the same Windows host, with identical benchmark code before and after.
Each workload runs 2,000 warmup operations and seven samples of 50,000 operations. Case order
rotates between samples. Values below are median microseconds per operation; ordinary garbage
collection is included and source loading is excluded. Composite workloads include all named
creation, subscription and settlement work. These are local measurements, not frame-time guarantees;
individual samples varied with GC and host scheduling. No native annotations were added.

| Workload | Before | After |
| --- | ---: | ---: |
| New pending | 1.460 | 0.826 |
| New with immediate resolution | 2.017 | 1.326 |
| Resolve factory | 1.874 | 0.232 |
| Reject factory | 2.257 | 0.227 |
| Deferred resolution and observer | 2.138 | 1.644 |
| Deferred rejection and observer | 2.454 | 1.594 |
| Cancellation and handler | 2.683 | 1.920 |
| Deferred resolution and waiter | 4.446 | 3.811 |
| All with two resolved children | 7.536 | 3.307 |

Construction now allocates one object table instead of the object plus four empty lists.
Each subscription list allocates only on first use; settlement releases its reference after
dispatch. Resolve/reject factories construct a settled object directly, avoiding executor
closures and protected executor invocation. Pending construction retains executor protection
and its per-instance resolver closures; cleanup is a shared helper. This table count describes
explicit package tables, not total VM memory allocation or caller-owned data.

The checkpoint passes all 13 behavioral cases, accepted public typing, all four negative type
cases, full source analysis, StyLua and Selene (zero errors, warnings or parse errors), using
Luau LSP 1.70.1 with the new solver. The benchmark's before version already included the public
read-only methods and intentionally erased `Promise.reject` success type.

## Native comparison - 2026-09-27

The implementation now starts with `--!native`; it has no function-level native attributes.
The in-memory loader was adjusted for this comparison: `script` and `require` are passed as
lexical chunk inputs, and `Luau.load` receives an explicit `codegenEnabled` flag. The previous
custom environment disabled codegen, so adding a directive alone would not have measured native
execution. See [Lune load options](https://lune-org.github.io/docs/api-reference/luau/#loadoptions).
Both sides of this comparison use the adjusted loader and optimization level 2. Do not attribute
differences from the earlier allocation benchmark solely to native compilation.

The benchmark workloads and sample counts are unchanged. Two serial off/on pairs improved every
workload. The repeat pair is reported below; the non-native control explicitly disables codegen
even with the directive present. These measurements exclude module loading/native compilation
cost and do not measure native-code memory or establish Roblox Studio/server performance.

| Workload | Codegen off (µs) | Codegen on (µs) | Time reduction |
| --- | ---: | ---: | ---: |
| New pending | 0.753 | 0.550 | 27% |
| New with immediate resolution | 1.309 | 1.100 | 16% |
| Resolve factory | 0.176 | 0.101 | 43% |
| Reject factory | 0.165 | 0.098 | 41% |
| Deferred resolution and observer | 1.622 | 1.348 | 17% |
| Deferred rejection and observer | 1.520 | 1.140 | 25% |
| Cancellation and handler | 1.779 | 1.292 | 27% |
| Deferred resolution and waiter | 3.597 | 2.974 | 17% |
| All with two resolved children | 2.770 | 2.118 | 24% |

All 18 behavioral executions, accepted typing, four rejected type cases, full source analysis,
StyLua and Selene pass after the native change. Full benchmark ranges remain in ignored local
files `.verification/native-before.txt`, `native-after.txt`, `native-control-repeat.txt`, and
`native-after-repeat.txt` under that directory.

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
