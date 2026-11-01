--!nonstrict
local net = require("@Luwow/net")
local fs = require("@Luwow/fs")
local task = require("@Luwow/task")

--[[
	Roblox's content ids as image files Luwow can show. Roblox images aren't
	files, so they're fetched the way Pinevex Renderer
	(github.com/whutdev/pinevex-renderer) fetches them: the Thumbnails API
	turns ids into image URLs on Roblox's CDN, in batches, polled until each
	thumbnail is ready, and the PNGs are downloaded into a cache.

		rbxassetid://123                      an asset's thumbnail
		https://www.roblox.com/asset/?id=123  the same
		rbxthumb://type=AvatarHeadShot&id=1&w=150&h=150
		rbxasset://textures/ui/icon.png       a file in contentDirectory or extraContentDirectory

	Thumbnails are resized to the size asked for, so a sprite sheet's pixels
	aren't the authored ones anymore: imageScale gives the factor its
	ImageRect and SliceCenter coordinates are multiplied by.
]]

local RobloxAssets = {}

RobloxAssets.cacheDirectory = ".luwow/roblox-assets"
RobloxAssets.assetSize = "700x700"
RobloxAssets.contentDirectory = nil :: string?
RobloxAssets.extraContentDirectory = nil :: string?

local API = "https://thumbnails.roblox.com/v1/"
local BATCH_SIZE = 50
local READY_POLLS = 6
local READY_DELAY = 0.45
local MAX_RETRIES = 5
local REQUEST_TIMEOUT = 15
local PNG_SIGNATURE = "\137PNG\r\n\26\n"

local THUMBNAIL_TYPES = {
	Asset = {path = "assets", ids = "assetIds"},
	Avatar = {path = "users/avatar", ids = "userIds"},
	AvatarHeadShot = {path = "users/avatar-headshot", ids = "userIds"},
	AvatarBust = {path = "users/avatar-bust", ids = "userIds"},
	BadgeIcon = {path = "badges/icons", ids = "badgeIds"},
	BundleThumbnail = {path = "bundles/thumbnails", ids = "bundleIds"},
	GameIcon = {path = "places/gameicons", ids = "placeIds"},
	GamePass = {path = "game-passes", ids = "gamePassIds"},
	GroupIcon = {path = "groups/icons", ids = "groupIds"},
	Outfit = {path = "users/outfits", ids = "userOutfitIds"},
}

export type Reference = {
	kind: string,
	id: string,
	size: string,
	key: string,
}

local waiting: {[string]: {(string?) -> ()}} = {}
local pending: {[string]: Reference} = {}
local flushing = false
local failed: {[string]: string} = {}
local imageSizes: {[string]: vector} = {}
local authoredSizes: {[string]: vector} = {}

local function decodeJson(text: string): any
	local position = 1

	local function skip()
		position = string.find(text, "[^%s]", position) or #text + 1
	end

	local value

	local function decodeString(): string
		local parts = {}
		position += 1
		while true do
			local start, finish, escape = string.find(text, '([\\"])', position)
			if start == nil then
				error("unterminated string in JSON")
			end
			table.insert(parts, string.sub(text, position, start - 1))
			if escape == '"' then
				position = finish + 1
				return table.concat(parts)
			end
			local kind = string.sub(text, start + 1, start + 1)
			if kind == "u" then
				table.insert(parts, utf8.char(tonumber(string.sub(text, start + 2, start + 5), 16) :: number))
				position = start + 6
			else
				local escapes = {b = "\b", f = "\f", n = "\n", r = "\r", t = "\t"}
				table.insert(parts, escapes[kind] or kind)
				position = start + 2
			end
		end
	end

	function value(): any
		skip()
		local first = string.sub(text, position, position)
		if first == "{" then
			local object = {}
			position += 1
			skip()
			if string.sub(text, position, position) == "}" then
				position += 1
				return object
			end
			while true do
				skip()
				local key = decodeString()
				skip()
				position += 1
				object[key] = value()
				skip()
				local separator = string.sub(text, position, position)
				position += 1
				if separator == "}" then
					return object
				end
			end
		elseif first == "[" then
			local array = {}
			position += 1
			skip()
			if string.sub(text, position, position) == "]" then
				position += 1
				return array
			end
			while true do
				table.insert(array, value())
				skip()
				local separator = string.sub(text, position, position)
				position += 1
				if separator == "]" then
					return array
				end
			end
		elseif first == '"' then
			return decodeString()
		elseif string.sub(text, position, position + 3) == "true" then
			position += 4
			return true
		elseif string.sub(text, position, position + 4) == "false" then
			position += 5
			return false
		elseif string.sub(text, position, position + 3) == "null" then
			position += 4
			return nil
		end
		local number = string.match(text, "^-?[%d%.eE+-]+", position)
		if number == nil then
			error(`unexpected {first} in JSON`)
		end
		position += #number
		return tonumber(number)
	end

	return value()
end

local function queryValue(query: string, name: string): string?
	return string.match("&" .. query, "&" .. name .. "=([^&]*)")
end

--[[
	What a content id refers to, or nil when it isn't a Roblox image: files
	and other strings are left as they are.
]]
function RobloxAssets.parse(content: string): Reference?
	if typeof(content) ~= "string" then
		return nil
	end
	local id = string.match(content, "^rbxassetid://(%d+)")
		or string.match(string.lower(content), "^https?://[%w%.]*roblox%.com/asset/%?id=(%d+)")
	if id ~= nil then
		return {kind = "Asset", id = id, size = RobloxAssets.assetSize, key = `Asset-{id}-{RobloxAssets.assetSize}`}
	end

	local query = string.match(content, "^rbxthumb://(.+)$")
	if query == nil then
		return nil
	end
	local kind = queryValue(query, "type")
	id = queryValue(query, "id")
	if kind == nil or id == nil or THUMBNAIL_TYPES[kind] == nil then
		return nil
	end
	local width = queryValue(query, "w") or "150"
	local height = queryValue(query, "h") or width
	local size = `{width}x{height}`
	return {kind = kind, id = id, size = size, key = `{kind}-{id}-{size}`}
end

function RobloxAssets.isRobloxContent(content: any): boolean
	return typeof(content) == "string" and (string.match(content, "^rbx") ~= nil or RobloxAssets.parse(content) ~= nil)
end

function RobloxAssets.localPath(content: string): string?
	local path = string.match(content, "^rbxasset://(.+)$")
	if path == nil then
		return nil
	end
	for _, directory in {RobloxAssets.contentDirectory, RobloxAssets.extraContentDirectory} do
		local file = `{directory}/{path}`
		if fs.exists(file) then
			return file
		end
	end
	return nil
end

RobloxAssets.decodeJson = decodeJson

local function pathOf(reference: Reference): string
	return `{RobloxAssets.cacheDirectory}/{reference.key}.png`
end

local function pngSize(data: string): vector?
	if string.sub(data, 1, 8) ~= PNG_SIGNATURE or #data < 24 then
		return nil
	end
	local width = string.unpack(">I4", data, 17)
	local height = string.unpack(">I4", data, 21)
	return vector.create(width, height, 0)
end

function RobloxAssets.cachedPath(content: string): string?
	local reference = RobloxAssets.parse(content)
	if reference == nil then
		return nil
	end
	local path = pathOf(reference)
	if imageSizes[reference.key] ~= nil or fs.exists(path) then
		return path
	end
	return nil
end

function RobloxAssets.imageSize(content: string): vector?
	local reference = RobloxAssets.parse(content)
	if reference == nil then
		return nil
	end
	local size = imageSizes[reference.key]
	if size == nil and fs.exists(pathOf(reference)) then
		size = pngSize(fs.readFile(pathOf(reference)))
		imageSizes[reference.key] = size
	end
	return size
end

--[[
	Tells the size an asset's image was authored at, such as a sprite sheet's,
	so its coordinates can be mapped onto its thumbnail.
]]
function RobloxAssets.setAuthoredSize(content: string, size: vector)
	local reference = RobloxAssets.parse(content)
	if reference ~= nil then
		authoredSizes[reference.id] = size
	end
end

local function nextPowerOfTwo(value: number): number
	local power = 1
	while power < value do
		power *= 2
	end
	return power
end

--[[
	What an asset's authored pixel coordinates are multiplied by on its
	downloaded thumbnail, nil while it isn't downloaded. A thumbnail fits the
	image in its square, centered, which gives the offset too. Without a size
	from setAuthoredSize, the image is taken to be the smallest square power of
	two holding extent, the furthest corner its coordinates reach, which is how
	sprite sheets are usually packed.
]]
function RobloxAssets.imageScale(content: string, extent: vector?): (number?, vector?)
	local reference = RobloxAssets.parse(content)
	local downloaded = RobloxAssets.imageSize(content)
	if reference == nil or downloaded == nil then
		return nil, nil
	end
	local authored = authoredSizes[reference.id]
	if authored == nil then
		local furthest = if extent then math.max(extent.X, extent.Y) else 0
		if furthest <= 0 then
			return 1, vector.create(0, 0, 0)
		end
		local side = nextPowerOfTwo(furthest)
		authored = vector.create(side, side, 0)
	end
	local scale = math.min(downloaded.X / authored.X, downloaded.Y / authored.Y)
	local offset = vector.create((downloaded.X - authored.X * scale) / 2, (downloaded.Y - authored.Y * scale) / 2, 0)
	return scale, offset
end

local function requestWithRetries(url: string): any
	for attempt = 0, MAX_RETRIES - 1 do
		local ok, response = pcall(net.request, {url = url, timeout = REQUEST_TIMEOUT})
		if ok and response.status ~= 429 and response.status < 500 then
			return response
		end
		task.wait(math.min(30, 2 ^ attempt) + math.random())
	end
	return nil
end

local function resolveUrls(kind: string, size: string, ids: {string}): {[string]: string}
	local endpoint = THUMBNAIL_TYPES[kind]
	local urls = {}
	local remaining = ids
	for poll = 1, READY_POLLS do
		if #remaining == 0 then
			break
		end
		local stillPending = {}
		for start = 1, #remaining, BATCH_SIZE do
			local batch = table.move(remaining, start, math.min(start + BATCH_SIZE - 1, #remaining), 1, {})
			local url = `{API}{endpoint.path}?{endpoint.ids}={table.concat(batch, ",")}&size={size}&format=Png&returnPolicy=PlaceHolder`
			local response = requestWithRetries(url)
			if response == nil or not response.ok then
				continue
			end
			local decoded = decodeJson(response.body)
			local seen = {}
			for _, item in decoded.data or {} do
				local id = string.format("%.0f", item.targetId)
				seen[id] = true
				if item.state == "Completed" and item.imageUrl then
					urls[id] = item.imageUrl
				elseif item.state == "Pending" or item.state == "InReview" then
					table.insert(stillPending, id)
				end
			end
			for _, id in batch do
				if not seen[id] and urls[id] == nil then
					table.insert(stillPending, id)
				end
			end
		end
		remaining = stillPending
		if #remaining > 0 and poll < READY_POLLS then
			task.wait(READY_DELAY * poll)
		end
	end
	return urls
end

local function finish(reference: Reference, path: string?)
	local callbacks = waiting[reference.key] or {}
	waiting[reference.key] = nil
	for _, callback in callbacks do
		task.spawn(callback, path)
	end
end

local function flush()
	while next(pending) ~= nil do
		local groups: {[string]: {Reference}} = {}
		for key, reference in pending do
			local group = `{reference.kind}|{reference.size}`
			groups[group] = groups[group] or {}
			table.insert(groups[group], reference)
		end
		table.clear(pending)

		if not fs.exists(RobloxAssets.cacheDirectory) then
			fs.mkdir(RobloxAssets.cacheDirectory, true)
		end

		for _, references in groups do
			local ids = {}
			for _, reference in references do
				table.insert(ids, reference.id)
			end
			local urls = resolveUrls(references[1].kind, references[1].size, ids)
			for _, reference in references do
				local url = urls[reference.id]
				local response = if url then requestWithRetries(url) else nil
				local size = if response and response.ok then pngSize(response.body) else nil
				if size == nil then
					failed[reference.key] = if url == nil then "no thumbnail" else "not an image"
					finish(reference, nil)
				else
					local path = pathOf(reference)
					fs.writeFile(path, response.body)
					imageSizes[reference.key] = size
					finish(reference, path)
				end
			end
		end
	end
	flushing = false
end

--[[
	Calls back with the image file of a content id once it's downloaded, or
	with nil when it can't be. Downloads asked for together are fetched in
	batches, on a thread of their own.
]]
function RobloxAssets.request(content: string, callback: (path: string?) -> ())
	local reference = RobloxAssets.parse(content)
	if reference == nil or failed[reference.key] ~= nil then
		task.spawn(callback, nil)
		return
	end
	local cached = RobloxAssets.cachedPath(content)
	if cached ~= nil then
		task.spawn(callback, cached)
		return
	end

	local callbacks = waiting[reference.key]
	if callbacks == nil then
		callbacks = {}
		waiting[reference.key] = callbacks
		pending[reference.key] = reference
	end
	table.insert(callbacks, callback)
	if not flushing then
		flushing = true
		task.defer(flush)
	end
end

function RobloxAssets.fetch(contents: {string}): {[string]: string}
	local files = {}
	local remaining = 0
	local current = coroutine.running()
	local waitingForAll = false
	for _, content in contents do
		remaining += 1
		RobloxAssets.request(content, function(path)
			files[content] = path
			remaining -= 1
			if remaining == 0 and waitingForAll then
				task.spawn(current)
			end
		end)
	end
	if remaining > 0 then
		waitingForAll = true
		coroutine.yield()
	end
	return files
end

return RobloxAssets
