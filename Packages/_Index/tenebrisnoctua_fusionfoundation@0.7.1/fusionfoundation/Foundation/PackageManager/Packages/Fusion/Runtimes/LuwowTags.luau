--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Tags for the Luwow runtime provider, in place of Roblox's
	CollectionService. Instances hold any number of tag names, and listeners
	hear about every tag added or removed, which is how styles follow them.

	Instances are held weakly, so tagging one doesn't keep it alive.
]]

export type Listener = (instance: any, tag: string, added: boolean) -> ()

local LuwowTags = {}

local tagsOf: {[any]: {[string]: true}} = setmetatable({}, {__mode = "k"}) :: any
local listeners: {Listener} = {}

local function notify(
	instance: any,
	tag: string,
	added: boolean
)
	for _, listener in table.clone(listeners) do
		listener(instance, tag, added)
	end
end

--[[
	Adds a tag to an instance. Adding one it already has does nothing.
]]
function LuwowTags.add(
	instance: any,
	tag: string
)
	local tags = tagsOf[instance]
	if tags == nil then
		tags = {}
		tagsOf[instance] = tags
	end
	if tags[tag] then
		return
	end
	tags[tag] = true
	notify(instance, tag, true)
end

--[[
	Removes a tag from an instance. Removing one it doesn't have does nothing.
]]
function LuwowTags.remove(
	instance: any,
	tag: string
)
	local tags = tagsOf[instance]
	if tags == nil or not tags[tag] then
		return
	end
	tags[tag] = nil
	notify(instance, tag, false)
end

function LuwowTags.has(
	instance: any,
	tag: string
): boolean
	local tags = tagsOf[instance]
	return tags ~= nil and tags[tag] == true
end

--[[
	The instance's tags, in no particular order.
]]
function LuwowTags.get(
	instance: any
): {string}
	local list = {}
	for tag in tagsOf[instance] or {} do
		table.insert(list, tag)
	end
	return list
end

--[[
	The instances that have the tag, in no particular order.
]]
function LuwowTags.getTagged(
	tag: string
): {any}
	local list = {}
	for instance, tags in tagsOf do
		if tags[tag] then
			table.insert(list, instance)
		end
	end
	return list
end

--[[
	Every instance with at least one tag, in no particular order.
]]
function LuwowTags.getAllTagged(): {any}
	local list = {}
	for instance, tags in tagsOf do
		if next(tags) ~= nil then
			table.insert(list, instance)
		end
	end
	return list
end

--[[
	Calls the listener for every tag added to or removed from any instance.
	Returns a function that stops it.
]]
function LuwowTags.onChanged(
	listener: Listener
): () -> ()
	table.insert(listeners, listener)
	return function()
		local index = table.find(listeners, listener)
		if index ~= nil then
			table.remove(listeners, index)
		end
	end
end

return LuwowTags
