const ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local Base64 = {}

--// Local Functions

-- Each base64 character's value
local function buildValues(): { [number]: number }
	local values = {}
	for index = 1, #ALPHABET do
		values[string.byte(ALPHABET, index)] = index - 1
	end
	return values
end

local VALUES = buildValues()

--// Module Functions

-- Decodes base64 text. Whitespace and padding are skipped.
function Base64.decode(text: string): string
	local output = {}
	local bits, bitCount = 0, 0

	for index = 1, #text do
		local value = VALUES[string.byte(text, index)]
		if value then
			bits = bit32.bor(bit32.lshift(bits, 6), value)
			bitCount += 6
			if bitCount >= 8 then
				bitCount -= 8
				table.insert(output, string.char(bit32.band(bit32.rshift(bits, bitCount), 0xFF)))
			end
		end
	end

	return table.concat(output)
end

return Base64
