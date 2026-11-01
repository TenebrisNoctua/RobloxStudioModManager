const net = require("@Luwow/net")

local Http = {}

--// Module Functions

--[[
	Downloads a URL's body, it raises if there's no response, or the status isn't a success.
]]
function Http.get(url: string, headers: { [string]: string }?): string
	local response = net.request({
		url = url,
		method = "GET",
		headers = headers,
		timeout = 30
	})

	if not response.ok then
		error(`{response.status} {response.statusMessage} from {url}`, 0)
	end
	return response.body
end

-- A HEAD request's status, 0 when there's no response
function Http.head(url: string, headers: { [string]: string }?): number
	local ok, response = pcall(net.request, {
		url = url,
		method = "HEAD",
		headers = headers,
		timeout = 30
	})
	return if ok then response.status else 0
end

-- The size a download will have, from a HEAD request's Content-Length, nil when it isn't told
function Http.contentLength(url: string, headers: { [string]: string }?): number?
	local ok, response = pcall(net.request, {
		url = url,
		method = "HEAD",
		headers = headers,
		timeout = 30
	})
	if not ok or not response.ok then return nil end
	return tonumber(response.headers["content-length"])
end

--[[
	The body is written as it arrives, so the file's size shows the progress. 
	Raises like get. Returns the body's length.
]]
function Http.download(url: string, path: string, headers: { [string]: string }?): number
	local response = net.request({
		url = url,
		method = "GET",
		headers = headers,
		timeout = 60,
		saveTo = path
	})

	if not response.ok then
		error(`{response.status} {response.statusMessage} from {url}`, 0)
	end
	return response.bodyLength
end

return Http
