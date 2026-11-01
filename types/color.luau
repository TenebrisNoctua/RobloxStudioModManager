-- This is the type system for the Color API as it exists in C++ code.

--[=[
	A color with red, green, blue and alpha components from 0 to 1. 
	Alpha 1 is fully opaque, and 0 fully transparent. Colors are immutable, two colors
	with the same components are equal.
]=]
export type Color = {
	read R: number,
	read G: number,
	read B: number,
	read A: number, -- 1 unless the color was made with an alpha.

	--[=[
		The color between this one (alpha 0) and goal (alpha 1), the alpha components included.
	]=]
	Lerp: (self: Color, goal: Color, alpha: number) -> Color,

	--[=[
		Returns the hue, saturation and value, each from 0 to 1.
	]=]
	ToHSV: (self: Color) -> (number, number, number),

	--[=[
		Returns the color as lowercase hex digits: six such as "ff8000", or eight such as "ff800080"
		when it isn't opaque.
	]=]
	ToHex: (self: Color) -> string
}

export type Library = {
	--[=[
		Creates a color from components between 0 and 1, each defaulting to 0. The alpha is fully
		opaque (1) when it's left out.
	]=]
	new: (r: number?, g: number?, b: number?, a: number?) -> Color,

	--[=[
		Creates a color from components between 0 and 255, and an alpha between 0 and 1, fully opaque
		when it's left out.
	]=]
	fromRGB: (r: number?, g: number?, b: number?, a: number?) -> Color,

	--[=[
		Creates a color from a hue, saturation and value between 0 and 1, and an alpha between 0 and 1,
		fully opaque when it's left out.
	]=]
	fromHSV: (h: number, s: number, v: number, a: number?) -> Color,

	--[=[
		Creates a color from a hex string such as "#ff8000", "ff8000" or "f80", with two more digits
		for the alpha ("#ff800080") or one in the short form ("f808").
	]=]
	fromHex: (hex: string) -> Color,

	--[=[
		The same as color:ToHSV().
	]=]
	toHSV: (color: Color) -> (number, number, number)
}

return table.freeze({} :: Library)
