--!strict
local Promise = require(game.ReplicatedStorage.packages.promise.components.promise.shared.promise)
local numberPromise: Promise.Promise<number> = Promise.new(
	function(resolve: Promise.Resolve<number>, _reject: Promise.Reject, onCancel: Promise.BindToCancel): ()
		onCancel(function() end)
		resolve(12)
	end
)
local observed: number = 0
numberPromise:andThen(function(value: number): ()
	observed = value
end)
local value: number = numberPromise:await()
local values: { number } = Promise.all({ numberPromise, Promise.resolve(4) }):await()
local rejected: Promise.Promise<number> = Promise.reject("failure")
rejected:catch(function(failure: unknown): ()
	print(failure)
end)
return { value = value, values = values, observed = observed }
