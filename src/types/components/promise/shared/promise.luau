--!strict

export type Resolve<T> = (value: T) -> ()
export type Reject = (err: unknown) -> ()
export type BindToCancel = (fn: () -> ()) -> ()

export type Promise<T> = {
	andThen: (self: Promise<T>, fn: (T) -> ()) -> Promise<T>,
	catch: (self: Promise<T>, fn: (unknown) -> ()) -> Promise<T>,

	await: (self: Promise<T>) -> T,

	cancel: (self: Promise<T>) -> (),
	isPending: (self: Promise<T>) -> boolean,
	isResolved: (self: Promise<T>) -> boolean,
	isRejected: (self: Promise<T>) -> boolean,
	isCancelled: (self: Promise<T>) -> boolean,
}

export type Executor<T> = (resolve: Resolve<T>, reject: Reject, bindToCancel: BindToCancel) -> ()

export type PromiseImpl<T> = Promise<T> & {
	_resolved: boolean,
	_rejected: boolean,
	_cancelled: boolean,

	_value: T?,
	_error: unknown?,

	_callbacks: { (T) -> () },
	_errbacks: { (unknown) -> () },
	_waiters: { thread },
	_cancelHandlers: { () -> () },
}

return {}
