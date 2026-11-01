local GetImageSetData = require("./Generated/GetImageSetData")
local Flags = require("./Flags")
local isLuwow = require("./isLuwow")
local FixBlurryImages = Flags.FixBlurryImages

local scale = 1
if not isLuwow then
	local GuiService = game:GetService("GuiService")

	local CorePackages = script:FindFirstAncestor("CorePackages")
	local success, resolutionScale = pcall(GuiService.GetResolutionScale, GuiService)

	if success and (FixBlurryImages or CorePackages) then
		scale = resolutionScale
	end

	-- Both this and the resolution scale should probably be provided to Foundation via some
	-- prop or context, maybe even token, rather than us calling GuiService directly.
	if GuiService:IsTenFootInterface() then
		scale = 3
	end
end

local function getResolutionScale(): number
	local _, imageScale = GetImageSetData(scale)
	return imageScale
end

return getResolutionScale
