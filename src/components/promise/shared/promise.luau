--!strict
--!optimize 2

local PromiseTypes = require(script.Parent.Parent.Parent.Parent.types.components.promise.shared.promise)
export type Resolve<T> = PromiseTypes.Resolve<T>
export type Reject = PromiseTypes.Reject
export type BindToCancel = PromiseTypes.BindToCancel
export type Promise<T> = PromiseTypes.Promise<T>
type PromiseImpl<T> = PromiseTypes.PromiseImpl<T>
export type Executor<T> = PromiseTypes.Executor<T>
type PromiseModule = {
	new: <T>(executor: Executor<T>) -> Promise<T>,
	resolve: <T>(value: T) -> Promise<T>,
	reject: <T>(err: unknown) -> Promise<T>,
	all: <T>(promises: { Promise<T> }) -> Promise<{ T }>,
}

local Promise = {}
Promise.__index = Promise

local function safeCall(tag: string, fn: () -> ())
	local ok, err = pcall(function(): unknown
		fn()
		return nil
	end)
	if not ok then
		warn(tag .. ": " .. tostring(err))
	end
end

function Promise.new<T>(executor: Executor<T>): Promise<T>
	local self: PromiseImpl<T> = (setmetatable({}, Promise) :: unknown) :: PromiseImpl<T>

	self._resolved = false
	self._rejected = false
	self._cancelled = false

	self._value = nil
	self._error = nil

	self._callbacks = {} :: { (T) -> () }
	self._errbacks = {} :: { (unknown) -> () }
	self._waiters = {} :: { thread }
	self._cancelHandlers = {} :: { () -> () }

	local function settleClear()
		table.clear(self._callbacks)
		table.clear(self._errbacks)
		table.clear(self._cancelHandlers)
	end

	local function resolve(value: T)
		if self._resolved or self._rejected or self._cancelled then
			return
		end

		self._resolved = true
		self._value = value

		for _, fn in self._callbacks do
			fn(value)
		end

		for _, th in self._waiters do
			coroutine.resume(th, true, value)
		end

		table.clear(self._waiters)
		settleClear()
	end

	local function reject(err: unknown)
		if self._resolved or self._rejected or self._cancelled then
			return
		end

		self._rejected = true
		self._error = err

		for _, fn in self._errbacks do
			fn(err)
		end

		for _, th in self._waiters do
			coroutine.resume(th, false, err)
		end

		table.clear(self._waiters)
		settleClear()
	end

	local function bindToCancelImpl(fn: () -> ())
		if self._cancelled then
			-- already cancelled: run immediately so caller can clean up
			safeCall("Error in Promise cancel handler", fn)
			return
		end
		if self._resolved or self._rejected then
			-- already settled: don't track cancel
			return
		end
		table.insert(self._cancelHandlers, fn)
	end

	-- All executor callbacks are supplied; an executor may ignore unused arguments.
	local ok, err = pcall(function(): unknown
		executor(resolve, reject, bindToCancelImpl)
		return nil
	end)
	if not ok then
		reject(err)
	end

	return self
end

function Promise.resolve<T>(value: T): Promise<T>
	return Promise.new(function(resolve)
		resolve(value)
	end)
end

function Promise.reject<T>(err: unknown): Promise<T>
	return Promise.new(function(_resolve, reject)
		(reject :: Reject)(err)
	end)
end

-- Cancelling the "all" promise cancels all children.
-- Reject fast on first rejection and cancel the rest.
function Promise.all<T>(promises: { Promise<T> }): Promise<{ T }>
	return Promise.new(function(resolve, reject, bindToCancel)
		local count = #promises
		local results: { T } = table.create(count)
		local settled = false

		if count == 0 then
			resolve(results)
			return
		end

		(bindToCancel :: BindToCancel)(function()
			for _, p in ipairs(promises) do
				p:cancel()
			end
		end)

		local function onReject(err: unknown)
			if settled then
				return
			end
			settled = true

			for _, p in ipairs(promises) do
				p:cancel()
			end

			(reject :: Reject)(err)
		end

		for i, p in ipairs(promises) do
			p:andThen(function(value: T)
				if settled then
					return
				end

				results[i] = value
				count -= 1

				if count == 0 then
					settled = true
					resolve(results)
				end
			end):catch(onReject)
		end
	end)
end

function Promise.andThen<T>(self: PromiseImpl<T>, fn: (T) -> ()): Promise<T>
	if self._resolved then
		fn(self._value :: T)
	elseif not self._rejected and not self._cancelled then
		table.insert(self._callbacks, fn)
	end
	return self
end

function Promise.catch<T>(self: PromiseImpl<T>, fn: (unknown) -> ()): Promise<T>
	if self._rejected then
		fn(self._error)
	elseif not self._resolved and not self._cancelled then
		table.insert(self._errbacks, fn)
	end
	return self
end

function Promise.await<T>(self: PromiseImpl<T>): T
	if self._resolved then
		return self._value :: T
	end
	if self._rejected then
		error(self._error, 2)
	end
	if self._cancelled then
		error("Promise.await() called on a cancelled promise", 2)
	end

	local th = coroutine.running()
	if not th then
		error("Promise.await() must be called from a yielding thread", 2)
	end

	table.insert(self._waiters, th)

	local ok, payload = coroutine.yield()
	if not ok then
		-- payload is either rejection error or nil (cancel)
		if payload ~= nil then
			error(payload, 2)
		end
		error("Promise was cancelled", 2)
	end

	return payload :: T
end

function Promise.cancel<T>(self: PromiseImpl<T>): ()
	if self._resolved or self._rejected or self._cancelled then
		return
	end

	self._cancelled = true

	for _, fn in self._cancelHandlers do
		safeCall("Error in Promise cancel handler", fn)
	end
	table.clear(self._cancelHandlers)

	table.clear(self._callbacks)
	table.clear(self._errbacks)

	for _, th in self._waiters do
		coroutine.resume(th, false, nil)
	end
	table.clear(self._waiters)
end

function Promise.isPending<T>(self: PromiseImpl<T>): boolean
	return not (self._resolved or self._cancelled or self._rejected)
end

function Promise.isResolved<T>(self: PromiseImpl<T>): boolean
	return self._resolved
end

function Promise.isRejected<T>(self: PromiseImpl<T>): boolean
	return self._rejected
end

function Promise.isCancelled<T>(self: PromiseImpl<T>): boolean
	return self._cancelled
end

return Promise :: PromiseModule
