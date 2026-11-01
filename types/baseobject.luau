-- This is the type system for the BaseObject API as it exists in C++ code. BaseObject is a C++ only
-- library without a Luau module, these types are for the libraries building on it.

--[=[
	The base of every Luwow object, whichever library made it. 
	Library types build on it with intersections.

	A destroyed object is no longer accessible: using any member other than Destroyed and Destroy
	raises an error.
]=]
export type BaseObject = {
	-- The object's class
	read ClassName: string,
	-- Any name, also what tostring gives.
	Name: string,
	-- Whether the object was destroyed.
	read Destroyed: boolean,

	--[=[
		Whether the object is of the class or inherits from it. Every object is a "BaseObject".
	]=]
	IsA: (self: BaseObject, className: string) -> boolean,

	--[=[
		Destroys the object, and whatever it owns. Destroying twice
		does nothing.
	]=]
	Destroy: (self: BaseObject) -> ()
}

return table.freeze({})
