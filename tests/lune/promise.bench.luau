--!nocheck

local loadPromise = require("./lib/loadPromise")
local process = require("@lune/process")
local native = process.env.PROMISE_BENCH_NATIVE == "1"
local Promise = loadPromise(native)

local ITERATIONS = 50000
local SAMPLES = 7
local sink = 0
local function emptyExecutor() end
local function resolveExecutor(resolve)
	resolve(1)
end
local function observe(value)
	sink += value
end
local function cancelled()
	sink += 1
end

local workloads = {
	{
		name = "new pending",
		run = function()
			sink += if Promise.new(emptyExecutor):isPending() then 1 else 0
		end,
	},
	{
		name = "new immediate resolution",
		run = function()
			sink += Promise.new(resolveExecutor):await()
		end,
	},
	{
		name = "resolve factory",
		run = function()
			sink += Promise.resolve(1):await()
		end,
	},
	{
		name = "reject factory",
		run = function()
			sink += if Promise.reject("failure"):isRejected() then 1 else 0
		end,
	},
	{
		name = "deferred resolution + observer",
		run = function()
			local finish
			local promise = Promise.new(function(resolve)
				finish = resolve
			end)
			promise:andThen(observe)
			finish(1)
		end,
	},
	{
		name = "deferred rejection + observer",
		run = function()
			local finish
			local promise = Promise.new(function(_, reject)
				finish = reject
			end)
			promise:catch(observe)
			finish(1)
		end,
	},
	{
		name = "cancel + handler",
		run = function()
			local promise = Promise.new(function(_, _, onCancel)
				onCancel(cancelled)
			end)
			promise:cancel()
		end,
	},
	{
		name = "deferred resolution + waiter",
		run = function()
			local finish
			local promise = Promise.new(function(resolve)
				finish = resolve
			end)
			local waiter = coroutine.create(function()
				sink += promise:await()
			end)
			assert(coroutine.resume(waiter))
			finish(1)
			assert(coroutine.status(waiter) == "dead")
		end,
	},
	{
		name = "all two resolved children",
		run = function()
			local values = Promise.all({ Promise.resolve(1), Promise.resolve(2) }):await()
			sink += values[1] + values[2]
		end,
	},
}

print(`Promise benchmark: native={native}; {ITERATIONS} operations/sample, {SAMPLES} samples; microseconds/operation`)
print("Source loading and warmup excluded; normal GC included; composite cases include all listed work.")
for _, workload in workloads do
	for _ = 1, 2000 do
		workload.run()
	end
end
local measurements = {}
for index in workloads do
	measurements[index] = {}
end
-- Rotate case order to reduce systematic warmup/GC ordering bias.
for sample = 1, SAMPLES do
	for offset = 0, #workloads - 1 do
		local index = (sample + offset - 1) % #workloads + 1
		local run = workloads[index].run
		local started = os.clock()
		for _ = 1, ITERATIONS do
			run()
		end
		measurements[index][sample] = (os.clock() - started) * 1e6 / ITERATIONS
	end
end
for index, workload in workloads do
	local samples = measurements[index]
	table.sort(samples)
	print(
		string.format("%s | median %.3f | min %.3f | max %.3f", workload.name, samples[4], samples[1], samples[SAMPLES])
	)
end
assert(sink > 0)
