--!strict

local requireAny = require :: any
local fs = requireAny("@lune/fs")
local process = requireAny("@lune/process")

export type TransformOptions = {
	packageRoot: string,
	tempDir: string,
	replicatedStorageStubSource: string?,
	externalOverrides: { [string]: string }?,
	packageOverrides: { [string]: string }?,
	moduleOverrides: { [string]: string }?,
	rewriteTaskGlobal: boolean?,
	sourceTransform: ((source: string, relativePath: string) -> string)?,
}

export type TransformHandle = {
	root: string,
	requireModule: (relativePath: string) -> any,
	cleanup: () -> (),
}

local LuneRequireTransform = {}

local function normalizePath(path: string): string
	return (path:gsub("\\", "/"))
end

local function joinPath(left: string, right: string): string
	if left:sub(-1) == "/" or left:sub(-1) == "\\" then
		return left .. right
	end

	return left .. "/" .. right
end

local function resolveFromCwd(path: string): string
	local normalized = normalizePath(path)
	if normalized:match("^%a:/") or normalized:sub(1, 1) == "/" then
		return normalized
	end

	return joinPath(process.cwd, normalized)
end

local function dirname(path: string): string
	return normalizePath(path):match("^(.*)/[^/]+$") or ""
end

local function pathSegments(path: string): { string }
	local segments: { string } = {}
	for segment in normalizePath(path):gmatch("[^/]+") do
		segments[#segments + 1] = segment
	end
	return segments
end

local function relativeRequirePath(sourcePath: string, targetPath: string): string
	local moduleSourcePath = if normalizePath(sourcePath):match("/init%.luau$") then dirname(sourcePath) else sourcePath
	local sourceSegments = pathSegments(dirname(moduleSourcePath))
	local targetSegments = pathSegments(targetPath)
	local common = 0
	local commonLimit = math.min(#sourceSegments, #targetSegments)
	while common < commonLimit and sourceSegments[common + 1]:lower() == targetSegments[common + 1]:lower() do
		common += 1
	end

	local relativeSegments: { string } = {}
	for _ = common + 1, #sourceSegments do
		relativeSegments[#relativeSegments + 1] = ".."
	end
	for index = common + 1, #targetSegments do
		relativeSegments[#relativeSegments + 1] = targetSegments[index]
	end

	local relativePath = table.concat(relativeSegments, "/"):gsub("/init%.luau$", ""):gsub("%.luau$", "")
	if relativePath:sub(1, 3) ~= "../" then
		relativePath = "./" .. relativePath
	end
	return relativePath
end

local function discoverPackageFiles(packageRoot: string): { string }
	local discovered: { string } = {}

	local function visit(directoryPath: string, directoryRel: string): ()
		for _, entry in fs.readDir(directoryPath) do
			local entryPath = joinPath(directoryPath, entry)
			local entryRel = if directoryRel == "" then entry else directoryRel .. "/" .. entry
			if fs.isDir(entryPath) then
				if entry ~= "tests" then
					visit(entryPath, entryRel)
				end
			elseif fs.isFile(entryPath) and entry:sub(-5) == ".luau" then
				table.insert(discovered, entryRel)
			end
		end
	end

	visit(packageRoot, "")
	table.sort(discovered)
	return discovered
end

local function moduleSegments(sourceRel: string): { string }
	local withoutExtension = normalizePath(sourceRel):gsub("%.luau$", "")
	local segments: { string } = {}
	for part in withoutExtension:gmatch("[^/]+") do
		table.insert(segments, part)
	end
	if segments[#segments] == "init" then
		table.remove(segments)
	end
	return segments
end

local function relFromSegments(segments: { string }, sourceFileSet: { [string]: true }): string
	local base = table.concat(segments, "/")
	local initRel = if base == "" then "init.luau" else base .. "/init.luau"
	if sourceFileSet[initRel] then
		return initRel
	end
	return base .. ".luau"
end

local function resolveScriptRequire(
	sourceRel: string,
	expression: string,
	tempRoot: string,
	sourceFileSet: { [string]: true }
): string
	local segments = moduleSegments(sourceRel)
	local isFirst = true
	for token in expression:gmatch("[A-Za-z_][A-Za-z0-9_]*") do
		if isFirst then
			isFirst = false
		elseif token == "Parent" then
			table.remove(segments)
		else
			table.insert(segments, token)
		end
	end
	return relativeRequirePath(
		joinPath(tempRoot, sourceRel),
		joinPath(tempRoot, relFromSegments(segments, sourceFileSet))
	)
end

function LuneRequireTransform.write(options: TransformOptions): TransformHandle
	local packageRoot = resolveFromCwd(options.packageRoot)
	local tempRoot = normalizePath(resolveFromCwd(options.tempDir))
	local cwd = normalizePath(process.cwd):gsub("/+$", "")
	assert(
		tempRoot:sub(1, #cwd + 1) == cwd .. "/" and not tempRoot:find("/../", 1, true),
		"test copy must stay inside this workspace"
	)
	local stubSource = options.replicatedStorageStubSource
	local stubPath = if stubSource ~= nil then joinPath(tempRoot, "externalStub.luau") else nil
	local packageFiles = discoverPackageFiles(packageRoot)
	local sourceFileSet: { [string]: true } = {}

	if fs.isDir(tempRoot) then
		fs.removeDir(tempRoot)
	end
	fs.writeDir(tempRoot)

	if stubPath ~= nil then
		fs.writeFile(stubPath, stubSource :: string)
	end

	for _, rel in packageFiles do
		sourceFileSet[rel] = true
	end

	for _, rel in packageFiles do
		local targetPath = joinPath(tempRoot, rel)
		local source = if options.moduleOverrides ~= nil and options.moduleOverrides[rel] ~= nil
			then options.moduleOverrides[rel]
			else fs.readFile(joinPath(packageRoot, rel))
		local transformed = source:gsub("require%(%s*(script[^%)]*)%)", function(expression)
			local packageName = expression:match("%.roblox_packages%.([%w_]+)%s*$")
			local packagePath = if packageName and options.packageOverrides
				then options.packageOverrides[packageName]
				else nil
			if packagePath then
				return "require([[" .. relativeRequirePath(targetPath, resolveFromCwd(packagePath)) .. "]])"
			end
			return "require([[" .. resolveScriptRequire(rel, expression, tempRoot, sourceFileSet) .. "]])"
		end)
		if stubPath ~= nil or options.externalOverrides ~= nil then
			transformed = transformed:gsub(
				"require%(%s*(game%.ReplicatedStorage%.([^%)]-))%s*%)",
				function(expression, pathSuffix)
					local overridePath = if options.externalOverrides ~= nil
						then options.externalOverrides[pathSuffix]
						else nil
					if overridePath ~= nil then
						return "require([[" .. relativeRequirePath(targetPath, resolveFromCwd(overridePath)) .. "]])"
					end
					if stubPath ~= nil then
						return "require([[" .. relativeRequirePath(targetPath, stubPath) .. "]])"
					end
					return "require(" .. expression .. ")"
				end
			)
		end
		if options.externalOverrides ~= nil then
			transformed = transformed:gsub(
				"require%(%s*(game%.ReplicatedFirst%.([^%)]-))%s*%)",
				function(expression, pathSuffix)
					local overridePath = options.externalOverrides["ReplicatedFirst." .. pathSuffix]
					if overridePath ~= nil then
						return "require([[" .. relativeRequirePath(targetPath, resolveFromCwd(overridePath)) .. "]])"
					end
					return "require(" .. expression .. ")"
				end
			)
		end
		if stubPath ~= nil then
			if options.rewriteTaskGlobal == true then
				transformed =
					transformed:gsub("task%.", "require([[" .. relativeRequirePath(targetPath, stubPath) .. "]]).task.")
			end
		end
		if options.sourceTransform ~= nil then
			transformed = options.sourceTransform(transformed, rel)
		end

		local targetDir = dirname(targetPath)
		if targetDir ~= "" then
			fs.writeDir(targetDir)
		end
		fs.writeFile(targetPath, transformed)
	end

	return {
		root = tempRoot,
		requireModule = function(relativePath: string): any
			local loaderPath = resolveFromCwd("tests/lune/lib/luneRequireTransform.luau")
			return requireAny(relativeRequirePath(loaderPath, joinPath(tempRoot, relativePath)))
		end,
		cleanup = function(): ()
			if fs.isDir(tempRoot) then
				fs.removeDir(tempRoot)
			end
		end,
	}
end

return LuneRequireTransform
