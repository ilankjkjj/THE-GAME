local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Events = {}
local random = Random.new()
local function living(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and humanoid.Health > 0 then return character, humanoid, root end
end
local function folder(world, name)
	local container = Instance.new("Folder")
	container.Name = name
	container.Parent = world.Effects
	return container
end
function Events.coins(context, amount, lifetime)
	local container = folder(context.World, "CoinShower")
	for _ = 1, amount do
		local coin = context.World.part(container, "Coin", Vector3.new(0.4, 1.8, 1.8), Vector3.new(random:NextNumber(-40, 40), 2, random:NextNumber(-40, 40)), Color3.fromRGB(255, 199, 65), Enum.Material.Neon, Enum.PartType.Cylinder)
		coin.CanCollide = false
		coin.Orientation = Vector3.new(0, 0, 90)
		local collected = false
		coin.Touched:Connect(function(hit)
			if collected then return end
			local character = hit:FindFirstAncestorOfClass("Model")
			local player = character and Players:GetPlayerFromCharacter(character)
			local root
			if player then
				local _, _, found = living(player)
				root = found
			end
			-- Check collection on the server, including distance, before paying.
			if not player or not root or not context.Data.get(player) or (root.Position - coin.Position).Magnitude > 9 then return end
			collected = true
			local earned = context.Data.award(player, 5, 0)
			context.Remotes.Toast:FireClient(player, "+" .. earned .. " coins", "good")
			coin:Destroy()
		end)
		TweenService:Create(coin, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = coin.Position + Vector3.new(0, 0.8, 0) }):Play()
	end
	Debris:AddItem(container, lifetime)
	return function() container:Destroy() end
end
function Events.chicken(context, scale, position, parent)
	local world = context.World
	local model = Instance.new("Model")
	model.Name = "ExtremelyLargeChicken"
	model.Parent = parent or world.Effects
	local white = Color3.fromRGB(255, 239, 192)
	local gold = Color3.fromRGB(255, 163, 43)
	local function piece(name, size, offset, color, shape)
		local part = world.part(model, name, size * scale, position + offset * scale, color, nil, shape)
		part.CanCollide = false
		return part
	end
	piece("Body", Vector3.new(6, 7, 6), Vector3.new(0, 5, 0), white, Enum.PartType.Ball)
	piece("Head", Vector3.new(4, 4, 4), Vector3.new(0, 9, -1), white, Enum.PartType.Ball)
	piece("Beak", Vector3.new(2, 1, 2), Vector3.new(0, 8.8, -3.2), gold)
	piece("Comb", Vector3.new(1, 2, 3), Vector3.new(0, 11, -1), Color3.fromRGB(255, 68, 83))
	for _, sign in ipairs({ -1, 1 }) do
		piece("Eye", Vector3.new(0.5, 0.7, 0.5), Vector3.new(sign * 1.6, 9.4, -2.2), Color3.fromRGB(12, 18, 26), Enum.PartType.Ball)
		piece("Wing", Vector3.new(1.5, 4, 4), Vector3.new(sign * 3, 5.5, 0), white, Enum.PartType.Ball)
		piece("Leg", Vector3.new(0.6, 2, 0.6), Vector3.new(sign * 1.5, 1.5, 0), gold)
		piece("Foot", Vector3.new(2, 0.4, 3), Vector3.new(sign * 1.5, 0.5, -0.7), gold)
	end
	return model
end
function Events.special(context)
	local theme = ({ "Gold", "Cosmic", "Candy" })[random:NextInteger(1, 3)]
	local gravity = workspace.Gravity
	context.World.theme(theme)
	workspace.Gravity = 90
	context.Data.awardAll(Config.SpecialCoins, Config.SpecialPoints)
	local cleanupCoins = Events.coins(context, 60, Config.SpecialDuration)
	local container = folder(context.World, "SpecialDecor")
	for i = 1, 12 do
		local angle = i * math.pi / 6
		local orb = context.World.part(container, "PartyOrb", Vector3.new(3, 3, 3), Vector3.new(math.cos(angle) * 32, 10 + i % 3 * 3, math.sin(angle) * 32), Color3.fromHSV(i / 12, 0.65, 1), Enum.Material.Neon, Enum.PartType.Ball)
		orb.CanCollide = false
		TweenService:Create(orb, TweenInfo.new(1.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = orb.Position + Vector3.new(0, 8, 0) }):Play()
	end
	context.Remotes.Toast:FireAllClients("SPECIAL! +100 base coins, +25 Button Points. Low gravity + coin shower!", "special")
	return function()
		cleanupCoins()
		container:Destroy()
		workspace.Gravity = gravity
		context.World.theme("Normal")
	end
end
local definitions = {
	{ Id = "payday", Name = "PAYDAY", Description = "Everyone gets 10 coins. You're welcome.", Duration = 3, Run = function(c)
		c.Data.awardAll(10, 0)
	end },
	{ Id = "teleport", Name = "WHERE DID EVERYONE GO?", Description = "Random teleport. Same room, new problems.", Duration = 4, Run = function()
		for _, player in ipairs(Players:GetPlayers()) do
			local character, _, root = living(player)
			if character then
				character:PivotTo(CFrame.new(random:NextNumber(-38, 38), 5, random:NextNumber(-38, 38)))
				root.AssemblyLinearVelocity = Vector3.zero
			end
		end
	end },
	{ Id = "chicken", Name = "ABSOLUTELY MASSIVE CHICKEN", Description = "It has questions about your life choices.", Duration = 10, Run = function(c)
		local chicken = Events.chicken(c, 2.1, Vector3.new(0, 0, -26))
		local pivot = chicken:GetPivot()
		task.spawn(function()
			local start = os.clock()
			while chicken.Parent do
				chicken:PivotTo(pivot * CFrame.new(0, math.abs(math.sin((os.clock() - start) * 3)) * 2, 0))
				task.wait(0.06)
			end
		end)
		return function() chicken:Destroy() end
	end },
	{ Id = "rain", Name = "INDOOR WEATHER", Description = "The forecast was not supposed to include this.", Duration = 10, Run = function(c)
		local cloud = c.World.part(c.World.Effects, "RainCloud", Vector3.new(96, 1, 96), Vector3.new(0, 28, 0), Color3.new(0, 0, 0))
		cloud.CanCollide = false
		cloud.Transparency = 1
		local rain = Instance.new("ParticleEmitter")
		rain.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		rain.Color = ColorSequence.new(Color3.fromRGB(116, 194, 255))
		rain.EmissionDirection = Enum.NormalId.Bottom
		rain.Rate = 200
		rain.Speed = NumberRange.new(35, 45)
		rain.Lifetime = NumberRange.new(0.7, 0.9)
		rain.Size = NumberSequence.new(0.2)
		rain.Acceleration = Vector3.new(0, -50, 0)
		rain.Parent = cloud
		return function() cloud:Destroy() end
	end },
	{ Id = "survivor", Name = "LAST ONE STANDING", Description = "Only the presser survives. Everyone else respawns.", Duration = 5, Run = function(c, presser)
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= presser then
				local _, humanoid = living(player)
				if humanoid then humanoid.Health = 0 end
			end
		end
		c.Data.award(presser, 15, 0)
	end },
	{ Id = "launch", Name = "UNSCHEDULED SPACE PROGRAM", Description = "The presser has left the conversation.", Duration = 5, Run = function(_, presser)
		local _, _, root = living(presser)
		if root then root.AssemblyLinearVelocity = Vector3.new(0, 135, 0) end
	end },
	{ Id = "king", Name = "ALL HAIL THE BUTTON KING", Description = "The presser wears the crown for 30 seconds.", Duration = 3, Run = function(c, presser)
		local expires = workspace:GetServerTimeNow() + Config.KingDuration
		presser:SetAttribute("KingUntil", expires)
		c.Data.award(presser, 20, 5)
		task.delay(Config.KingDuration, function()
			if presser.Parent and presser:GetAttribute("KingUntil") == expires then presser:SetAttribute("KingUntil", nil) end
		end)
	end },
	{ Id = "coins", Name = "FINDERS KEEPERS", Description = "Run! Collect the coins before they disappear.", Duration = 12, Run = function(c)
		return Events.coins(c, 35, 12)
	end },
	{ Id = "countdown", Name = "TEN SECONDS. NO EXPLANATION.", Description = "Stay together. Or don't. We aren't experts.", Duration = 11, Run = function(c)
		for seconds = 10, 1, -1 do
			c.Remotes.Countdown:FireAllClients(seconds)
			task.wait(1)
		end
		c.Remotes.Countdown:FireAllClients(0)
		c.Data.awardAll(25, 3)
		for _, player in ipairs(Players:GetPlayers()) do
			local _, _, root = living(player)
			if root then root.AssemblyLinearVelocity = Vector3.new(0, 70, 0) end
		end
		c.Remotes.Toast:FireAllClients("SURPRISE! +25 base coins, +3 points, and a little airtime.", "good")
	end },
	{ Id = "tax", Name = "THE BUTTON HAS A BUSINESS DEGREE", Description = "Presses cost 5 coins for 45 seconds. Then they're free again.", Duration = 3, Run = function(c)
		c.State.TaxUntil = workspace:GetServerTimeNow() + Config.TaxDuration
	end },
	{ Id = "gift", Name = "A LITTLE FAVORITISM", Description = "One random player gets 50 coins and 10 points.", Duration = 4, Run = function(c)
		local eligible = {}
		for _, player in ipairs(Players:GetPlayers()) do
			if c.Data.get(player) then table.insert(eligible, player) end
		end
		if #eligible > 0 then
			local winner = eligible[random:NextInteger(1, #eligible)]
			c.Data.award(winner, 50, 10)
			c.Remotes.Toast:FireAllClients(winner.DisplayName .. " won the random gift!", "good")
		end
	end },
	{ Id = "remodel", Name = "EXTREME ROOM MAKEOVER", Description = "Same bad decisions. Completely different atmosphere.", Duration = 12, Run = function(c)
		c.World.theme(({ "Cosmic", "Candy", "Gold" })[random:NextInteger(1, 3)])
		local container = folder(c.World, "NewFurniture")
		for _, x in ipairs({ -22, 22 }) do
			for _, z in ipairs({ -18, 18 }) do
				c.World.part(container, "ClimbingBlock", Vector3.new(8, 6, 8), Vector3.new(x, 3, z), Color3.fromRGB(178, 112, 255), Enum.Material.Neon)
			end
		end
		return function() container:Destroy(); c.World.theme("Normal") end
	end },
	{ Id = "nothing", Name = "ABSOLUTELY NOTHING", Description = "You still earned a point. The button is judging you.", Duration = 2.5, Run = function() end },
}
Events.Definitions = definitions
function Events.choose()
	return definitions[random:NextInteger(1, #definitions)]
end
return Events
