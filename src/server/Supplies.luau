local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Catalog = require(Shared.Catalog)
local Economy = require(Shared.Economy)
local Supplies = {}
Supplies.__index = Supplies
function Supplies.new(data, remotes)
	return setmetatable({ Data = data, Remotes = remotes, Sessions = {} }, Supplies)
end
function Supplies:clear(player)
	local session = self.Sessions[player]
	if not session then return end
	self.Sessions[player] = nil
	for _, connection in ipairs(session.Connections) do connection:Disconnect() end
	for _, object in ipairs(session.Objects) do object:Destroy() end
	local humanoid = session.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		for property, change in pairs(session.Buffs) do
			if humanoid[property] == change.Value then humanoid[property] = change.Previous end
		end
	end
end
function Supplies:reapply(player)
	local session = self.Sessions[player]
	local humanoid = session and session.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	for property, change in pairs(session.Buffs) do
		if workspace:GetServerTimeNow() >= change.Expires then
			if humanoid[property] == change.Value then humanoid[property] = change.Previous end
			session.Buffs[property] = nil
		elseif humanoid[property] ~= change.Value and humanoid[property] > 0 then
			change.Previous = humanoid[property]
			change.Value = change.Previous + change.Amount
			humanoid[property] = change.Value
		end
	end
end
function Supplies:update()
	for player, session in pairs(self.Sessions) do
		if player.Character ~= session.Character or player:GetAttribute("InRound") ~= true then self:clear(player); continue end
		local humanoid = session.Character:FindFirstChildOfClass("Humanoid")
		if not humanoid then continue end
		for property, change in pairs(session.Buffs) do
			if workspace:GetServerTimeNow() >= change.Expires and humanoid[property] == change.Value then
				humanoid[property] = change.Previous
				session.Buffs[property] = nil
			end
		end
	end
end
function Supplies:grant(player, roundId)
	self:clear(player)
	local data, character = self.Data.get(player), player.Character
	if not data or not character then return end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then backpack = Instance.new("Backpack"); backpack.Parent = player end
	local session = { Character = character, RoundId = roundId, Connections = {}, Objects = {}, Buffs = {} }
	self.Sessions[player] = session
	local function active()
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		return self.Sessions[player] == session and player.Character == character and player:GetAttribute("InRound") == true and humanoid and humanoid.Health > 0
	end
	for _, item in ipairs(Catalog.Items) do
		if (data.Inventory[item.Id] or 0) <= 0 then continue end
		local tool = Instance.new("Tool")
		tool.Name, tool.ToolTip, tool.CanBeDropped = item.Name, item.Description, false
		tool:SetAttribute("SupplyId", item.Id)
		local handle = Instance.new("Part")
		handle.Name, handle.Size, handle.CanCollide, handle.CanTouch, handle.Massless = "Handle", Vector3.new(0.8, 1.1, 0.6), false, false, true
		handle.Color, handle.Material = Color3.fromRGB(unpack(item.Color)), Enum.Material.Plastic
		handle.Parent = tool
		tool.Parent = backpack
		table.insert(session.Objects, tool)
		local used = false
		table.insert(session.Connections, tool.Activated:Connect(function()
			if used or not active() or tool.Parent ~= character then return end
			local profile = self.Data.get(player)
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if item.Id == "medkit" and humanoid.Health >= humanoid.MaxHealth then
				self.Remotes.Toast:FireClient(player, "You're already at full health. Your medkit stays unused.", "info"); return
			end
			if not profile or not Economy.consume(profile, item.Id, Catalog) then return end
			used = true
			if item.Id == "medkit" then humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + 35)
			elseif item.Id == "shield" then
				local shield = Instance.new("ForceField"); shield.Name = "SupplyShield"; shield.Parent = character
				table.insert(session.Objects, shield)
				task.delay(5, function() if shield.Parent then shield:Destroy() end end)
			else
				local property = item.Id == "soda" and "WalkSpeed" or "JumpPower"
				local amount = item.Id == "soda" and 6 or 15
				local change = { Previous = humanoid[property], Value = humanoid[property] + amount, Amount = amount, Expires = workspace:GetServerTimeNow() + 8 }
				session.Buffs[property] = change; humanoid[property] = change.Value
				task.delay(8, function()
					if self.Sessions[player] == session and humanoid.Parent and humanoid[property] == change.Value then
						humanoid[property] = change.Previous
						if session.Buffs[property] == change then session.Buffs[property] = nil end
					end
				end)
			end
			self.Data.push(player)
			self.Remotes.Cue:FireClient(player, { Kind = "supply", Strength = 0.8, RoundId = roundId })
			self.Remotes.Toast:FireClient(player, item.Name .. " used!", "good")
			tool:Destroy()
		end))
	end
end
return Supplies
