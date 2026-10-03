-- Events own their visuals, jobs, roles and physics. The round controller
-- always calls cleanup on expiry or round end. Only alive participants qualify.
local Events = {}
local random = Random.new()
local RED = Color3.fromRGB(255, 86, 92)
local GOLD = Color3.fromRGB(255, 210, 79)
local BLUE = Color3.fromRGB(82, 183, 255)
local GREEN = Color3.fromRGB(105, 240, 157)
local PURPLE = Color3.fromRGB(185, 117, 255)
local TOP = 30

local function flatDistance(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end
local function shuffled(values)
	local result = table.clone(values)
	for index = #result, 2, -1 do
		local other = random:NextInteger(1, index)
		result[index], result[other] = result[other], result[index]
	end
	return result
end
local function toast(c, message, style)
	if c.Remotes and c.Remotes.Toast then c.Remotes.Toast:FireAllClients(message, style or "event") end
end

local function newScope(c, name)
	local s = { Context = c, Live = true, Jobs = {}, Restores = {}, Saved = {}, Roles = {}, HitTimes = {}, Hints = {}, Resources = {} }
	s.Container = Instance.new("Folder")
	s.Container.Name = name
	s.Container.Parent = c.World.Effects
	function s:active() return self.Live and (not c.Active or c.Active()) end
	function s:players() return c.Players() end
	function s:character(player)
		if not player or not self:active() or not c.IsAlive(player) then return end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and root and humanoid.Health > 0 then return character, humanoid, root end
	end
	function s:part(name_, size, position, color, material, shape, collidable)
		local part = c.World.part(self.Container, name_, size, position, color, material, shape)
		part.CanCollide = collidable == true
		part.CanTouch = false
		return part
	end
	function s:save(instance, properties)
		self.Saved[instance] = self.Saved[instance] or {}
		local saved = self.Saved[instance]
		for property, value in pairs(properties) do
			if saved[property] == nil then saved[property] = { instance[property] } end
			instance[property] = value
		end
	end
	function s:restore(callback) table.insert(self.Restores, callback) end
	function s:hint(player, text)
		if not player.Parent then return end
		player:SetAttribute("EventHint", text)
		self.Hints[player] = text
	end
	function s:spawn(callback)
		local job = task.spawn(function() if self:active() then callback() end end)
		if job then table.insert(self.Jobs, job) end
	end
	function s:wait(seconds)
		local untilTime = os.clock() + seconds
		while self:active() and os.clock() < untilTime do task.wait(math.max(0.01, math.min(0.15, untilTime - os.clock()))) end
		return self:active()
	end
	function s:loop(callback, interval)
		self:spawn(function()
			local start = os.clock()
			while self:active() do
				callback(os.clock() - start)
				if not self:wait(interval or 0.15) then break end
			end
		end)
	end
	function s:resource(player, character, release)
		local resource = { Player = player, Character = character, Released = false }
		function resource.close()
			if resource.Released then return end
			resource.Released = true
			release()
		end
		table.insert(self.Resources, resource)
		self:restore(resource.close)
		if not self.WatchingResources then
			self.WatchingResources = true
			self:loop(function()
				for _, owned in ipairs(self.Resources) do
					if not owned.Released and (not c.IsAlive(owned.Player) or owned.Player.Character ~= owned.Character) then owned.close() end
				end
			end)
		end
		return resource.close
	end
	function s:hit(player, amount, cooldown, channel)
		if not self:character(player) then return end
		local key = (channel or "hazard") .. ":" .. player.UserId
		local now = os.clock()
		if now < (self.HitTimes[key] or 0) then return end
		self.HitTimes[key] = now + (cooldown or 1)
		c.Damage(player, amount)
	end
	function s:area(position, radius, damage, vertical, channel)
		for _, player in ipairs(self:players()) do
			local _, _, root = self:character(player)
			if root and flatDistance(root.Position, position) <= radius and math.abs(root.Position.Y - position.Y) <= (vertical or 12) then self:hit(player, damage, 0.8, channel) end
		end
	end
	function s:role(player, role, color)
		local character = self:character(player)
		if not character then return end
		local owned = self.Roles[player]
		if owned and owned.Highlight then owned.Highlight:Destroy() end
		c.SetRole(player, role)
		local highlight
		if color then
			highlight = Instance.new("Highlight")
			highlight.Name = "EventRole"
			highlight.Adornee = character
			highlight.FillColor = color
			highlight.FillTransparency = 0.5
			highlight.OutlineColor = color
			highlight.DepthMode = Enum.HighlightDepthMode.Occluded
			highlight.Parent = self.Container
			self:resource(player, character, function() highlight:Destroy() end)
		end
		self.Roles[player] = { Character = character, Highlight = highlight }
	end
	function s:buff(player, properties)
		local character, humanoid = self:character(player)
		if not humanoid then return end
		local previous = {}
		for property, value in pairs(properties) do previous[property] = humanoid[property]; humanoid[property] = value end
		self:resource(player, character, function()
			if player.Character == character and humanoid.Parent then
				for property, value in pairs(previous) do humanoid[property] = value end
			end
		end)
	end
	function s:close()
		if not self.Live then return end
		self.Live = false
		for _, job in ipairs(self.Jobs) do
			if task.cancel and job ~= coroutine.running() and coroutine.status(job) ~= "dead" then pcall(task.cancel, job) end
		end
		for index = #self.Restores, 1, -1 do self.Restores[index]() end
		for instance, properties in pairs(self.Saved) do
			if instance.Parent then for property, value in pairs(properties) do instance[property] = value[1] end end
		end
		for player, role in pairs(self.Roles) do
			if player.Character == role.Character and (not c.Active or c.Active()) and c.IsAlive(player) then c.SetRole(player, nil) end
		end
		for player, text in pairs(self.Hints) do
			if player.Parent and player:GetAttribute("EventHint") == text then player:SetAttribute("EventHint", nil) end
		end
		self.Container:Destroy()
	end
	return s
end

local function surfaceParts(c)
	local parts = table.clone(c.World.Platforms)
	if c.World.Floor then table.insert(parts, c.World.Floor) end
	for _, bridge in ipairs(c.World.Bridges or {}) do table.insert(parts, bridge) end
	return parts
end
local function marker(s, position, radius, color, name)
	local part = s:part(name or "DangerWarning", Vector3.new(0.18, radius * 2, radius * 2), Vector3.new(position.X, TOP + 0.18, position.Z), color, Enum.Material.Neon, Enum.PartType.Cylinder)
	part.Orientation = Vector3.new(0, 0, 90)
	part.Transparency = 0.35
	return part
end
local function label(s, part, text, color)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(190, 45)
	gui.StudsOffset = Vector3.new(0, 5, 0)
	gui.AlwaysOnTop = true
	gui.Adornee = part
	gui.Parent = part
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundTransparency = 1
	textLabel.TextColor3 = color or Color3.new(1, 1, 1)
	textLabel.TextStrokeTransparency = 0.45
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextScaled = true
	textLabel.Text = text
	textLabel.Parent = gui
	return textLabel
end
local function nearest(s, position, exclude)
	local found, rootFound, best = nil, nil, math.huge
	for _, player in ipairs(s:players()) do
		local _, _, root = s:character(player)
		if root and player ~= exclude then
			local distance = flatDistance(position, root.Position)
			if distance < best then found, rootFound, best = player, root, distance end
		end
	end
	return found, rootFound, best
end
local function setPosition(pieces, position, angle)
	local cf = CFrame.new(position) * CFrame.Angles(0, angle or 0, 0)
	for _, piece in ipairs(pieces) do piece.Part.CFrame = cf * CFrame.new(piece.Offset) end
end
local function npc(s, kind, position)
	local pieces = {}
	local function piece(name, size, offset, color, shape)
		local part = s:part(name, size, position + offset, color, nil, shape)
		table.insert(pieces, { Part = part, Offset = offset })
		return part
	end
	local body
	if kind == "chicken" then
		body = piece("ChickenBody", Vector3.new(6, 7, 6), Vector3.new(0, 4.6, 0), Color3.fromRGB(255, 246, 216), Enum.PartType.Ball)
		piece("ChickenHead", Vector3.new(3.7, 3.7, 3.7), Vector3.new(0, 8.2, -1.2), Color3.fromRGB(255, 246, 216), Enum.PartType.Ball)
		piece("ChickenBeak", Vector3.new(2, 1.4, 2), Vector3.new(0, 8, -3.4), GOLD)
		piece("ChickenComb", Vector3.new(1, 1.6, 2.5), Vector3.new(0, 10.2, -1.2), RED)
		for _, sign in ipairs({ -1, 1 }) do
			piece("ChickenEye", Vector3.new(0.5, 0.5, 0.5), Vector3.new(sign * 1.3, 8.7, -2.7), Color3.fromRGB(40, 36, 52), Enum.PartType.Ball)
			piece("ChickenWing", Vector3.new(1.8, 3, 4), Vector3.new(sign * 3, 4.8, 0), Color3.fromRGB(255, 224, 153), Enum.PartType.Ball)
			piece("ChickenFoot", Vector3.new(2, 0.5, 3), Vector3.new(sign * 1.5, 0.3, -1), GOLD)
		end
	else
		body = piece("ZombieTorso", Vector3.new(2.8, 3.8, 1.8), Vector3.new(0, 3.5, 0), PURPLE)
		piece("ZombieHead", Vector3.new(2.2, 2.2, 2.2), Vector3.new(0, 6.5, 0), GREEN)
		for _, sign in ipairs({ -1, 1 }) do
			piece("ZombieArm", Vector3.new(1, 3, 1), Vector3.new(sign * 2, 3.5, -1.2), GREEN)
			piece("ZombieLeg", Vector3.new(1.1, 2.3, 1.2), Vector3.new(sign * 0.8, 1.2, 0), Color3.fromRGB(73, 89, 149))
			piece("ZombieEye", Vector3.new(0.4, 0.4, 0.3), Vector3.new(sign * 0.5, 6.7, -1.15), RED)
		end
	end
	label(s, body, kind == "chicken" and "RUN. IT'S HUNGRY." or "BRAAAINS!", kind == "chicken" and GOLD or GREEN)
	return pieces
end
local function chase(s, kind, position, speed)
	local pieces = npc(s, kind, position)
	s:loop(function(elapsed)
		local _, target, distance = nearest(s, position)
		if not target or elapsed < 3 then return end
		local direction = Vector3.new(target.Position.X - position.X, 0, target.Position.Z - position.Z)
		if direction.Magnitude > 0.2 then
			direction = direction.Unit
			position += direction * math.min(speed * 0.15, distance)
			setPosition(pieces, position + Vector3.new(0, math.abs(math.sin(elapsed * 5)) * 0.7, 0), math.atan2(-direction.X, -direction.Z))
		end
		for _, player in ipairs(s:players()) do
			local _, _, root = s:character(player)
			if root and flatDistance(root.Position, position) < (kind == "chicken" and 6 or 4) and math.abs(root.Position.Y - TOP) < 9 then s:hit(player, kind == "chicken" and 24 or 16, 1, kind) end
		end
	end)
end
local function strike(s, position, radius, damage, kind)
	local warning = marker(s, position, radius, kind == "lightning" and GOLD or RED, "Incoming" .. kind)
	label(s, warning, kind == "lightning" and "LIGHTNING! MOVE!" or "INCOMING! MOVE!", kind == "lightning" and GOLD or RED)
	s:spawn(function()
		if not s:wait(2.2) then return end
		warning:Destroy()
		local effect
		if kind == "lightning" then
			effect = s:part("LightningBolt", Vector3.new(0.8, 60, 0.8), Vector3.new(position.X, TOP + 30, position.Z), GOLD, Enum.Material.Neon)
		else
			effect = s:part(kind == "meteor" and "Meteor" or "BombBlast", Vector3.new(radius * 2, radius * 2, radius * 2), Vector3.new(position.X, TOP + 3, position.Z), kind == "meteor" and Color3.fromRGB(255, 130, 64) or RED, Enum.Material.Neon, Enum.PartType.Ball)
			effect.Transparency = 0.25
		end
		s:area(Vector3.new(position.X, TOP + 4, position.Z), radius, damage, 14, kind)
		if s:wait(0.5) then effect:Destroy() end
	end)
end
local function shower(s, color)
	local emitterPart = s:part("ArenaRainCloud", Vector3.new(152, 1, 152), Vector3.new(0, 72, 0), color)
	emitterPart.Transparency = 1
	local particles = Instance.new("ParticleEmitter")
	particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	particles.Color = ColorSequence.new(color)
	particles.EmissionDirection = Enum.NormalId.Bottom
	particles.Rate = 150
	particles.Speed = NumberRange.new(38, 42)
	particles.Lifetime = NumberRange.new(1.2)
	particles.Size = NumberSequence.new(0.35)
	particles.Acceleration = Vector3.new(0, -30, 0)
	particles.Parent = emitterPart
end

local definitions = {}
local function add(id, name, description, duration, callback, minimum, weight)
	table.insert(definitions, {
		Id = id, Name = name, Description = description, Duration = duration,
		MinPlayers = minimum or 1, Weight = weight or 1,
		Run = function(context, presser)
			local scope = newScope(context, name)
			local ok, err = pcall(callback, scope, context, presser)
			if not ok then scope:close(); error(err) end
			return function() scope:close() end
		end,
	})
end

add("cops_robbers", "COPS & ROBBERS", "Blue cop: catch the red robber. Robber: survive the chase! Four-second head start.", 20, function(s, c, presser)
	local players = shuffled(s:players())
	if #players < 2 then return end
	local cop = presser and c.IsAlive(presser) and presser or players[1]
	local robber = players[1] == cop and players[2] or players[1]
	s:role(cop, "Cop", BLUE)
	s:role(robber, "Robber", RED)
	s:hint(cop, "Catch the red robber after the head start")
	s:hint(robber, "Escape the blue cop")
	s:buff(cop, { WalkSpeed = 22 })
	s:buff(robber, { WalkSpeed = 19 })
	toast(c, cop.DisplayName .. " is the cop! " .. robber.DisplayName .. " has a 4-second head start.")
	local finished = false
	s:loop(function(elapsed)
		if finished or elapsed < 4 then return end
		local _, _, copRoot = s:character(cop)
		local _, _, robberRoot = s:character(robber)
		if not robberRoot then finished = true; return end
		if copRoot and flatDistance(copRoot.Position, robberRoot.Position) <= 5.5 and math.abs(copRoot.Position.Y - robberRoot.Position.Y) < 6 then
			finished = true
			c.Award(cop, 30, 5)
			c.Eliminate(robber, "Caught by the cop")
			toast(c, "CAUGHT! " .. cop.DisplayName .. " captured the robber.", "good")
		elseif elapsed >= 19 then
			finished = true
			c.Award(robber, 35, 5)
			toast(c, robber.DisplayName .. " escaped! +35 coins.", "good")
		end
	end)
end, 2, 1.3)

add("rising_lava", "THE LAVA IS RISING", "Climb the bright emergency stairs or a cottage roof. Low ground burns after the warning.", 18, function(s)
	local lava = s:part("RisingLava", Vector3.new(156, 2, 156), Vector3.new(0, 13, 0), Color3.fromRGB(255, 104, 47), Enum.Material.Neon)
	lava.Transparency = 0.12
	for _, platform in ipairs(s.Context.World.Platforms) do
		local position = platform.Position
		for step = 1, 4 do
			local height = step * 2.5
			s:part("EmergencyStair", Vector3.new(3.5, height, 5), Vector3.new(position.X - 7 + (step - 1) * 3.4, TOP + height / 2, position.Z + 5), GOLD, Enum.Material.SmoothPlastic, nil, true)
		end
	end
	s:loop(function(elapsed)
		if elapsed < 4 then return end
		local level = math.min(35.5, 16 + (elapsed - 4) * 2.1)
		lava.Position = Vector3.new(0, level - 1, 0)
		for _, player in ipairs(s:players()) do
			local _, _, root = s:character(player)
			if root and root.Position.Y < level + 2 then s:hit(player, 18, 1, "lava") end
		end
	end)
end)

add("laser_sweep", "LASER LIMBO", "Jump over the pink beam. It sweeps the islands twice.", 16, function(s)
	local laser = s:part("SweepingLaser", Vector3.new(160, 0.8, 1.2), Vector3.new(0, TOP + 2, -78), Color3.fromRGB(255, 112, 199), Enum.Material.Neon)
	s:loop(function(elapsed)
		if elapsed < 3 then return end
		local phase = ((elapsed - 3) * 24) % 312
		local z = phase < 156 and -78 + phase or 234 - phase
		laser.Position = Vector3.new(0, TOP + 2, z)
		for _, player in ipairs(s:players()) do
			local _, _, root = s:character(player)
			if root and math.abs(root.Position.Z - z) < 2 and math.abs(root.Position.Y - (TOP + 2)) < 3.5 then s:hit(player, 30, 1.3, "laser") end
		end
	end)
end)

add("meteor_shower", "METEOR MAYHEM", "Red circles mark impact zones. Move before the meteors land!", 18, function(s)
	s:spawn(function()
		for _ = 1, 7 do
			if not s:active() then break end
			local platforms = shuffled(s.Context.World.Platforms)
			for index = 1, math.min(2, #platforms) do strike(s, platforms[index].Position, 9, 42, "meteor") end
			if not s:wait(2) then break end
		end
	end)
end)

add("chicken_chase", "CHICKEN'S REVENGE", "A giant hungry chicken is chasing the nearest survivor. Keep moving!", 18, function(s)
	chase(s, "chicken", Vector3.new(0, TOP, 0), 13)
end)

add("zombie_outbreak", "ZOMBIE OUTBREAK", "Three zombies are invading the islands. Don't let them corner you.", 18, function(s)
	for index = 1, 3 do
		local angle = index * math.pi * 2 / 3
		chase(s, "zombie", Vector3.new(math.cos(angle) * 58, TOP, math.sin(angle) * 58), 9 + index)
	end
end)

add("hot_potato", "HOT POTATO", "Tag someone nearby to pass the bomb. The holder has eight seconds!", 18, function(s, c)
	local players = s:players()
	if #players < 2 then return end
	local holder = players[random:NextInteger(1, #players)]
	local expires, lastTransfer = os.clock() + 8, os.clock()
	local serverExpires = workspace:GetServerTimeNow() + 8
	local bomb = s:part("HotPotatoBomb", Vector3.new(2.5, 2.5, 2.5), Vector3.new(0, 40, 0), RED, Enum.Material.Neon, Enum.PartType.Ball)
	local text = label(s, bomb, "8", RED)
	local ownedAttributes = {}
	local function assign(player)
		if holder and holder ~= player and s:character(holder) then s:role(holder, nil); s:hint(holder, nil) end
		holder = player
		if holder then s:role(holder, "Hot Potato", RED); s:hint(holder, "Tag someone to pass the bomb!") end
		lastTransfer = os.clock()
	end
	s:restore(function()
		for player in pairs(ownedAttributes) do if player.Parent then player:SetAttribute("EventTimer", nil) end end
	end)
	assign(holder)
	local rounds, finished = 0, false
	s:loop(function()
		if finished then return end
		local root
		if holder then local _, _, found = s:character(holder); root = found end
		if not root then
			local remaining = s:players()
			if #remaining < 2 then bomb.Transparency = 1; finished = true; return end
			assign(remaining[random:NextInteger(1, #remaining)])
			local _, _, found = s:character(holder)
			root = found
			if not root then return end
		end
		bomb.Position = root.Position + Vector3.new(0, 4, 0)
		local seconds = math.max(0, math.ceil(expires - os.clock()))
		text.Text = "PASS IT! " .. seconds
		holder:SetAttribute("EventTimer", serverExpires)
		ownedAttributes[holder] = true
		if os.clock() >= expires then
			s:area(root.Position, 9, 35, 10, "potatoBlast")
			if not s:active() then return end
			if c.IsAlive(holder) then c.Eliminate(holder, "Held the hot potato too long") end
			rounds += 1
			if rounds >= 2 then bomb.Transparency = 1; finished = true; return end
			expires, holder = os.clock() + 8, nil
			serverExpires = workspace:GetServerTimeNow() + 8
		elseif os.clock() - lastTransfer > 1.1 then
			local nextPlayer, otherRoot, distance = nearest(s, root.Position, holder)
			if nextPlayer and distance < 6 and math.abs(otherRoot.Position.Y - root.Position.Y) < 5 then
				holder:SetAttribute("EventTimer", nil)
				assign(nextPlayer)
			end
		end
	end)
end, 2)

add("musical_islands", "MUSICAL ISLANDS", "Get onto a GREEN island before the music stops. You have eight seconds to reach safety.", 20, function(s)
	local safe, markers = {}, {}
	local function choose()
		for _, part in ipairs(markers) do part:Destroy() end
		markers, safe = {}, {}
		local platforms = shuffled(s.Context.World.Platforms)
		for index = 1, math.min(4, #platforms) do
			table.insert(safe, platforms[index].Position)
			table.insert(markers, marker(s, platforms[index].Position, 8, GREEN, "SafeIsland"))
		end
	end
	choose()
	local lastRound = 0
	s:loop(function(elapsed)
		local currentRound = math.floor(elapsed / 10)
		if currentRound ~= lastRound then lastRound = currentRound; choose() end
		if elapsed % 10 < 8.5 then return end
		for _, player in ipairs(s:players()) do
			local _, _, root = s:character(player)
			if root then
				local protected = false
				for _, position in ipairs(safe) do if flatDistance(root.Position, position) <= 10 then protected = true; break end end
				if not protected then s:hit(player, 35, 2, "music") end
			end
		end
	end)
end)

add("vanishing_islands", "NOW YOU SEE IT...", "Flashing red islands and their bridges disappear in four seconds. Find solid ground.", 16, function(s, c)
	local selected = shuffled(c.World.Platforms)
	local warnings = {}
	for index = 1, math.min(4, #selected) do
		local platform = selected[index]
		table.insert(warnings, marker(s, platform.Position, 10, RED, "VanishingWarning"))
		s:save(platform, { Color = RED })
	end
	s:spawn(function()
		if not s:wait(4) then return end
		for _, warning in ipairs(warnings) do warning:Destroy() end
		for index = 1, math.min(4, #selected) do
			local platform = selected[index]
			-- The cottage and porch must disappear too, or the missing island
			-- would retain a large invisible safe floor under its survivors.
			for _, instance in ipairs(platform.Parent:GetDescendants()) do
				if instance:IsA("BasePart") then s:save(instance, { CanCollide = false, Transparency = 0.94 }) end
			end
			local islandIndex = table.find(c.World.Platforms, platform)
			local bridge = c.World.Bridges and c.World.Bridges[islandIndex]
			if bridge then s:save(bridge, { CanCollide = false, Transparency = 0.88 }) end
		end
	end)
end)

add("shrinking_islands", "HONEY, I SHRUNK THE ISLANDS", "The outer island floors are shrinking! Head toward the hub or balance on the remaining ground.", 18, function(s, c)
	local originals = {}
	for _, platform in ipairs(c.World.Platforms) do originals[platform] = platform.Size; s:save(platform, { Color = GOLD }) end
	s:loop(function(elapsed)
		if elapsed < 3 then return end
		local scale = math.max(0.27, 1 - (elapsed - 3) * 0.065)
		for platform, size in pairs(originals) do s:save(platform, { Size = Vector3.new(size.X * scale, size.Y, size.Z * scale) }) end
	end)
end)

add("acid_rain", "ACID RAIN", "Hide under a GREEN emergency umbrella. Exposed survivors take damage after four seconds.", 18, function(s, c)
	local shelters = {}
	local platforms = shuffled(c.World.Platforms)
	for index = 1, math.min(5, #platforms) do
		local position = platforms[index].Position
		table.insert(shelters, position)
		local roof = s:part("AcidUmbrella", Vector3.new(16, 1, 16), Vector3.new(position.X, TOP + 10, position.Z), GREEN, Enum.Material.SmoothPlastic, nil, true)
		label(s, roof, "SAFE COVER", GREEN)
		marker(s, position, 7, GREEN, "ShelterMarker")
	end
	shower(s, GREEN)
	s:loop(function(elapsed)
		if elapsed < 4 then return end
		for _, player in ipairs(s:players()) do
			local _, _, root = s:character(player)
			if root then
				local covered = false
				for _, position in ipairs(shelters) do if flatDistance(root.Position, position) < 8 and root.Position.Y < TOP + 10 then covered = true; break end end
				if not covered then s:hit(player, 12, 1, "acid") end
			end
		end
	end)
end)

add("tidal_wave", "TIDAL TROUBLE", "A huge blue wave is coming. Climb a roof or jump high to dodge it.", 16, function(s)
	local wave = s:part("TidalWave", Vector3.new(7, 11, 155), Vector3.new(-79, TOP + 4, 0), BLUE, Enum.Material.Neon)
	wave.Transparency = 0.35
	s:loop(function(elapsed)
		if elapsed < 4 then return end
		local x = -79 + (elapsed - 4) * 15
		wave.Position = Vector3.new(x, TOP + 4, 0)
		for _, player in ipairs(s:players()) do
			local _, _, root = s:character(player)
			if root and math.abs(root.Position.X - x) < 5 and root.Position.Y < TOP + 11 then s:hit(player, 35, 2, "wave"); if s:active() then root.AssemblyLinearVelocity = Vector3.new(22, 35, 0) end end
		end
	end)
end)

add("shockwaves", "JUMP! JUMP! JUMP!", "Golden shockwaves expand from the button. Jump over each ring.", 16, function(s)
	local rings = {}
	for index = 1, 3 do
		local parts = {}
		for _ = 1, 24 do table.insert(parts, s:part("ShockwaveSegment", Vector3.new(3.5, 0.65, 2), Vector3.new(0, TOP + 1, 0), GOLD, Enum.Material.Neon)) end
		table.insert(rings, { Parts = parts, Start = 3 + (index - 1) * 4 })
	end
	s:loop(function(elapsed)
		for index, ring in ipairs(rings) do
			local age = elapsed - ring.Start
			local radius = math.max(0, age * 21)
			for segment, part in ipairs(ring.Parts) do
				part.Transparency = (age < 0 or radius > 83) and 1 or 0
				local angle = segment * math.pi * 2 / #ring.Parts
				part.CFrame = CFrame.new(math.cos(angle) * radius, TOP + 1, math.sin(angle) * radius) * CFrame.Angles(0, -angle, 0)
				part.Size = Vector3.new(3.5, 0.65, math.max(2, radius * 0.28))
			end
			if age >= 0 and radius <= 83 then
				for _, player in ipairs(s:players()) do
					local _, _, root = s:character(player)
					if root and math.abs(flatDistance(root.Position, Vector3.zero) - radius) < 3 and root.Position.Y < TOP + 5 then s:hit(player, 28, 2, "shock" .. index) end
				end
			end
		end
	end)
end)

add("slippery_islands", "ICE ICE MAYBE", "The islands are icy! Take small steps and stay away from the edges.", 16, function(s, c)
	for _, part in ipairs(surfaceParts(c)) do s:save(part, { Material = Enum.Material.Ice, Color = Color3.fromRGB(166, 227, 255), CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.01, 0.3, 100, 1) }) end
end)

add("moon_gravity", "MOON WALK", "Survivors get floaty jumps. Mind the gaps: the lobby stays on Earth.", 18, function(s)
	for _, player in ipairs(s:players()) do
		local character, _, root = s:character(player)
		if root then
			local attachment = Instance.new("Attachment")
			attachment.Name = "EventMoonAttachment"
			attachment.Parent = root
			local force = Instance.new("VectorForce")
			force.Name = "EventMoonGravity"
			force.Attachment0 = attachment
			force.RelativeTo = Enum.ActuatorRelativeTo.World
			force.ApplyAtCenterOfMass = true
			force.Force = Vector3.new(0, root.AssemblyMass * workspace.Gravity * 0.67, 0)
			force.Parent = root
			s:resource(player, character, function() force:Destroy(); attachment:Destroy() end)
		end
	end
end, 1, 0.65)

add("speed_frenzy", "SPEED LIMIT: NONE", "Everyone in the round runs faster. Tight bridges just became much harder.", 14, function(s)
	for _, player in ipairs(s:players()) do s:buff(player, { WalkSpeed = 29 }) end
	for _, platform in ipairs(s.Context.World.Platforms) do marker(s, platform.Position, 3, BLUE, "SpeedSpark") end
end, 1, 0.65)

add("lightning_storm", "LIGHTNING LIKES YOU", "Yellow targets lock onto survivors' last positions. Leave the circles before lightning strikes.", 18, function(s)
	shower(s, BLUE)
	s:spawn(function()
		for _ = 1, 5 do
			if not s:active() then return end
			local selected = shuffled(s:players())
			for index = 1, math.min(3, #selected) do
				local _, _, root = s:character(selected[index])
				if root then strike(s, root.Position, 6, 38, "lightning") end
			end
			if not s:wait(3) then break end
		end
	end)
end)

add("spinner", "THE GREAT SPINNER", "A red arm circles the arena at ankle height. Jump over it or shelter above it.", 18, function(s)
	local spinner = s:part("SpinnerArm", Vector3.new(147, 1.2, 1.5), Vector3.new(0, TOP + 1.5, 0), RED, Enum.Material.Neon)
	s:loop(function(elapsed)
		if elapsed < 3 then return end
		spinner.CFrame = CFrame.new(0, TOP + 1.5, 0) * CFrame.Angles(0, (elapsed - 3) * 0.85, 0)
		for _, player in ipairs(s:players()) do
			local _, _, root = s:character(player)
			if root then
				local relative = spinner.CFrame:PointToObjectSpace(root.Position)
				if math.abs(relative.X) < 74 and math.abs(relative.Z) < 2.5 and math.abs(relative.Y) < 3.5 then s:hit(player, 24, 1.2, "spinner") end
			end
		end
	end)
end)

add("greedy_gold", "GREED IS DANGEROUS", "Gold coins are worth ten each. Red coins are traps. Collect carefully!", 16, function(s, c)
	local coins = {}
	for index = 1, 30 do
		local platform = c.World.Platforms[(index - 1) % #c.World.Platforms + 1]
		local fake = index % 4 == 0
		local position = Vector3.new(platform.Position.X + random:NextNumber(-7, 7), TOP + 2.5, platform.Position.Z + random:NextNumber(-7, 7))
		local coin = s:part(fake and "TrapCoin" or "RewardCoin", Vector3.new(0.4, 1.8, 1.8), position, fake and RED or GOLD, Enum.Material.Neon, Enum.PartType.Cylinder)
		coin.Orientation = Vector3.new(0, 0, 90)
		table.insert(coins, { Part = coin, Fake = fake, Base = position, Collected = false })
	end
	s:loop(function(elapsed)
		for _, coin in ipairs(coins) do
			if coin.Collected then continue end
			coin.Part.Position = coin.Base + Vector3.new(0, math.sin(elapsed * 3) * 0.5, 0)
			for _, player in ipairs(s:players()) do
				local _, _, root = s:character(player)
				if root and (root.Position - coin.Part.Position).Magnitude <= 3.5 then
					coin.Collected = true
					coin.Part:Destroy()
					if coin.Fake then s:hit(player, 20, 0, "trapCoin") else c.Award(player, 10, 1) end
					break
				end
			end
		end
	end)
end)

add("red_light", "RED LIGHT, GREEN LIGHT", "GREEN means go. When the giant light turns RED, stand still! One second to stop.", 18, function(s, c)
	local light = s:part("TrafficLight", Vector3.new(5, 5, 5), Vector3.new(0, TOP + 15, 0), GREEN, Enum.Material.Neon, Enum.PartType.Ball)
	local text = label(s, light, "GREEN LIGHT", GREEN)
	local previous, phase = {}, -1
	s:loop(function(elapsed)
		local currentPhase = math.floor(elapsed / 3)
		local red = currentPhase % 2 == 1
		if currentPhase ~= phase then
			phase, previous = currentPhase, {}
			light.Color = red and RED or GREEN
			text.Text = red and "RED LIGHT: FREEZE!" or "GREEN LIGHT: GO!"
			text.TextColor3 = light.Color
			toast(c, red and "RED LIGHT! Stop moving." or "GREEN LIGHT! Move.")
		end
		for _, player in ipairs(s:players()) do
			local _, _, root = s:character(player)
			if root then
				if red and elapsed % 3 > 1 and previous[player] and flatDistance(root.Position, previous[player]) > 0.65 then s:hit(player, 18, 0.9, "redLight") end
				previous[player] = root.Position
			end
		end
	end)
end)

add("falling_bombs", "SPECIAL DELIVERY: BOMBS", "Bombs target where you were standing. The red circles give you time to run.", 18, function(s)
	s:spawn(function()
		for _ = 1, 6 do
			local selected = shuffled(s:players())
			for index = 1, math.min(3, #selected) do
				local _, _, root = s:character(selected[index])
				if root then strike(s, root.Position, 7.5, 34, "bomb") end
			end
			if not s:wait(2.4) then break end
		end
	end)
end)

add("supply_drop", "A MOMENT OF MERCY", "Grab a glowing supply crate for healing and coins. First come, first saved.", 12, function(s, c)
	local crates = {}
	local platforms = shuffled(c.World.Platforms)
	for index = 1, math.min(6, #platforms) do
		local position = platforms[index].Position
		local crate = s:part("SupplyCrate", Vector3.new(3, 3, 3), Vector3.new(position.X, TOP + 2, position.Z), GREEN, Enum.Material.SmoothPlastic)
		label(s, crate, "+35 HP / +15 COINS", GREEN)
		table.insert(crates, { Part = crate, Collected = false })
	end
	s:loop(function()
		for _, crate in ipairs(crates) do
			if crate.Collected then continue end
			for _, player in ipairs(s:players()) do
				local _, humanoid, root = s:character(player)
				if root and (root.Position - crate.Part.Position).Magnitude < 4.5 then
					crate.Collected = true
					crate.Part:Destroy()
					humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + 35)
					c.Award(player, 15, 1)
					break
				end
			end
		end
	end)
end, 1, 0.65)

add("earthquake", "EARTHQUAKE!", "The islands shake and tremors shove survivors. Jump and keep your balance.", 16, function(s, c)
	local originals = {}
	for _, platform in ipairs(c.World.Platforms) do originals[platform] = platform.CFrame end
	local lastImpulse = 0
	s:loop(function(elapsed)
		if elapsed < 3 then return end
		for index, platform in ipairs(c.World.Platforms) do s:save(platform, { CFrame = originals[platform] * CFrame.new(math.sin(elapsed * 13 + index) * 0.25, math.sin(elapsed * 9 + index) * 0.4, 0) }) end
		if elapsed - lastImpulse >= 3 then
			lastImpulse = elapsed
			for _, player in ipairs(s:players()) do
				local _, humanoid, root = s:character(player)
				if root and humanoid.FloorMaterial ~= Enum.Material.Air then
					local direction = Vector3.new(root.Position.X, 0, root.Position.Z)
					if direction.Magnitude > 1 then root.AssemblyLinearVelocity = direction.Unit * 14 + Vector3.new(0, 18, 0) end
				end
			end
		end
	end)
end)

add("tornado", "TWISTER ON THE LOOSE", "A roaming tornado pulls nearby survivors inward. Keep clear of the purple funnel.", 18, function(s)
	local discs = {}
	for index = 1, 8 do
		local disc = s:part("TornadoRing", Vector3.new(1.5, index * 1.8 + 2, index * 1.8 + 2), Vector3.new(0, TOP + index * 2, 0), PURPLE, Enum.Material.Neon, Enum.PartType.Cylinder)
		disc.Orientation = Vector3.new(0, 0, 90)
		disc.Transparency = 0.55
		table.insert(discs, disc)
	end
	s:loop(function(elapsed)
		local position = Vector3.new(math.cos(elapsed * 0.48) * 46, TOP, math.sin(elapsed * 0.48) * 46)
		for index, disc in ipairs(discs) do disc.Position = position + Vector3.new(math.sin(elapsed * 5 + index), index * 2, math.cos(elapsed * 5 + index)) end
		if elapsed < 4 then return end
		for _, player in ipairs(s:players()) do
			local _, _, root = s:character(player)
			if root then
				local delta = Vector3.new(position.X - root.Position.X, 0, position.Z - root.Position.Z)
				if delta.Magnitude < 17 and delta.Magnitude > 0.1 then
					root.AssemblyLinearVelocity += delta.Unit * 3.4 + Vector3.new(0, 1.7, 0)
					if delta.Magnitude < 5 then s:hit(player, 15, 1, "tornado") end
				end
			end
		end
	end)
end)

add("cursed_crown", "THE CURSED CROWN", "The crowned survivor earns coins while marked. Tag another player to pass the draining curse.", 18, function(s, c)
	local players = s:players()
	if #players < 2 then return end
	local holder = players[random:NextInteger(1, #players)]
	local lastTransfer, lastReward = os.clock(), os.clock()
	s:role(holder, "Cursed King", GOLD)
	s:hint(holder, "Touch another survivor to pass the curse")
	local crown = s:part("CursedCrown", Vector3.new(3.5, 0.8, 3.5), Vector3.new(0, 42, 0), GOLD, Enum.Material.Neon)
	label(s, crown, "PASS THE CURSE", GOLD)
	s:loop(function(elapsed)
		local _, _, root = s:character(holder)
		if not root then
			local remaining = s:players()
			if #remaining == 0 then return end
			holder = remaining[random:NextInteger(1, #remaining)]
			s:role(holder, "Cursed King", GOLD)
			s:hint(holder, "Touch another survivor to pass the curse")
			local _, _, found = s:character(holder)
			root = found
			if not root then return end
		end
		crown.Position = root.Position + Vector3.new(0, 3.8, 0)
		if elapsed < 3 then return end
		if os.clock() - lastReward > 1 then lastReward = os.clock(); c.Award(holder, 3, 0); s:hit(holder, 8, 0.9, "curse") end
		if os.clock() - lastTransfer > 2 then
			local target, targetRoot, distance = nearest(s, root.Position, holder)
			if target and distance < 5.5 and math.abs(targetRoot.Position.Y - root.Position.Y) < 5 then
				s:role(holder, nil)
				s:hint(holder, nil)
				holder = target
				s:role(holder, "Cursed King", GOLD)
				s:hint(holder, "Touch another survivor to pass the curse")
				lastTransfer = os.clock()
			end
		end
	end)
end, 2)

add("freeze_tag", "FREEZE TAG", "The blue tagger can freeze survivors for two seconds. Run, jump, and avoid contact.", 18, function(s, c, presser)
	local players = s:players()
	if #players < 2 then return end
	local tagger = presser and c.IsAlive(presser) and presser or players[1]
	s:role(tagger, "Ice Tagger", BLUE)
	s:hint(tagger, "Tag survivors to freeze them")
	s:buff(tagger, { WalkSpeed = 21 })
	local frozen = {}
	local function thaw(player, data)
		if data.Release then data.Release() end
		if s:character(player) then s:role(player, nil); s:hint(player, nil) end
		frozen[player] = nil
	end
	s:restore(function() for player, data in pairs(frozen) do thaw(player, data) end end)
	s:loop(function(elapsed)
		for player, data in pairs(frozen) do if os.clock() >= data.Until or not c.IsAlive(player) then thaw(player, data) end end
		if elapsed < 3 then return end
		local _, _, taggerRoot = s:character(tagger)
		if not taggerRoot then return end
		for _, player in ipairs(s:players()) do
			local character, humanoid, root = s:character(player)
			if root and player ~= tagger and not frozen[player] and flatDistance(root.Position, taggerRoot.Position) < 5.5 and math.abs(root.Position.Y - taggerRoot.Position.Y) < 5 and os.clock() >= (s.HitTimes["freeze:" .. player.UserId] or 0) then
				local data = { Character = character, Humanoid = humanoid, Speed = humanoid.WalkSpeed, JumpPower = humanoid.JumpPower, JumpHeight = humanoid.JumpHeight, Until = os.clock() + 2 }
				frozen[player] = data
				data.Release = s:resource(player, character, function()
					if player.Character == character and humanoid.Parent then humanoid.WalkSpeed = data.Speed; humanoid.JumpPower = data.JumpPower; humanoid.JumpHeight = data.JumpHeight end
				end)
				s.HitTimes["freeze:" .. player.UserId] = os.clock() + 5
				humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight = 0, 0, 0
				s:role(player, "Frozen", BLUE)
				s:hint(player, "Frozen! You thaw in two seconds")
				c.Damage(player, 12)
				c.Award(tagger, 5, 0)
			end
		end
	end)
end, 2)

add("rocket_jump", "BOING!", "The islands turn into trampolines. Land on an island to bounce across the arena.", 16, function(s, c)
	for _, platform in ipairs(c.World.Platforms) do s:save(platform, { Color = Color3.fromRGB(255, 167, 223), Material = Enum.Material.Neon }) end
	local bounced = {}
	s:loop(function(elapsed)
		if elapsed < 2 then return end
		for _, player in ipairs(s:players()) do
			local _, _, root = s:character(player)
			if root and root.AssemblyLinearVelocity.Y < 1 and root.Position.Y >= TOP + 1 and root.Position.Y < TOP + 5 and os.clock() >= (bounced[player] or 0) then
				for _, platform in ipairs(c.World.Platforms) do
					if math.abs(root.Position.X - platform.Position.X) < 9 and math.abs(root.Position.Z - platform.Position.Z) < 9 then
						bounced[player] = os.clock() + 1.5
						root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 78, root.AssemblyLinearVelocity.Z)
						break
					end
				end
			end
		end
	end)
end, 1, 0.65)

add("bridge_roulette", "BRIDGE ROULETTE", "Half the bridges turn RED, then vanish. Use the safe bridges or stay on your island.", 16, function(s, c)
	local bridges = shuffled(c.World.Bridges or {})
	local count = math.ceil(#bridges / 2)
	for index = 1, count do s:save(bridges[index], { Color = RED, Material = Enum.Material.Neon }) end
	s:spawn(function()
		if not s:wait(4) then return end
		for index = 1, count do s:save(bridges[index], { CanCollide = false, Transparency = 0.9 }) end
	end)
end)

add("laser_grid", "LASER GRID", "Four neon fences pulse on and off. Cross while they're blue; jump clear when they turn pink.", 18, function(s)
	local bars = {}
	for _, z in ipairs({ -42, -14, 14, 42 }) do table.insert(bars, s:part("GridLaser", Vector3.new(155, 0.8, 1), Vector3.new(0, TOP + 2, z), BLUE, Enum.Material.Neon)) end
	s:loop(function(elapsed)
		local active = elapsed >= 3 and math.floor((elapsed - 3) / 2) % 2 == 1
		for _, bar in ipairs(bars) do
			bar.Color = active and Color3.fromRGB(255, 112, 199) or BLUE
			bar.Transparency = active and 0 or 0.65
			if active then
				for _, player in ipairs(s:players()) do
					local _, _, root = s:character(player)
					if root and math.abs(root.Position.Z - bar.Position.Z) < 2 and root.Position.Y < TOP + 5.5 then s:hit(player, 20, 1, "grid") end
				end
			end
		end
	end)
end)

Events.Definitions = definitions
function Events.choose(aliveCount, previousId, threatLevel)
	local eligible, total = {}, 0
	for _, definition in ipairs(definitions) do
		if (aliveCount or 1) >= definition.MinPlayers and definition.Id ~= previousId then
			local weight = definition.Weight
			if definition.Weight < 1 then weight /= 1 + math.max(0, (threatLevel or 1) - 1) * 0.16 end
			total += weight
			table.insert(eligible, { Definition = definition, Weight = weight })
		end
	end
	if #eligible == 0 then return nil end
	local roll = random:NextNumber(0, total)
	for _, entry in ipairs(eligible) do roll -= entry.Weight; if roll <= 0 then return entry.Definition end end
	return eligible[#eligible].Definition
end
return Events
