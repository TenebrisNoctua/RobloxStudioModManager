-- This is the type system for the UDim2 API as it exists in C++ code.

local udim = require("@Luwow/udim")

export type UDim = udim.UDim

--[=[
	A UDim for each axis, like Roblox's UDim2, used for positions and sizes, printed as
	"{1, -20}, {0, 40}". UDim2s are immutable and support +, - between them, and * and / with numbers.
	The css library turns CSS sizes such as "calc(100% - 20px) 40px" into UDim2s.
]=]
export type UDim2 = typeof(setmetatable(
	{} :: {
		read X: UDim,
		read Y: UDim,
		-- The same as X and Y
		read Width: UDim,
		read Height: UDim,

		--[=[
			The value between this one (alpha 0) and goal (alpha 1).
		]=]
		Lerp: (self: UDim2, goal: UDim2, alpha: number) -> UDim2,

		--[=[
			The pixels within a parent of the given size.
		]=]
		Resolve: (self: UDim2, size: vector) -> vector,
	},
	{} :: {
		__add: (UDim2, UDim2) -> UDim2,
		__sub: (UDim2, UDim2) -> UDim2,
		__unm: (UDim2) -> UDim2,
		__mul: (UDim2, number) -> UDim2,
		__div: (UDim2, number) -> UDim2,
	}
))

--[=[
	What properties taking a UDim2 accept: a UDim2, or a vector of pixels.
]=]
export type UDim2Like = UDim2 | vector

export type Library = {
	--[=[
		Creates a UDim2 from each axis' scale and offset, all defaulting to 0, or from two UDims.
	]=]
	new: ((xScale: number?, xOffset: number?, yScale: number?, yOffset: number?) -> UDim2) & ((x: UDim, y: UDim) -> UDim2),

	--[=[
		Fractions of the parent's size, fromScale(1, 1) fills it.
	]=]
	fromScale: (x: number?, y: number?) -> UDim2,

	--[=[
		Pixels, from two numbers or a vector.
	]=]
	fromOffset: ((x: number?, y: number?) -> UDim2) & ((pixels: vector) -> UDim2),

}

return table.freeze({} :: Library)
