local isLuwow = require("../../../Utility/isLuwow")

local function isImageFile(image: string): boolean
	return isLuwow and image:match("%.%a%a%a?%a?$") ~= nil
end

local function isFoundationImage(image: string?)
	return image ~= nil and image ~= "" and image:match("^%w+://.*$") == nil and not isImageFile(image)
end

return isFoundationImage
