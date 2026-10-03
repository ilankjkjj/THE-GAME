local Profile = {}
local MAX_VALUE = 1e12
local function number(value, default)
	if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return default
	end
	return math.clamp(math.floor(value), 0, MAX_VALUE)
end
function Profile.new(startingCoins)
	return {
		Version = 1, Coins = startingCoins, Points = 0, Presses = 0,
		Owned = { skin_classic = true }, Equipped = { Skin = "skin_classic" },
	}
end
function Profile.normalize(raw, catalog, startingCoins)
	local data = Profile.new(startingCoins)
	if type(raw) ~= "table" then
		return data
	end
	for _, key in ipairs({ "Coins", "Points", "Presses" }) do
		data[key] = number(raw[key], data[key])
	end
	if type(raw.Owned) == "table" then
		for id, owned in pairs(raw.Owned) do
			if owned == true and catalog.ById[id] then
				data.Owned[id] = true
			end
		end
	end
	if type(raw.Equipped) == "table" then
		for category, id in pairs(raw.Equipped) do
			local item = catalog.ById[id]
			if item and data.Owned[id] and item.Category == category then
				data.Equipped[category] = id
			end
		end
	end
	return data
end
function Profile.copy(data)
	return {
		Version = data.Version, Coins = data.Coins, Points = data.Points, Presses = data.Presses,
		Owned = table.clone(data.Owned), Equipped = table.clone(data.Equipped),
	}
end
return Profile
