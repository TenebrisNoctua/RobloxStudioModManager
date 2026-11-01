const Http = require("@Backend/tools/Http")
const BASE_URL = "https://setup.rbxcdn.com"

local PackageManifest = {}
PackageManifest.__index = PackageManifest

--// Types

export type Package = {
	Name: string,
	Signature: string,
	PackedSize: number,
	Size: number,
	Exists: boolean,
	ShouldInstall: boolean
}

export type PackageManifest = setmetatable<
	{
		RawData: string,
		-- The zip packages, in the manifest's order
		Packages: { Package }
	},
	typeof(PackageManifest)
>

--// Local Functions

local function parseSize(text: string?): number?
	local digits = text and string.match(text, "^%s*(%d+)%s*$")
	return if digits then tonumber(digits) else nil
end

--// Module Functions

--[[
	Parses rbxPkgManifest.txt: "v0", then four lines for each package, its
	name, signature, packed size and size. Only zips are kept.
]]
function PackageManifest.parse(data: string): PackageManifest
	local lines = string.split((string.gsub(data, "\r", "")), "\n")
	local version = lines[1]

	if version ~= "v0" then
		error(`Unexpected package manifest version: {version} (expected v0!)`, 0)
	end

	local packages = {}
	local index = 2
	while index + 3 <= #lines do
		local fileName = lines[index]
		local signature = lines[index + 1]
		local packedSize = parseSize(lines[index + 2])
		local size = parseSize(lines[index + 3])
		index += 4

		if not packedSize or not size then
			break
		end

		if string.sub(fileName, -4) == ".zip" then
			table.insert(packages, {
				Name = fileName,
				Signature = signature,
				PackedSize = packedSize,
				Size = size,
				Exists = false,
				ShouldInstall = false
			})
		end
	end

	return setmetatable({
		RawData = data,
		Packages = packages,
	}, PackageManifest)
end

function PackageManifest.get(versionGuid: string): PackageManifest
	return PackageManifest.parse(Http.get(`{BASE_URL}/channel/common/{versionGuid}-rbxPkgManifest.txt`))
end

return PackageManifest
