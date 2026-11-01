--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Provides functions for converting colours into Oklab space, for more
	perceptually uniform colour blending.

	Colours are passed as their red, green and blue channels from 0 to 1, and
	Oklab colours as their L, a and b components, so these work with any
	runtime's colour type.

	See: https://bottosson.github.io/posts/oklab/
]]

local sRGB = require("./sRGB")

local Oklab = {}

-- Converts a colour in linear RGB space to Oklab space.
function Oklab.fromLinear(red: number, green: number, blue: number): (number, number, number)
	local l = red * 0.4122214708 + green * 0.5363325363 + blue * 0.0514459929
	local m = red * 0.2119034982 + green * 0.6806995451 + blue * 0.1073969566
	local s = red * 0.0883024619 + green * 0.2817188376 + blue * 0.6299787005

	local lRoot = l ^ (1/3)
	local mRoot = m ^ (1/3)
	local sRoot = s ^ (1/3)

	return
		lRoot * 0.2104542553 + mRoot * 0.7936177850 - sRoot * 0.0040720468,
		lRoot * 1.9779984951 - mRoot * 2.4285922050 + sRoot * 0.4505937099,
		lRoot * 0.0259040371 + mRoot * 0.7827717662 - sRoot * 0.8086757660
end

-- Converts a colour in sRGB space to Oklab space.
function Oklab.fromSRGB(red: number, green: number, blue: number): (number, number, number)
	return Oklab.fromLinear(sRGB.toLinear(red, green, blue))
end

-- Converts a colour in Oklab space to linear RGB space.
-- The channels will be clamped by default unless specified otherwise.
function Oklab.toLinear(L: number, a: number, b: number, unclamped: boolean?): (number, number, number)
	local lRoot = L + a * 0.3963377774 + b * 0.2158037573
	local mRoot = L - a * 0.1055613458 - b * 0.0638541728
	local sRoot = L - a * 0.0894841775 - b * 1.2914855480

	local l = lRoot ^ 3
	local m = mRoot ^ 3
	local s = sRoot ^ 3

	local red = l * 4.0767416621 - m * 3.3077115913 + s * 0.2309699292
	local green = l * -1.2684380046 + m * 2.6097574011 - s * 0.3413193965
	local blue = l * -0.0041960863 - m * 0.7034186147 + s * 1.7076147010

	if not unclamped then
		red = math.clamp(red, 0, 1)
		green = math.clamp(green, 0, 1)
		blue = math.clamp(blue, 0, 1)
	end

	return red, green, blue
end

-- Converts a colour in Oklab space to sRGB space.
-- The channels will be clamped by default unless specified otherwise.
function Oklab.toSRGB(L: number, a: number, b: number, unclamped: boolean?): (number, number, number)
	local red, green, blue = Oklab.toLinear(L, a, b, unclamped)
	return sRGB.fromLinear(red, green, blue)
end

return Oklab
