const Json = require("@Backend/tools/Json")

-- (F|DF|SF)(Flag|String|Int|Log), alternatives in the regex's order
const FLAG_CLASSES = { "F", "DF", "SF" }
const FLAG_TYPES = { "Flag", "String", "Int", "Log" }

local FVariable = {}
FVariable.__index = FVariable

--// Types

export type FVariable = setmetatable<
	{
		Name: string,
		Type: string,
		Reset: string,
		Value: string,
		Custom: boolean,
		Dirty: boolean, -- Internal, not saved
		Key: string
	},
	typeof(FVariable)
>

-- How an FVariable is saved in state.json's FlagEditor
export type SavedFVariable = {
	Name: string?,
	Type: string?,
	Reset: string?,
	Value: string?,
	Custom: boolean?
}

--// Local Functions

-- The type the flagTypes regex matches first: the leftmost match, the alternatives tried in order
local function matchFlagType(key: string): string
	for start = 1, #key do
		for _, flagClass in FLAG_CLASSES do
			if string.sub(key, start, start + #flagClass - 1) ~= flagClass then continue end
			local after = start + #flagClass
			for _, flagType in FLAG_TYPES do
				if string.sub(key, after, after + #flagType - 1) ~= flagType then continue end
				return flagClass .. flagType
			end
		end
	end
	return ""
end

local function endsWith(text: string, suffix: string): boolean
	return #text >= #suffix and string.sub(text, -#suffix) == suffix
end

--// Module Functions

-- A flag from its key, such as "DFIntTaskSchedulerTargetFps", and value
function FVariable.new(key: string, value: string, custom: boolean?): FVariable
	local flagType = matchFlagType(key)
	local name = string.sub(key, #flagType + 1)

	if endsWith(flagType, "Flag") then
		value = string.lower(value)
	end

	return setmetatable({
		Name = name,
		Type = flagType,
		Reset = value,
		Value = value,
		Custom = custom == true,
		Dirty = true,
		Key = flagType .. name,
	}, FVariable)
end

-- A flag as state.json's FlagEditor keeps it
function FVariable.fromSaved(saved: SavedFVariable): FVariable
	local flagType = saved.Type or ""
	local name = saved.Name or ""
	return setmetatable({
		Name = name,
		Type = flagType,
		Reset = saved.Reset or "",
		Value = saved.Value or "",
		Custom = saved.Custom == true,
		Dirty = true,
		Key = flagType .. name,
	}, FVariable)
end

function FVariable.SetValue(self: FVariable, value: string)
	if self.Value ~= value then
		self.Value = value
		self.Dirty = true
	end
end

function FVariable.Clear(self: FVariable)
	self:SetValue(self.Reset)
end

function FVariable.IsType(self: FVariable, suffix: string): boolean
	return endsWith(self.Type, suffix)
end

function FVariable.ToSaved(self: FVariable): { [string]: any }
	return Json.object({
		Name = self.Name,
		Type = self.Type,
		Reset = self.Reset,
		Value = self.Value,
		Custom = self.Custom,
	})
end

return FVariable
