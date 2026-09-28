--!nocheck

-- Load the original modules in memory; benchmark setup creates no runtime copies.
local fs = require("@lune/fs")
local Luau = require("@lune/luau")

local function loadPromise(codegenEnabled)
	local byPath = {}
	local function scan(path, parent)
		local node = { Parent = parent }
		for _, entry in fs.readDir(path) do
			local childPath = path .. "/" .. entry
			if fs.isDir(childPath) then
				node[entry] = scan(childPath, node)
			elseif entry:sub(-5) == ".luau" then
				local child = { Parent = node, path = childPath }
				node[entry:sub(1, -6)] = child
				byPath[childPath] = child
			end
		end
		return node
	end
	scan("src", nil)
	local cache = {}
	local function load(node)
		assert(type(node) == "table" and node.path, "Unresolved script require")
		if cache[node] == nil then
			local source = fs.readFile(node.path)
			local directives = ""
			while source:sub(1, 3) == "--!" do
				local newline = assert(source:find("\n", 1, true))
				directives ..= source:sub(1, newline)
				source = source:sub(newline + 1)
			end
			-- Lexical module inputs keep the global environment safe for native compilation.
			-- A custom Luau.load environment would forcibly disable codegen.
			local bytecode = Luau.compile(directives .. "local script, require = ...\n" .. source, {
				optimizationLevel = 2,
			})
			cache[node] = Luau.load(bytecode, {
				debugName = node.path,
				codegenEnabled = codegenEnabled == true,
			})(node, load)
		end
		return cache[node]
	end
	return load(byPath["src/components/promise/shared/promise.luau"])
end

return loadPromise
