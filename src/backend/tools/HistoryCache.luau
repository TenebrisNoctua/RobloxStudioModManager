const Http = require("@Backend/tools/Http")
const HISTORY_URL = "https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/refs/heads/roblox/version-history.json"

-- How long a download is reused, in seconds
const LIFETIME = 5 * 60

local HistoryCache = {
	History = nil :: string?,
	LastUpdate = -math.huge
}

--// Module Functions

-- Studio's version history, as JSON of version ids to guids, downloaded again after five minutes
function HistoryCache.get(): string
	if not HistoryCache.History or os.clock() - HistoryCache.LastUpdate > LIFETIME then
		HistoryCache.History = Http.get(HISTORY_URL)
		HistoryCache.LastUpdate = os.clock()
	end
	return HistoryCache.History :: string
end

return HistoryCache
