local Economy = {}
function Economy.multiplier(data, catalog)
	local best = 1
	for id in pairs(data.Owned) do
		local item = catalog.ById[id]
		if item and item.Multiplier then
			best = math.max(best, item.Multiplier)
		end
	end
	return best
end
function Economy.awardCoins(data, amount, catalog)
	local earned = math.floor(amount * Economy.multiplier(data, catalog))
	data.Coins += earned
	return earned
end
function Economy.press(data, cost, config, catalog)
	if data.Coins < cost then
		return false, "You need " .. cost .. " coins to press during the button tax."
	end
	data.Coins -= cost
	data.Presses += 1
	data.Points += config.PointsPerPress
	Economy.awardCoins(data, config.CoinsPerPress, catalog)
	return true
end
function Economy.purchase(data, id, catalog)
	local item = catalog.ById[id]
	if not item then
		return false, "That item does not exist."
	end
	if not data.Owned[id] then
		if data.Points < item.Price then
			return false, "You need " .. (item.Price - data.Points) .. " more Button Points."
		end
		data.Points -= item.Price
		data.Owned[id] = true
	end
	if item.Category ~= "Multiplier" then
		data.Equipped[item.Category] = id
	end
	return true, item.Name .. " is ready!"
end
function Economy.unequip(data, category, catalog)
	if not table.find(catalog.Categories, category) or category == "Multiplier" then
		return false, "That category cannot be unequipped."
	end
	data.Equipped[category] = category == "Skin" and "skin_classic" or nil
	return true, "Equipment cleared."
end
return Economy
