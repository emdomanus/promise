# Promise

A small typed promise primitive extracted from Minerva. It supports resolution, rejection,
observation, awaiting, cancellation, and combining a list of promises.

`andThen` and `catch` return the same promise. They do not create a transformed chain.
Executors run immediately. This package adds no scheduler or Roblox service dependency.

## Package layout

- `src/components/promise/shared/promise.luau`: implementation and Pesde library entry.
- `src/types/components/promise/shared/promise.luau`: canonical public and private contracts.
- `tests/lune/`: actual implementation behavior checks.
- `tests/typechecks/`: accepted and rejected public type examples.
- `scripts/verify/`: Rokit-pinned Lune, Luau-LSP, Selene and StyLua checks.
- `docs/`: package-owned Markdown for this small primitive.

## Usage

```lua
local Promise = require(game.ReplicatedStorage.packages.promise)
local result: Promise.Promise<number> = Promise.new(function(resolve, _reject, onCancel)
    onCancel(function()
        -- release the producer's pending work
    end)
    resolve(42)
end)
local value = result:await()
```

The private package manifest assumes the Git repository `emdomanus/promise`. Git setup, commits,
publishing and Pesde installs are left to the repository owner. No install or generated lockfile
is supplied by this extraction.

See [API and behavior](docs/api.md) and [verification](docs/verification.md).
