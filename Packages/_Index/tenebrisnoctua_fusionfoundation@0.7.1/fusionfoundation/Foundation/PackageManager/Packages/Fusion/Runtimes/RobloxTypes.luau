--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Animates Roblox's datatypes for the Roblox runtime provider: interpolates
	them, and packs them to and unpacks them from arrays of numbers. Numbers
	themselves are handled by Fusion's animation code.
]]

local Types = require("../Types")
local Oklab = require("../Colour/Oklab")

local RobloxTypes = {}

local function colorToLab(color: Color3): (number, number, number)
	return Oklab.fromSRGB(color.R, color.G, color.B)
end

local function labToColor(L: number, a: number, b: number): Color3
	return Color3.new(Oklab.toSRGB(L, a, b, false))
end

local function lerpColor(from: Color3, to: Color3, ratio: number): Color3
	local fromL, fromA, fromB = colorToLab(from)
	local toL, toA, toB = colorToLab(to)
	return labToColor(
		(toL - fromL) * ratio + fromL,
		(toA - fromA) * ratio + fromA,
		(toB - fromB) * ratio + fromB
	)
end

--[[
	Linearly interpolates two values of the same type by a ratio, or returns
	nil when the type can't be animated.
]]
function RobloxTypes.lerpType(
	from: unknown,
	to: unknown,
	ratio: number,
	typeString: string
): unknown?
	if typeString == "CFrame" then
		local to, from = to :: CFrame, from :: CFrame
		return from:Lerp(to, ratio)

	elseif typeString == "Color3" then
		local to, from = to :: Color3, from :: Color3
		return lerpColor(from, to, ratio)

	elseif typeString == "ColorSequenceKeypoint" then
		local to, from = to :: ColorSequenceKeypoint, from :: ColorSequenceKeypoint
		return ColorSequenceKeypoint.new(
			(to.Time - from.Time) * ratio + from.Time,
			lerpColor(from.Value, to.Value, ratio)
		)

	elseif typeString == "DateTime" then
		local to, from = to :: DateTime, from :: DateTime
		return DateTime.fromUnixTimestampMillis(
			(to.UnixTimestampMillis - from.UnixTimestampMillis) * ratio + from.UnixTimestampMillis
		)

	elseif typeString == "NumberRange" then
		local to, from = to :: NumberRange, from :: NumberRange
		return NumberRange.new(
			(to.Min - from.Min) * ratio + from.Min,
			(to.Max - from.Max) * ratio + from.Max
		)

	elseif typeString == "NumberSequenceKeypoint" then
		local to, from = to :: NumberSequenceKeypoint, from :: NumberSequenceKeypoint
		return NumberSequenceKeypoint.new(
			(to.Time - from.Time) * ratio + from.Time,
			(to.Value - from.Value) * ratio + from.Value,
			(to.Envelope - from.Envelope) * ratio + from.Envelope
		)

	elseif typeString == "PhysicalProperties" then
		local to, from = to :: PhysicalProperties, from :: PhysicalProperties
		return PhysicalProperties.new(
			(to.Density - from.Density) * ratio + from.Density,
			(to.Friction - from.Friction) * ratio + from.Friction,
			(to.Elasticity - from.Elasticity) * ratio + from.Elasticity,
			(to.FrictionWeight - from.FrictionWeight) * ratio + from.FrictionWeight,
			(to.ElasticityWeight - from.ElasticityWeight) * ratio + from.ElasticityWeight
		)

	elseif typeString == "Ray" then
		local to, from = to :: Ray, from :: Ray
		return Ray.new(
			from.Origin:Lerp(to.Origin, ratio),
			from.Direction:Lerp(to.Direction, ratio)
		)

	elseif typeString == "Rect" then
		local to, from = to :: Rect, from :: Rect
		return Rect.new(
			from.Min:Lerp(to.Min, ratio),
			from.Max:Lerp(to.Max, ratio)
		)

	elseif typeString == "Region3" then
		local to, from = to :: Region3, from :: Region3
		-- FUTURE: support rotated Region3s if/when they become constructable
		local position = from.CFrame.Position:Lerp(to.CFrame.Position, ratio)
		local halfSize = from.Size:Lerp(to.Size, ratio) / 2
		return Region3.new(position - halfSize, position + halfSize)

	elseif typeString == "Region3int16" then
		local to, from = to :: Region3int16, from :: Region3int16
		return Region3int16.new(
			Vector3int16.new(
				(to.Min.X - from.Min.X) * ratio + from.Min.X,
				(to.Min.Y - from.Min.Y) * ratio + from.Min.Y,
				(to.Min.Z - from.Min.Z) * ratio + from.Min.Z
			),
			Vector3int16.new(
				(to.Max.X - from.Max.X) * ratio + from.Max.X,
				(to.Max.Y - from.Max.Y) * ratio + from.Max.Y,
				(to.Max.Z - from.Max.Z) * ratio + from.Max.Z
			)
		)

	elseif typeString == "UDim" then
		local to, from = to :: UDim, from :: UDim
		return UDim.new(
			(to.Scale - from.Scale) * ratio + from.Scale,
			(to.Offset - from.Offset) * ratio + from.Offset
		)

	elseif typeString == "UDim2" then
		local to, from = to :: UDim2, from :: UDim2
		return from:Lerp(to, ratio)

	elseif typeString == "Vector2" then
		local to, from = to :: Vector2, from :: Vector2
		return from:Lerp(to, ratio)

	elseif typeString == "Vector2int16" then
		local to, from = to :: Vector2int16, from :: Vector2int16
		return Vector2int16.new(
			(to.X - from.X) * ratio + from.X,
			(to.Y - from.Y) * ratio + from.Y
		)

	elseif typeString == "Vector3" then
		local to, from = to :: Vector3, from :: Vector3
		return from:Lerp(to, ratio)

	elseif typeString == "Vector3int16" then
		local to, from = to :: Vector3int16, from :: Vector3int16
		return Vector3int16.new(
			(to.X - from.X) * ratio + from.X,
			(to.Y - from.Y) * ratio + from.Y,
			(to.Z - from.Z) * ratio + from.Z
		)
	end

	return nil
end

--[[
	Packs an array of numbers into a given animatable data type.
	If the type is not animatable, nil will be returned.
]]
function RobloxTypes.packType(
	numbers: {number},
	typeString: string
): Types.Animatable?
	if typeString == "CFrame" then
		return
			CFrame.new(numbers[1], numbers[2], numbers[3]) *
			CFrame.fromAxisAngle(
				Vector3.new(numbers[4], numbers[5], numbers[6]).Unit,
				numbers[7]
			)

	elseif typeString == "Color3" then
		return labToColor(numbers[1], numbers[2], numbers[3])

	elseif typeString == "ColorSequenceKeypoint" then
		return ColorSequenceKeypoint.new(
			numbers[4],
			labToColor(numbers[1], numbers[2], numbers[3])
		)

	elseif typeString == "DateTime" then
		return DateTime.fromUnixTimestampMillis(numbers[1])

	elseif typeString == "NumberRange" then
		return NumberRange.new(numbers[1], numbers[2])

	elseif typeString == "NumberSequenceKeypoint" then
		return NumberSequenceKeypoint.new(numbers[2], numbers[1], numbers[3])

	elseif typeString == "PhysicalProperties" then
		return PhysicalProperties.new(numbers[1], numbers[2], numbers[3], numbers[4], numbers[5])

	elseif typeString == "Ray" then
		return Ray.new(
			Vector3.new(numbers[1], numbers[2], numbers[3]),
			Vector3.new(numbers[4], numbers[5], numbers[6])
		)

	elseif typeString == "Rect" then
		return Rect.new(numbers[1], numbers[2], numbers[3], numbers[4])

	elseif typeString == "Region3" then
		-- FUTURE: support rotated Region3s if/when they become constructable
		local position = Vector3.new(numbers[1], numbers[2], numbers[3])
		local halfSize = Vector3.new(numbers[4] / 2, numbers[5] / 2, numbers[6] / 2)
		return Region3.new(position - halfSize, position + halfSize)

	elseif typeString == "Region3int16" then
		return Region3int16.new(
			Vector3int16.new(numbers[1], numbers[2], numbers[3]),
			Vector3int16.new(numbers[4], numbers[5], numbers[6])
		)

	elseif typeString == "UDim" then
		return UDim.new(numbers[1], numbers[2])

	elseif typeString == "UDim2" then
		return UDim2.new(numbers[1], numbers[2], numbers[3], numbers[4])

	elseif typeString == "Vector2" then
		return Vector2.new(numbers[1], numbers[2])

	elseif typeString == "Vector2int16" then
		return Vector2int16.new(numbers[1], numbers[2])

	elseif typeString == "Vector3" then
		return Vector3.new(numbers[1], numbers[2], numbers[3])

	elseif typeString == "Vector3int16" then
		return Vector3int16.new(numbers[1], numbers[2], numbers[3])
	end

	return nil
end

--[[
	Unpacks an animatable type into an array of numbers.
	If the type is not animatable, an empty array will be returned.
]]
function RobloxTypes.unpackType(
	value: unknown,
	typeString: string
): {number}
	if typeString == "CFrame" then
		local value = value :: CFrame
		-- FUTURE: is there a better way of doing this? doing distance
		-- calculations on `angle` may be incorrect
		local axis, angle = value:ToAxisAngle()
		return {value.X, value.Y, value.Z, axis.X, axis.Y, axis.Z, angle}

	elseif typeString == "Color3" then
		local value = value :: Color3
		return {colorToLab(value)}

	elseif typeString == "ColorSequenceKeypoint" then
		local value = value :: ColorSequenceKeypoint
		local L, a, b = colorToLab(value.Value)
		return {L, a, b, value.Time}

	elseif typeString == "DateTime" then
		local value = value :: DateTime
		return {value.UnixTimestampMillis}

	elseif typeString == "NumberRange" then
		local value = value :: NumberRange
		return {value.Min, value.Max}

	elseif typeString == "NumberSequenceKeypoint" then
		local value = value :: NumberSequenceKeypoint
		return {value.Value, value.Time, value.Envelope}

	elseif typeString == "PhysicalProperties" then
		local value = value :: PhysicalProperties
		return {value.Density, value.Friction, value.Elasticity, value.FrictionWeight, value.ElasticityWeight}

	elseif typeString == "Ray" then
		local value = value :: Ray
		return {value.Origin.X, value.Origin.Y, value.Origin.Z, value.Direction.X, value.Direction.Y, value.Direction.Z}

	elseif typeString == "Rect" then
		local value = value :: Rect
		return {value.Min.X, value.Min.Y, value.Max.X, value.Max.Y}

	elseif typeString == "Region3" then
		local value = value :: Region3
		-- FUTURE: support rotated Region3s if/when they become constructable
		return {
			value.CFrame.X, value.CFrame.Y, value.CFrame.Z,
			value.Size.X, value.Size.Y, value.Size.Z
		}

	elseif typeString == "Region3int16" then
		local value = value :: Region3int16
		return {value.Min.X, value.Min.Y, value.Min.Z, value.Max.X, value.Max.Y, value.Max.Z}

	elseif typeString == "UDim" then
		local value = value :: UDim
		return {value.Scale, value.Offset}

	elseif typeString == "UDim2" then
		local value = value :: UDim2
		return {value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset}

	elseif typeString == "Vector2" then
		local value = value :: Vector2
		return {value.X, value.Y}

	elseif typeString == "Vector2int16" then
		local value = value :: Vector2int16
		return {value.X, value.Y}

	elseif typeString == "Vector3" then
		local value = value :: Vector3
		return {value.X, value.Y, value.Z}

	elseif typeString == "Vector3int16" then
		local value = value :: Vector3int16
		return {value.X, value.Y, value.Z}
	end

	return {}
end

return RobloxTypes
