const Http = require("@Backend/tools/Http")
const BASE_URL = "https://setup.rbxcdn.com"

local FileManifest = {}
FileManifest.__index = FileManifest

--// Types

export type FileManifest = setmetatable<
	{
		RawData: string,
		-- The paths in the manifest's order, as a Dictionary enumerates them
		Paths: { string },
		-- Path -> its signature, the MD5 of its contents
		Signatures: { [string]: string },
		-- A path's suffixes after each separator -> the first path with it, for EndsWith lookups
		BySuffix: { [string]: string }
	},
	typeof(FileManifest)
>

--// Local Functions

local function startsWith(text: string, prefix: string): boolean
	return string.sub(text, 1, #prefix) == prefix
end

-- Indexes the path's suffixes that start after a separator, the whole path included
local function indexSuffixes(manifest: FileManifest, path: string)
	local bySuffix = manifest.BySuffix
	if bySuffix[path] == nil then
		bySuffix[path] = path
	end

	local position = 1
	while true do
		local separator = string.find(path, "\\", position, true)
		if not separator then
			break
		end
		local suffix = string.sub(path, separator + 1)
		if suffix ~= "" and bySuffix[suffix] == nil then
			bySuffix[suffix] = path
		end
		position = separator + 1
	end
end

--// Module Functions

--[[
	Parses rbxManifest.txt: a path and its signature on every two lines.
	With remapExtraContent, ExtraContent is listed as content.
]]
function FileManifest.parse(data: string, remapExtraContent: boolean?): FileManifest
	local manifest = setmetatable({
		RawData = data,
		Paths = {},
		Signatures = {},
		BySuffix = {},
	}, FileManifest)

	local lines = string.split((string.gsub(data, "\r", "")), "\n")
	for index = 1, #lines - 1, 2 do
		local path = lines[index]
		local signature = lines[index + 1]

		if remapExtraContent and startsWith(path, "ExtraContent") then
			path = string.gsub(path, "ExtraContent", "content")
		end

		-- ~~ AWFUL TEMPORARY HACK. ~~
		--
		-- This is necessary because SourceSansPro gets incorrectly listed in the root directory,
		-- but also MUST be extracted to both 'StudioFonts/' and 'content/fonts/', so I need to
		-- make sure it unambiguously extracts to the correct locations.
		if string.sub(path, -4) == ".ttf" and not string.find(path, "\\", 1, true) then
			path = "StudioFonts\\" .. path
		end

		-- !! This bug only happens when remapping ExtraContent.
		if remapExtraContent and manifest.Signatures[path] ~= nil then
			continue
		end

		manifest:Set(path, signature)
	end

	return manifest
end

function FileManifest.get(versionGuid: string, remapExtraContent: boolean?): FileManifest
	return FileManifest.parse(Http.get(`{BASE_URL}/channel/common/{versionGuid}-rbxManifest.txt`), remapExtraContent)
end

function FileManifest.Get(self: FileManifest, path: string): string?
	return self.Signatures[path]
end

function FileManifest.Set(self: FileManifest, path: string, signature: string)
	if self.Signatures[path] == nil then
		table.insert(self.Paths, path)
		indexSuffixes(self, path)
	end
	self.Signatures[path] = signature
end

-- The first path that ends with the given one at a separator, or is it
function FileManifest.FindEndingWith(self: FileManifest, path: string): string?
	return self.BySuffix[path]
end

-- The paths sharing each signature, in the manifest's order
function FileManifest.GroupBySignature(self: FileManifest): { [string]: { string } }
	local groups = {}
	for _, path in self.Paths do
		local signature = self.Signatures[path]
		local group = groups[signature]
		if not group then
			group = {}
			groups[signature] = group
		end
		table.insert(group, path)
	end
	return groups
end

return FileManifest
