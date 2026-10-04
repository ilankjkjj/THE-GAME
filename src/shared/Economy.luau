local Economy = {}
function Economy.award(data, amount)
	if type(amount) ~= "number" or amount ~= amount or math.abs(amount) == math.huge or amount <= 0 then return 0 end
	local earned = math.min(math.floor(amount), math.max(0, 1e12 - data.Tokens))
	data.Tokens += earned
	return earned
end
function Economy.press(data)
	data.Presses = math.min(1e12, data.Presses + 1)
	return true
end
function Economy.purchase(data, id, catalog)
	local item = catalog.ById[id]
	if not item then return false, "That supply does not exist." end
	local stock = data.Inventory[id] or 0
	if stock >= item.MaxStock then return false, "You already have " .. item.MaxStock .. " of this supply." end
	if data.Tokens < item.Price then return false, "You need " .. (item.Price - data.Tokens) .. " more tokens." end
	data.Tokens -= item.Price
	data.Inventory[id] = stock + 1
	return true, item.Name .. " bought! Find it in your backpack next round."
end
function Economy.consume(data, id, catalog)
	if not catalog.ById[id] or (data.Inventory[id] or 0) < 1 then return false end
	data.Inventory[id] -= 1
	if data.Inventory[id] == 0 then data.Inventory[id] = nil end
	return true
end
return table.freeze(Economy)
