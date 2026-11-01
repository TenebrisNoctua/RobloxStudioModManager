local Datatypes = require("../../Utility/Luwow/Datatypes")
local Enum, Font = Datatypes.Enum, Datatypes.Font

return {
	[Font.fromEnum(Enum.Font.BuilderSans).Family] = 1.26,
}
