local PackageManager = require("../../../PackageManager")

local FoundationCloudAssets = PackageManager.getPackage("FoundationCloudAssets").Assets

return function(img: string)
	return FoundationCloudAssets[img] ~= nil
end
