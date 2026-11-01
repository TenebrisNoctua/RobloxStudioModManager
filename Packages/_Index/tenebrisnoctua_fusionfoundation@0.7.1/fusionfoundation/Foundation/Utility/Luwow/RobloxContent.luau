--!nonstrict
local gui = require("@Luwow/udc")
local fs = require("@Luwow/fs")

local RobloxAssets = require("./RobloxAssets")
local FoundationImages = require("../../PackageManager/Packages/FoundationImages")

--[[
	A Roblox Studio installation's content, used in place of downloads when
	it's there: its content folder and the ExtraContent next to it.

		fonts       the font families in content/fonts/families, loaded with
		            gui.loadFont when they're first used
		rbxasset:// files in content or ExtraContent
		images      Foundation's sprite sheets, full size in
		            ExtraContent/LuaPackages, rather than thumbnails. Studio's
		            FoundationImages may be packed differently from the one
		            vendored here, so its own rectangles are used with them.
		icons       BuilderIcons' fonts. Luwow's text has no ligatures, so an
		            icon is drawn as its own character, read from the font.
]]

local RobloxContent = {}

local FOUNDATION_IMAGES = "rbxasset://LuaPackages/Packages/_Index/FoundationImages/FoundationImages/SpriteSheets"
local IMAGE_SET_DATA = "LuaPackages/Packages/_Index/FoundationImages/FoundationImages/Generated/GetImageSetData.lua"
local BUILDER_ICONS = "rbxasset://LuaPackages/Packages/_Index/BuilderIcons/BuilderIcons/BuilderIcons.json"

type Face = {
	weight: number,
	style: string,
	asset: string,
}

local contentDirectory: string? = nil
local families: {[string]: {Face}} = {}
local loadedFamilies: {[string]: boolean} = {}

type Icons = {
	regular: string,
	filled: string,
	codepoints: {[string]: number},
}
local icons: Icons? = nil

function RobloxContent.findStudioContent(): string?
	local candidates = {"/Applications/RobloxStudio.app/Contents/Resources/content"}
	if fs.exists("C:/Users") then
		for _, entry in fs.listdir("C:/Users") do
			if entry.type == "dir" then
				table.insert(candidates, 1, `C:/Users/{entry.name}/AppData/Local/Roblox Studio/content`)
			end
		end
	end
	for _, candidate in candidates do
		if fs.exists(candidate) then
			return candidate
		end
	end
	return nil
end

local function readIconCodepoints(path: string): {[string]: number}
	local data = fs.readFile(path)
	local tables = {}
	local tableCount = string.unpack(">I2", data, 5)
	for index = 0, tableCount - 1 do
		local record = 13 + index * 16
		local tag = string.sub(data, record, record + 3)
		tables[tag] = string.unpack(">I4", data, record + 8) + 1
	end

	local glyphCharacters = {}
	local cmap = tables.cmap
	for index = 0, string.unpack(">I2", data, cmap + 2) - 1 do
		local record = cmap + 4 + index * 8
		local platform, encoding, offset = string.unpack(">I2I2I4", data, record)
		local subtable = cmap + offset
		if platform == 3 and encoding == 10 and string.unpack(">I2", data, subtable) == 12 then
			local groupCount = string.unpack(">I4", data, subtable + 12)
			for group = 0, groupCount - 1 do
				local first, last, glyph = string.unpack(">I4I4I4", data, subtable + 16 + group * 12)
				for character = math.max(first, 0xE000), math.min(last, 0xF8FF) do
					glyphCharacters[glyph + character - first] = character
				end
			end
		end
	end

	local codepoints = {}
	local post = tables.post
	if string.unpack(">I4", data, post) ~= 0x00020000 then
		return codepoints
	end
	local glyphCount = string.unpack(">I2", data, post + 32)
	local nameIndexes = {}
	for glyph = 0, glyphCount - 1 do
		nameIndexes[glyph] = string.unpack(">I2", data, post + 34 + glyph * 2)
	end
	local names = {}
	local position = post + 34 + glyphCount * 2
	while position <= #data and #names < glyphCount do
		local length = string.byte(data, position)
		table.insert(names, string.sub(data, position + 1, position + length))
		position += length + 1
	end
	for glyph, nameIndex in nameIndexes do
		local character = glyphCharacters[glyph]
		local name = if nameIndex >= 258 then names[nameIndex - 257] else nil
		if character ~= nil and name ~= nil then
			codepoints[name] = character
		end
	end
	return codepoints
end

local function readFamily(file: string): (string?, {Face})
	local text = fs.readFile(file)
	local name = string.match(text, '"name"%s*:%s*"([^"]+)"')
	local faces = {}
	local list = string.match(text, '"faces"%s*:%s*(%b[])') or ""
	for face in string.gmatch(list, "%b{}") do
		local asset = string.match(face, '"assetId"%s*:%s*"([^"]+)"')
		if asset ~= nil then
			table.insert(faces, {
				weight = tonumber(string.match(face, '"weight"%s*:%s*(%d+)')) or 400,
				style = string.match(face, '"style"%s*:%s*"([^"]+)"') or "normal",
				asset = asset,
			})
		end
	end
	return name, faces
end

local function loadIcons()
	local file = RobloxAssets.localPath(BUILDER_ICONS)
	if file == nil then
		return
	end
	local _, faces = readFamily(file)
	local regular, filled = nil, nil
	for _, face in faces do
		local path = RobloxAssets.localPath(face.asset)
		if path ~= nil and pcall(gui.loadFont, path) then
			local family = string.match(path, "([^/\\]+)%.%a+$")
			if face.weight >= 700 then
				filled = filled or {family = family, path = path}
			else
				regular = regular or {family = family, path = path}
			end
		end
	end
	if regular == nil then
		return
	end
	local ok, codepoints = pcall(readIconCodepoints, regular.path)
	if ok and next(codepoints) ~= nil then
		icons = {
			regular = regular.family,
			filled = if filled then filled.family else regular.family,
			codepoints = codepoints,
		}
	end
end

--[[
	Uses a Roblox Studio content folder, such as findStudioContent's. Its
	ExtraContent is the folder next to it.
]]
--[[
	Points Foundation's Images at Studio's sprite sheets, with the rectangles
	Studio's own GetImageSetData gives them at the scale Foundation uses. The
	images Studio doesn't have keep their uploaded sheets, downloaded as before.
]]
local function useStudioImageSets()
	local extra = RobloxAssets.extraContentDirectory
	local file = if extra then `{extra}/{IMAGE_SET_DATA}` else nil
	if file == nil or not fs.exists(file) then
		return
	end
	local source = fs.readFile(file)
	local scale = FoundationImages.getResolutionScale()
	local section = string.match(source, "function make_assets_" .. scale .. "x%(%) assets_" .. scale .. "x = (%b{})")
	if section == nil then
		return
	end

	local images = FoundationImages.Images
	local pattern = "%['([^']+)'%] = { ImageRectOffset = Vector2%.new%((%d+), (%d+)%), ImageRectSize = Vector2%.new%((%d+), (%d+)%), ImageSet = '([^']+)' }"
	for name, x, y, width, height, sheet in string.gmatch(section, pattern) do
		local image = rawget(images, name)
		if image ~= nil then
			image.Image = `{FOUNDATION_IMAGES}/{sheet}.png`
			image.ImageRectOffset = vector.create(tonumber(x), tonumber(y), 0)
			image.ImageRectSize = vector.create(tonumber(width), tonumber(height), 0)
		end
	end
end

function RobloxContent.setDirectory(path: string)
	path = string.gsub(path, "\\", "/")
	path = string.gsub(path, "/+$", "")
	contentDirectory = path
	RobloxAssets.contentDirectory = path
	RobloxAssets.extraContentDirectory = string.gsub(path, "/[^/]+$", "") .. "/ExtraContent"

	table.clear(families)
	table.clear(loadedFamilies)
	local directory = `{path}/fonts/families`
	if fs.exists(directory) then
		for _, entry in fs.listdir(directory) do
			if entry.type == "file" and string.match(entry.name, "%.json$") then
				local name, faces = readFamily(`{directory}/{entry.name}`)
				if name ~= nil then
					families[name] = faces
				end
			end
		end
	end
	icons = nil
	loadIcons()
	useStudioImageSets()
end

function RobloxContent.directory(): string?
	return contentDirectory
end

--[[
	Loads the faces of a family that are files in the content folder, the
	first time it's asked for. Returns whether any loaded.
]]
function RobloxContent.loadFamily(name: string): boolean
	local loaded = loadedFamilies[name]
	if loaded ~= nil then
		return loaded
	end
	loaded = false
	for _, face in families[name] or {} do
		local path = RobloxAssets.localPath(face.asset)
		if path ~= nil and pcall(gui.loadFont, path) then
			loaded = true
		end
	end
	loadedFamilies[name] = loaded
	return loaded
end

function RobloxContent.localImage(content: string): string?
	return RobloxAssets.localPath(content)
end

function RobloxContent.iconFamily(filled: boolean?): string?
	if icons == nil then
		return nil
	end
	return if filled then icons.filled else icons.regular
end

function RobloxContent.iconCharacter(name: string): string?
	local codepoint = if icons then icons.codepoints[name] else nil
	return if codepoint then utf8.char(codepoint) else nil
end

return RobloxContent
