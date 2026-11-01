local description = _RUNTIME :: any

return typeof(description) == "table"
	and typeof(description.name) == "string"
	and string.lower(description.name) == "luwow"
