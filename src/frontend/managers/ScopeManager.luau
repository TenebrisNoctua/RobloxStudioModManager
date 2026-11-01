const Packages = require("@Frontend/Packages")
const Types = require("@Frontend/Types")

const Fusion = Packages.Fusion

type Scope = Types.Scope

local Manager = {
	scopeTable = {} :: { Scope },
}

--// Module Functions

function Manager.createScope(): Scope
	local newScope = Fusion.scoped(Fusion)
	table.insert(Manager.scopeTable, newScope)

	return newScope
end

-- Cleans a scope made by createScope, returns whether it was one
function Manager.cleanScope(scope: Scope): boolean
	local index = table.find(Manager.scopeTable, scope)
	if not index then
		return false
	end

	table.remove(Manager.scopeTable, index)
	Fusion.doCleanup(scope)
	return true
end

-- Cleans every scope, newest first, when the program ends
function Manager.cleanAll()
	for i = #Manager.scopeTable, 1, -1 do
		local scope = Manager.scopeTable[i]
		Manager.scopeTable[i] = nil
		pcall(Fusion.doCleanup, scope)
	end
end

return Manager
