# API and behavior

## Constructors

| API | Result |
| --- | --- |
| `Promise.new(executor)` | Runs `executor(resolve, reject, onCancel)` immediately and returns a promise |
| `Promise.resolve(value)` | An already resolved promise |
| `Promise.reject(reason)` | An already rejected promise |
| `Promise.all(promises)` | Resolves to values in input order after all children resolve |

Public types are `Promise<T>`, `Executor<T>`, `Resolve<T>`, `Reject`, and `BindToCancel`.
The Pesde library entry is the implementation leaf itself; no root aggregate or init is needed.
All types come from the canonical type module. Private fields remain outside the exported Promise type.

## Observation and awaiting

`andThen(callback)` observes resolution. `catch(callback)` observes rejection. Both return the same
promise and invoke immediately if their corresponding outcome is already available. They do not
transform callback return values, flatten nested promises, or provide a chained-promise API.

`await()` returns the resolved value or raises the rejection/cancellation error. Pending awaits
suspend their coroutine. Resolution and rejection resume all queued waiters in the ordinary path.
`isPending`, `isResolved`, `isRejected`, and `isCancelled` report the terminal state.
The first settlement wins; later resolution, rejection, or cancellation has no effect.

Executors are protected: a failure before settlement rejects the promise. Resolution/rejection
observers run inline and must not throw or yield. Their exceptions are not isolated and can interrupt
remaining observer/waiter dispatch. This is retained behavior, not a new exception policy.

## Cancellation and ownership

The executor uses `onCancel(callback)` to release pending work. `cancel()` is idempotent, releases
registered cancellation handlers, clears observers, and resumes pending awaiters with cancellation.
Registering cleanup after cancellation invokes it immediately. Cancel-handler errors are isolated.
Cancellation of an already resolved/rejected promise has no effect.

Cancelling `Promise.all` cancels its children. A child rejection rejects the combined promise and
cancels remaining children. Cancelling a child independently does not itself settle the combined
promise. `all` retains the input list for cancellation: callers should not mutate that list afterward.

The package preserves the extracted behavior. It adds no retry, race, finally, deferred scheduler,
networking, or Minerva-specific ownership rules.
