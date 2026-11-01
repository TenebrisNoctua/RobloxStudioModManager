local preloadAsset = require("@self/preloadAsset")
local assets = require("@self/Generated/ConsolidatedAssets")

return {
	Assets = assets,
	preloadAsset = preloadAsset,
}
