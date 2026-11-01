local Types = require("./Types")
local assign = require("./assign")

--[=[
	Returns a new Map by merging all keys from the provided Map arguments in left-to-right order.

	The `None` symbol can be used to remove existing elements.

	@param ... Any number of tables to merge.
	@return A new Map containing the merged keys and values.
]=]
local function join(...: {}?): Types.Table
	return assign({}, ...)
end

return join
