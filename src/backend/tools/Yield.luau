const task = require("@Luwow/task")
const BUDGET = 0.01 -- How long work may run before it lets the other threads have a frame

local Yield = {}
local lastYield = os.clock()

--// Module Functions

--[[
	Yields for a frame once the budget since the
	last yield is used up, so the window keeps painting while the work goes on.
	Does nothing where the thread can't yield, such as while a module is
	being required.
]]
function Yield.ifNeeded()
	local now = os.clock()
	if now - lastYield < BUDGET then return end
	if coroutine.isyieldable() then task.wait() end
	lastYield = os.clock()
end

return Yield
