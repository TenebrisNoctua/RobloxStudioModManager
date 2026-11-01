--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Tween infos and easing for the Luwow runtime provider, which has no
	TweenService. A tween info has the same fields as Roblox's TweenInfo, with
	easing styles and directions given as strings:

		TweenInfo.new(0.25, "Quad", "Out")

	Easing styles: Linear, Sine, Quad, Cubic, Quart, Quint, Exponential,
	Circular, Back, Elastic and Bounce. Directions: In, Out and InOut.
]]

export type EasingStyle =
	"Linear" | "Sine" | "Quad" | "Cubic" | "Quart" | "Quint" |
	"Exponential" | "Circular" | "Back" | "Elastic" | "Bounce"

export type EasingDirection = "In" | "Out" | "InOut"

export type TweenInfo = {
	read Time: number,
	read EasingStyle: EasingStyle,
	read EasingDirection: EasingDirection,
	read RepeatCount: number,
	read Reverses: boolean,
	read DelayTime: number
}

local BACK = 1.70158
local ELASTIC = (2 * math.pi) / 3

local function bounceOut(t: number): number
	if t < 1 / 2.75 then
		return 7.5625 * t * t
	elseif t < 2 / 2.75 then
		t -= 1.5 / 2.75
		return 7.5625 * t * t + 0.75
	elseif t < 2.5 / 2.75 then
		t -= 2.25 / 2.75
		return 7.5625 * t * t + 0.9375
	else
		t -= 2.625 / 2.75
		return 7.5625 * t * t + 0.984375
	end
end

local easeIn: {[string]: (t: number) -> number} = {
	Linear = function(t)
		return t
	end,
	Sine = function(t)
		return 1 - math.cos(t * math.pi / 2)
	end,
	Quad = function(t)
		return t ^ 2
	end,
	Cubic = function(t)
		return t ^ 3
	end,
	Quart = function(t)
		return t ^ 4
	end,
	Quint = function(t)
		return t ^ 5
	end,
	Exponential = function(t)
		return if t == 0 then 0 else 2 ^ (10 * t - 10)
	end,
	Circular = function(t)
		return 1 - math.sqrt(1 - t * t)
	end,
	Back = function(t)
		return (BACK + 1) * t ^ 3 - BACK * t ^ 2
	end,
	Elastic = function(t)
		if t == 0 or t == 1 then
			return t
		end
		return -(2 ^ (10 * t - 10)) * math.sin((t * 10 - 10.75) * ELASTIC)
	end,
	Bounce = function(t)
		return 1 - bounceOut(1 - t)
	end
}

local directions = {
	In = true,
	Out = true,
	InOut = true
}

local TweenInfo = {}

--[[
	Creates a tween info. Every argument is optional, the defaults match
	Roblox's: one second, Quad, Out, no repeats, no reversing and no delay.
	A negative repeat count repeats forever.
]]
function TweenInfo.new(
	time: number?,
	easingStyle: EasingStyle?,
	easingDirection: EasingDirection?,
	repeatCount: number?,
	reverses: boolean?,
	delayTime: number?
): TweenInfo
	local style = easingStyle or "Quad"
	local direction = easingDirection or "Out"
	if easeIn[style] == nil then
		error(`'{style}' isn't an easing style`, 2)
	end
	if directions[direction] == nil then
		error(`'{direction}' isn't an easing direction`, 2)
	end

	return table.freeze({
		Time = time or 1,
		EasingStyle = style,
		EasingDirection = direction,
		RepeatCount = repeatCount or 0,
		Reverses = reverses or false,
		DelayTime = delayTime or 0
	})
end

--[[
	Returns the eased alpha for a tween's progress from 0 to 1, like Roblox's
	TweenService:GetValue.
]]
function TweenInfo.getEasedValue(
	alpha: number,
	easingStyle: EasingStyle,
	easingDirection: EasingDirection
): number
	local curve = easeIn[easingStyle] or easeIn.Linear
	alpha = math.clamp(alpha, 0, 1)

	if easingDirection == "In" then
		return curve(alpha)
	elseif easingDirection == "Out" then
		return 1 - curve(1 - alpha)
	elseif alpha < 0.5 then
		return curve(alpha * 2) / 2
	else
		return 1 - curve((1 - alpha) * 2) / 2
	end
end

return TweenInfo
