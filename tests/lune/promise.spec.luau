--!strict
local LuneRequireTransform = require("./lib/luneRequireTransform")
local transformed = LuneRequireTransform.write({ packageRoot = "src", tempDir = ".promise-lune-runtime" })
local Promise = transformed.requireModule("components/promise/shared/promise.luau")
local cases = 0
local function test(name: string, callback: () -> ()): ()
	callback()
	cases += 1
	print("PASS " .. name)
end

test("executor runs immediately and resolved observers reuse the same promise", function()
	local executed = false
	local promise = Promise.new(function(resolve)
		executed = true
		resolve(12)
	end)
	assert(executed and promise:isResolved() and promise:await() == 12)
	local seen = 0
	assert(promise:andThen(function(value)
		seen = value
	end) == promise)
	assert(seen == 12)
end)

test("only the first resolution or rejection settles a promise", function()
	local resolve, reject
	local promise = Promise.new(function(r, j)
		resolve, reject = r, j
	end)
	local calls = 0
	promise:andThen(function()
		calls += 1
	end)
	resolve(4)
	reject("late")
	resolve(5)
	promise:cancel()
	assert(promise:await() == 4 and calls == 1 and not promise:isCancelled())
end)

test("deferred resolution resumes every waiter", function()
	local resolve
	local promise = Promise.new(function(r)
		resolve = r
	end)
	local values = {}
	for i = 1, 2 do
		local thread = coroutine.create(function()
			values[i] = promise:await()
		end)
		assert(coroutine.resume(thread))
	end
	assert(promise:isPending())
	resolve(17)
	assert(values[1] == 17 and values[2] == 17)
end)

test("rejection retains the error and resumes suspended waiters", function()
	local reject
	local promise = Promise.new(function(_, j)
		reject = j
	end)
	local observed
	assert(promise:catch(function(err)
		observed = err
	end) == promise)
	local waitedOk, waitedError
	local thread = coroutine.create(function()
		waitedOk, waitedError = pcall(function()
			return promise:await()
		end)
	end)
	assert(coroutine.resume(thread))
	local reason = { message = "failure" }
	reject(reason)
	assert(promise:isRejected() and observed == reason and waitedOk == false and waitedError == reason)
end)

test("executor failures become rejections", function()
	local promise = Promise.new(function()
		error("executor failed")
	end)
	assert(promise:isRejected())
	assert(not pcall(function()
		promise:await()
	end))
	assert(Promise.reject("failure"):isRejected())
end)

test("cancellation is idempotent and releases pending waiters", function()
	local bind, resolve
	local releases = 0
	local promise = Promise.new(function(r, _, b)
		resolve, bind = r, b
		b(function()
			releases += 1
		end)
	end)
	local resumed = false
	local thread = coroutine.create(function()
		resumed = not pcall(function()
			promise:await()
		end)
	end)
	assert(coroutine.resume(thread))
	promise:cancel()
	promise:cancel()
	resolve(9)
	bind(function()
		releases += 1
	end)
	assert(releases == 2 and resumed and promise:isCancelled() and not promise:isResolved())
end)

test("all handles an empty list and cancels remaining children on rejection", function()
	assert(#Promise.all({}):await() == 0)
	local reject
	local first = Promise.new(function(_, j)
		reject = j
	end)
	local second = Promise.new(function() end)
	local all = Promise.all({ first, second })
	reject("failed")
	assert(all:isRejected() and second:isCancelled())
end)

test("promise all retains ordered results and propagates cancellation", function()
	local resolve
	local pending = Promise.new(function(r)
		resolve = r
	end)
	local combined = Promise.all({ pending, Promise.resolve(20) })
	assert(combined:isPending())
	resolve(10)
	local values = combined:await()
	assert(values[1] == 10 and values[2] == 20)
	local child = Promise.new(function() end)
	local all = Promise.all({ child })
	all:cancel()
	assert(child:isCancelled())
end)

transformed.cleanup()
print(`Promise: {cases} cases passed`)
