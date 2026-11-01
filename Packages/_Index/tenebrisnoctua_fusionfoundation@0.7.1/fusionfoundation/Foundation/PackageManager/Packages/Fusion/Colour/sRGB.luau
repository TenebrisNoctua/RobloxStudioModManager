--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
    Provides transformation functions for converting linear RGB values
    into sRGB values. Colours are passed as their red, green and blue
    channels from 0 to 1, so these work with any runtime's colour type.

    RGB color channel transformations are outlined here:
    https://bottosson.github.io/posts/colorwrong/#what-can-we-do%3F
]]

local sRGB = {}

-- Equivalent to f_inv. Takes a linear sRGB channel and returns
-- the sRGB channel
local function transform(channel: number): number
    if channel >= 0.04045 then
        return ((channel + 0.055)/(1 + 0.055))^2.4
    else
        return channel / 12.92
    end
end

-- Equivalent to f. Takes an sRGB channel and returns
-- the linear sRGB channel
local function inverse(channel: number): number
    if channel >= 0.0031308 then
        return (1.055) * channel^(1.0/2.4) - 0.055
    else
        return 12.92 * channel
    end
end

-- Uses a tranformation to convert linear RGB into sRGB.
function sRGB.fromLinear(red: number, green: number, blue: number): (number, number, number)
    return transform(red), transform(green), transform(blue)
end

-- Converts an sRGB into linear RGB using a
-- (The inverse of sRGB.fromLinear).
function sRGB.toLinear(red: number, green: number, blue: number): (number, number, number)
    return inverse(red), inverse(green), inverse(blue)
end

return sRGB
