--!nonstrict
local PackageManager = require("../../PackageManager")
local isLuwow = require("../isLuwow")

local Datatypes = {}

local LUWOW_TYPES = {
	Instance = "BaseObject",
	Color3 = "Color",
	Vector2 = "vector",
}

if not isLuwow then
	Datatypes.UDim = UDim
	Datatypes.UDim2 = UDim2
	Datatypes.Color3 = Color3
	Datatypes.Vector2 = Vector2
	Datatypes.Rect = Rect
	Datatypes.Enum = Enum
	Datatypes.Font = Font
	Datatypes.TweenInfo = TweenInfo
	Datatypes.NumberSequence = NumberSequence
	Datatypes.NumberSequenceKeypoint = NumberSequenceKeypoint
	Datatypes.ColorSequence = ColorSequence
	Datatypes.ColorSequenceKeypoint = ColorSequenceKeypoint
	Datatypes.NumberRange = NumberRange
	Datatypes.Path2DControlPoint = Path2DControlPoint
	Datatypes.task = task
	Datatypes.typeof = function(value: any): string
		local kind = typeof(value)
		return LUWOW_TYPES[kind] or kind
	end
	return table.freeze(Datatypes)
end

local Fusion = PackageManager.getPackage("Fusion")
local Color = require("@Luwow/color")
local LuwowRect = require("@Luwow/rect")

local runtime = Fusion.Runtime

Datatypes.UDim = require("@Luwow/udim")
Datatypes.UDim2 = require("@Luwow/udim2")
local luwowTask = require("@Luwow/task")
local FRAME = 1 / 60
local task = table.clone(luwowTask)
function task.wait(seconds: number?): number
	return luwowTask.wait(if seconds == nil or seconds <= 0 then FRAME else seconds)
end
Datatypes.task = table.freeze(task)

Datatypes.Color3 = table.freeze({
	new = function(r: number?, g: number?, b: number?)
		return Color.new(r or 0, g or 0, b or 0)
	end,
	fromRGB = function(r: number?, g: number?, b: number?)
		return Color.fromRGB(r or 0, g or 0, b or 0)
	end,
	fromHSV = function(h: number, s: number, v: number)
		return Color.fromHSV(h, s, v)
	end,
	fromHex = Color.fromHex,
	toHSV = Color.toHSV,
})

local function vector2(x: number?, y: number?): vector
	return vector.create(x or 0, y or 0, 0)
end

Datatypes.Vector2 = table.freeze({
	new = vector2,
	zero = vector2(0, 0),
	one = vector2(1, 1),
	xAxis = vector2(1, 0),
	yAxis = vector2(0, 1),
})

Datatypes.Rect = table.freeze({
	new = function(a: any, b: any, c: number?, d: number?)
		if typeof(a) == "vector" then
			return LuwowRect.new(a, b - a)
		end
		local minX, minY = a or 0, b or 0
		return LuwowRect.new(minX, minY, (c or 0) - minX, (d or 0) - minY)
	end,
})

local WEIGHTS = {"Thin", "ExtraLight", "Light", "Regular", "Medium", "SemiBold", "Bold", "ExtraBold", "Heavy"}

local function splitFontName(name: string): (string, string)
	local weight = "Regular"
	for _, candidate in WEIGHTS do
		if #name > #candidate and string.sub(name, -#candidate) == candidate then
			weight = candidate
			name = string.sub(name, 1, -#candidate - 1)
			break
		end
	end
	local family = string.gsub(name, "(%l)(%u)", "%1 %2")
	return family, weight
end

--[[
	A font like Roblox's Font: a family, a weight and a style. The family is a
	name, as Luwow's Font property takes it, and Foundation's Luwow instances
	turn the rest into a FontStyle, see Luwow/Instances.
]]
local function font(family: string, weight: string?, style: string?)
	local asset = string.match(family, "([%w_]+)%.json$")
	if asset ~= nil then
		family = (splitFontName(asset))
	end
	return table.freeze({
		Family = family,
		Weight = weight or "Regular",
		Style = style or "Normal",
	})
end

local fontEnum = setmetatable({}, {
	__index = function(self, name: string)
		local family, weight = splitFontName(name)
		local item = font(family, weight, "Normal")
		rawset(self, name, item)
		return item
	end,
})

local ENUM_ITEMS: {[string]: {string}} = {
	PreferredTextSize = {"Medium", "Large", "Larger", "Largest"},
	PreferredInput = {"KeyboardAndMouse", "Gamepad", "Touch"},
}

--[[
	Luwow takes enums as their item names, so Enum.FillDirection.Horizontal is
	"Horizontal". Enum.Font's items are fonts, see font.
]]
Datatypes.Enum = setmetatable({Font = fontEnum}, {
	__index = function(self, enumName: string)
		local items = setmetatable({}, {
			__index = function(_, itemName: string)
				if itemName == "GetEnumItems" then
					return function()
						return table.clone(ENUM_ITEMS[enumName] or {})
					end
				end
				return itemName
			end,
		})
		rawset(self, enumName, items)
		return items
	end,
})

Datatypes.Font = table.freeze({
	new = font,
	fromEnum = function(item: any)
		return item
	end,
	fromName = function(name: string, weight: string?, style: string?)
		local family = splitFontName(name)
		return font(family, weight, style)
	end,
})

Datatypes.TweenInfo = runtime.TweenInfo

Datatypes.NumberSequence = table.freeze({
	new = function(first: any, second: any?)
		if typeof(first) == "table" then
			return table.freeze({Keypoints = first})
		end
		return table.freeze({Keypoints = {
			{Time = 0, Value = first, Envelope = 0},
			{Time = 1, Value = second or first, Envelope = 0},
		}})
	end,
})
Datatypes.NumberSequenceKeypoint = table.freeze({
	new = function(time: number, value: number, envelope: number?)
		return table.freeze({Time = time, Value = value, Envelope = envelope or 0})
	end,
})
Datatypes.ColorSequence = table.freeze({
	new = function(first: any, second: any?)
		if typeof(first) == "table" then
			return table.freeze({Keypoints = first})
		end
		return table.freeze({Keypoints = {
			{Time = 0, Value = first},
			{Time = 1, Value = second or first},
		}})
	end,
})
Datatypes.ColorSequenceKeypoint = table.freeze({
	new = function(time: number, value: any)
		return table.freeze({Time = time, Value = value})
	end,
})
Datatypes.NumberRange = table.freeze({
	new = function(min: number, max: number?)
		return table.freeze({Min = min, Max = max or min})
	end,
})
Datatypes.Path2DControlPoint = table.freeze({
	new = function(position: any, leftTangent: any?, rightTangent: any?)
		return table.freeze({Position = position, LeftTangent = leftTangent, RightTangent = rightTangent})
	end,
})

function Datatypes.typeof(value: any): string
	if runtime.isInstance(value) then
		return "BaseObject"
	end
	return typeof(value)
end

return table.freeze(Datatypes)
