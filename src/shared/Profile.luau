local Profile = {}
local MAX_VALUE = 1e12
local function number(value, default, maximum)
	if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return default
	end
	return math.clamp(math.floor(value), 0, maximum or MAX_VALUE)
end
function Profile.new(startingTokens)
	return { Version = 3, Tokens = startingTokens, Presses = 0, Wins = 0, Rounds = 0, KOs = 0, Inventory = {} }
end
function Profile.normalize(raw, catalog, startingTokens)
	local data = Profile.new(startingTokens)
	if type(raw) ~= "table" then
		return data
	end
	for _, key in ipairs({ "Presses", "Wins", "Rounds", "KOs" }) do data[key] = number(raw[key], 0) end
	if raw.Version == 3 then data.Tokens = number(raw.Tokens, startingTokens)
	else
		-- Preserve earned balances once while retiring cosmetic ownership and boosts.
		data.Tokens = math.min(MAX_VALUE, number(raw.Coins, startingTokens) + number(raw.Points, 0))
	end
	if raw.Version == 3 and type(raw.Inventory) == "table" then
		for id, count in pairs(raw.Inventory) do
			local item = catalog.ById[id]
			if item then local stock = number(count, 0, item.MaxStock); if stock > 0 then data.Inventory[id] = stock end end
		end
	end
	return data
end
function Profile.copy(data)
	return { Version = 3, Tokens = data.Tokens, Presses = data.Presses, Wins = data.Wins, Rounds = data.Rounds, KOs = data.KOs, Inventory = table.clone(data.Inventory) }
end
return Profile
