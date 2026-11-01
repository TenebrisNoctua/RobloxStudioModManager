local Assets = require("./Generated/ConsolidatedAssets")
local isLuwow = require("./isLuwow")
local ContentProvider = if isLuwow then nil :: any else game:GetService("ContentProvider")

local function preloadAsset(assetKey: string)
	if isLuwow then
		return
	end

	-- create image label instance
	local assetImage = Instance.new("ImageLabel")
	assetImage.Image = Assets[assetKey].assetId

	-- preload asset
	task.spawn(function()
		ContentProvider:PreloadAsync({ assetImage })
		assetImage:Destroy()
	end)
end

return preloadAsset
