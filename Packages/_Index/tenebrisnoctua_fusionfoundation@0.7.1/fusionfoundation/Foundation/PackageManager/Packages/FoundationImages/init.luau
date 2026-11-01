local ImagesTypes = require("@self/ImagesTypes")
export type ImageSetImage = ImagesTypes.ImageSetImage
export type Images = ImagesTypes.Images

return {
	getResolutionScale = require("@self/getResolutionScale"),
	Images = require("@self/Images"),
}
