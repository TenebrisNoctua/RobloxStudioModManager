local Datatypes = require("../../../Utility/Luwow/Datatypes")
local Rect = Datatypes.Rect

local PackageManager = require("../../../PackageManager")

local FoundationImages = PackageManager.getPackage("FoundationImages")
local Types = require("../../../Utility/Types")

type Slice = Types.Slice

local function getScaledSlice(sliceCenter: Rect?, sliceScale: number?): Slice
	local scale = FoundationImages.getResolutionScale()

	if sliceCenter then
		local min = sliceCenter.Min * scale
		local max = sliceCenter.Max * scale
		sliceCenter = Rect.new(min, max)
		sliceScale = (sliceScale or 1) / scale
	end

	return {
		center = sliceCenter,
		scale = sliceScale,
	}
end

return getScaledSlice
