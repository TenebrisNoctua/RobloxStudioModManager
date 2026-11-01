const signal = require("@Luwow/signal")
const task = require("@Luwow/task")

local Tasks = {}

--// Module Functions

--[[
	Runs each job on a thread of its own, at most limit at once,
	and yields until every one is done. Jobs that wait off the state, such as
	downloads, run at the same time. Returns each job's result, and the errors
	of the ones that failed, by index.
]]
function Tasks.all<T>(jobs: { () -> T }, limit: number?): ({ [number]: T }, { [number]: string })
	local results: { [number]: T } = {}
	local errors: { [number]: string } = {}
	local workers = math.min(limit or #jobs, #jobs)
	if workers == 0 then
		return results, errors
	end

	local nextJob = 1
	local running = workers
	local finished = signal.new()

	-- Each worker takes the next job until none is left
	local function work()
		while nextJob <= #jobs do
			local index = nextJob
			nextJob += 1
			local ok, result = pcall(jobs[index])
			if ok then
				results[index] = result
			else
				errors[index] = tostring(result)
			end
		end

		running -= 1
		if running == 0 then
			finished:Fire()
		end
	end

	for _ = 1, workers do
		task.spawn(work)
	end
	if running > 0 then
		finished:Wait()
	end
	return results, errors
end

return Tasks
