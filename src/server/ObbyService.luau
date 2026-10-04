local Players = game:GetService("Players")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config)
local Obby = {}
Obby.__index = Obby
function Obby.new(world, data, remotes)
	local self = setmetatable({ World = world, Data = data, Remotes = remotes, Runs = {}, RewardAt = {}, Connections = {} }, Obby)
	for order, part in ipairs(world.ObbyCheckpoints) do
		table.insert(self.Connections, part.Touched:Connect(function(hit)
			local character = hit:FindFirstAncestorOfClass("Model")
			local player = character and Players:GetPlayerFromCharacter(character)
			if player then self:touch(player, order) end
		end))
	end
	table.insert(self.Connections, world.ObbyFinish.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if player then self:touch(player, #world.ObbyCheckpoints + 1) end
	end))
	return self
end
function Obby:reset(player)
	self.Runs[player] = nil
	player:SetAttribute("ObbyCheckpoint", 0)
end
function Obby:removed(player) self:reset(player); self.RewardAt[player] = nil end
function Obby:touch(player, order)
	if type(order) ~= "number" or order ~= order or order % 1 ~= 0 or order < 1 or order > #self.World.ObbyCheckpoints + 1 then return false end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if player.Parent ~= Players or player:GetAttribute("InRound") == true or not self.Data.get(player) or not root or not humanoid or humanoid.Health <= 0 then return false end
	local count, current = #self.World.ObbyCheckpoints, workspace:GetServerTimeNow()
	local part = order == count + 1 and self.World.ObbyFinish or self.World.ObbyCheckpoints[order]
	if not part or (root.Position - part.Position).Magnitude > part.Size.Magnitude / 2 + 4 then return false end
	if order == 1 then
		if current < (self.RewardAt[player] or 0) then
			if not self.Runs[player] then self.Remotes.Toast:FireClient(player, "Obby reward ready in " .. math.ceil(self.RewardAt[player] - current) .. "s. Practice while you wait.", "info") end
		end
		if self.Runs[player] and self.Runs[player].Character == character and self.Runs[player].Checkpoint == 1 then return false end
		self.Runs[player] = { Character = character, Checkpoint = 1, StartedAt = current, LastAt = current }
	elseif not self.Runs[player] or self.Runs[player].Character ~= character or order ~= self.Runs[player].Checkpoint + 1 or current - self.Runs[player].LastAt < 0.2 then return false
	else self.Runs[player].Checkpoint = order; self.Runs[player].LastAt = current end
	player:SetAttribute("ObbyCheckpoint", order)
	if order == count + 1 then
		local eligible = current >= (self.RewardAt[player] or 0) and current - self.Runs[player].StartedAt >= Config.ObbyMinimumSeconds
		self:reset(player)
		if not eligible then self.Remotes.Toast:FireClient(player, "Course complete! The reward is still cooling down.", "info"); return false end
		self.RewardAt[player] = current + Config.ObbyCooldown
		self.Data.award(player, Config.ObbyTokens)
		self.Remotes.Cue:FireClient(player, { Kind = "obby", Local = true, Strength = 1 })
		self.Remotes.Toast:FireClient(player, "OBBY COMPLETE! +" .. Config.ObbyTokens .. " tokens. Reward returns in 60s.", "good")
		return true
	end
	self.Remotes.Cue:FireClient(player, { Kind = "checkpoint", Local = true, Strength = 0.65 })
	return true
end
return Obby
