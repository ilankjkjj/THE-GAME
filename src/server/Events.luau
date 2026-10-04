-- Events own their visuals, jobs, roles and physics. The round controller
-- always calls cleanup on expiry or round end. Only alive participants qualify.
local Events = {}
local Director = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("DisasterDirector"))
local random = Random.new()
local RED = Color3.fromRGB(255, 86, 92)
local GOLD = Color3.fromRGB(255, 210, 79)
local BLUE = Color3.fromRGB(82, 183, 255)
local GREEN = Color3.fromRGB(105, 240, 157)
local PURPLE = Color3.fromRGB(185, 117, 255)
local TOP = 30

-- Property and private-status leases belong to individual event scopes. Removing
-- an older event must not erase a newer event's ice, speed, role or instructions.
local propertyLeases = setmetatable({}, { __mode = "k" })
local roleLeases = setmetatable({}, { __mode = "k" })
local hintLeases = setmetatable({}, { __mode = "k" })
local function leaseProperty(owner, instance, property, value)
	local properties = propertyLeases[instance]
	if not properties then properties = {}; propertyLeases[instance] = properties end
	local lease = properties[property]
	if not lease then lease = { Base = instance[property], Entries = {} }; properties[property] = lease end
	local owned
	for _, entry in ipairs(lease.Entries) do if entry.Owner == owner then owned = entry; break end end
	if not owned then owned = { Owner = owner }; table.insert(lease.Entries, owned) end
	owned.Value = value
	if lease.Entries[#lease.Entries] == owned then instance[property] = value; owned.Value = instance[property] end
end
local function releaseProperty(owner, instance, property)
	local properties = propertyLeases[instance]
	local lease = properties and properties[property]
	if not lease then return end
	local top = lease.Entries[#lease.Entries]
	for index = #lease.Entries, 1, -1 do if lease.Entries[index].Owner == owner then table.remove(lease.Entries, index) end end
	-- An external supply or persistent map change may have taken ownership.
	-- Preserve that change rather than writing an obsolete snapshot over it.
	if instance.Parent and top and top.Owner == owner and instance[property] == top.Value then
		local previous = lease.Entries[#lease.Entries]
		if previous then instance[property] = previous.Value; previous.Value = instance[property] else instance[property] = lease.Base end
	end
	if #lease.Entries == 0 then properties[property] = nil end
	if next(properties) == nil then propertyLeases[instance] = nil end
end
local function privateLease(bank, scope, player, value, setter)
	local entries = bank[player]
	if not entries then entries = {}; bank[player] = entries end
	for index = #entries, 1, -1 do if entries[index].Scope == scope then table.remove(entries, index) end end
	if value ~= nil then table.insert(entries, { Scope = scope, Value = value, Setter = setter }) end
	local top = entries[#entries]
	if player.Parent then
		-- Root's slot-aware setter must also clear this scope's own record.
		setter(player, value)
		if top and top.Scope ~= scope then top.Setter(player, top.Value) end
	end
	if #entries == 0 then bank[player] = nil end
end

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
			saved[property] = true
			leaseProperty(self, instance, property, value)
		end
	end
	function s:restore(callback) table.insert(self.Restores, callback) end
	function s:cue(kind, position, strength)
		if not self:active() or not c.Cue then return end
		local now = os.clock()
		-- Crowd impacts share a small budget; rendering and sound stay client-side.
		if now < (self.NextCue or 0) then return end
		self.NextCue = now + 0.22
		c.Cue(kind, position, strength or 1)
	end
	function s:phase(text, hint, kind, stage)
		if not self:active() then return end
		if c.SetStage then c.SetStage(stage or "Active", hint or text) end
		toast(c, text, "event")
		for _, player in ipairs(self:players()) do self:hint(player, hint or text) end
		self:cue(kind or "warning", Vector3.new(0, TOP, 0), 1)
	end
	function s:hint(player, text)
		if not player.Parent then return end
		local function setter(target, value)
			if c.SetHint then c.SetHint(target, value) else target:SetAttribute("EventHint", value) end
		end
		privateLease(hintLeases, self, player, text, setter)
		self.Hints[player] = setter
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
		privateLease(roleLeases, self, player, role, c.SetRole)
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
		local owner = {}
		for property, value in pairs(properties) do leaseProperty(owner, humanoid, property, value) end
		return self:resource(player, character, function()
			for property in pairs(properties) do releaseProperty(owner, humanoid, property) end
			if properties.MaxHealth and humanoid.Parent then humanoid.Health = math.min(humanoid.Health, humanoid.MaxHealth) end
		end)
	end
	function s:close()
		if not self.Live then return end
		self.Live = false
		for _, job in ipairs(self.Jobs) do
			if task.cancel and job ~= coroutine.running() and coroutine.status(job) ~= "dead" then pcall(task.cancel, job) end
		end
		for instance, properties in pairs(self.Saved) do
			for property in pairs(properties) do releaseProperty(self, instance, property) end
		end
		for index = #self.Restores, 1, -1 do self.Restores[index]() end
		for player, role in pairs(self.Roles) do
			privateLease(roleLeases, self, player, nil, c.SetRole)
		end
		for player, setter in pairs(self.Hints) do
			privateLease(hintLeases, self, player, nil, setter)
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
	-- Billboard scale components use studs: text recedes with its island
	-- instead of retaining a large pixel size across the entire arena.
	gui.Size = UDim2.fromScale(8, 1.8)
	gui.MaxDistance = 65
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
	local sizeLimit = Instance.new("UITextSizeConstraint")
	sizeLimit.MinTextSize, sizeLimit.MaxTextSize = 8, 22
	sizeLimit.Parent = textLabel
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
local function emitter(part, color, rate, speed, size, lifetime, direction)
	local particles = Instance.new("ParticleEmitter")
	particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	particles.Color = ColorSequence.new(color)
	particles.LightEmission = 0.65
	particles.Rate = rate
	particles.Speed = NumberRange.new(speed * 0.6, speed)
	particles.Lifetime = NumberRange.new(lifetime * 0.75, lifetime)
	particles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	particles.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	particles.SpreadAngle = Vector2.new(25, 25)
	particles.EmissionDirection = direction or Enum.NormalId.Top
	particles.Parent = part
	return particles
end
local function glow(part, color, brightness, range)
	local light = Instance.new("PointLight")
	light.Color, light.Brightness, light.Range = color, brightness or 1.5, range or 18
	light.Parent = part
	return light
end
local function beamPart(s, name, a, b, width, color, material)
	local part = s:part(name, Vector3.new(width, width, (b - a).Magnitude), (a + b) / 2, color, material or Enum.Material.Neon)
	part.CFrame = CFrame.lookAt((a + b) / 2, b)
	return part
end
local function impact(s, position, radius, color, kind)
	local group = Instance.new("Folder")
	group.Name = "ImpactBurst"
	group.Parent = s.Container
	local orb = s:part("ImpactFlash", Vector3.new(radius, radius, radius), position, color, Enum.Material.Neon, Enum.PartType.Ball)
	orb.Parent = group
	orb.Transparency = 0.3
	emitter(orb, color, 36, 23, 1.2, 0.5)
	glow(orb, color, 3, radius * 4)
	local debris = {}
	for index = 1, 6 do
		local angle = index * math.pi / 3
		local chunk = s:part("ImpactShard", Vector3.new(1.4, 1.4, 1.4), position, color, Enum.Material.Neon)
		chunk.Parent = group
		table.insert(debris, { Part = chunk, Direction = Vector3.new(math.cos(angle), 0, math.sin(angle)) })
	end
	s:cue(kind or "impact", position, math.min(2, radius / 6))
	s:spawn(function()
		for frame = 1, 5 do
			if not s:wait(0.12) then return end
			orb.Size = Vector3.new(1, 1, 1) * (radius + frame * 2)
			orb.Transparency = 0.3 + frame * 0.12
			for _, chunk in ipairs(debris) do
				chunk.Part.Position = position + chunk.Direction * frame * 2 + Vector3.new(0, 3 + frame - frame * frame * 0.24, 0)
				chunk.Part.CFrame *= CFrame.Angles(0.5, 0.4, 0.3)
			end
		end
		group:Destroy()
	end)
end
local function escapeCrates(s, position, color)
	-- Three separated jump platforms require deliberate jumps. No staircase
	-- or floor-to-roof solid columns appear inside an occupied cottage.
	local crate
	for level = 1, 3 do
		crate = s:part("EscapeCrate", Vector3.new(4.5, 3, 4.5), Vector3.new(position.X - 10, TOP + level * 3 - 1.5, position.Z - 10 + (level - 1) * 5), color, Enum.Material.WoodPlanks, nil, true)
	end
	label(s, crate, "JUMP TO SAFETY", color)
	return crate
end
local function hideBridge(s, bridge)
	s:save(bridge, { CanCollide = false, Transparency = 0.94 })
	for _, descendant in ipairs(bridge:GetDescendants()) do
		if descendant:IsA("BasePart") then s:save(descendant, { CanCollide = false, Transparency = 0.94 }) end
	end
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
			piece("ChickenPupil", Vector3.new(0.24, 0.3, 0.2), Vector3.new(sign * 1.3, 8.7, -3), Color3.new(0, 0, 0), Enum.PartType.Ball)
			piece("ChickenWattle", Vector3.new(0.9, 1.2, 0.7), Vector3.new(sign * 0.4, 7.1, -2.8), RED, Enum.PartType.Ball)
		end
		for index = 1, 3 do piece("TailFeather", Vector3.new(1.2, 3.5, 1.3), Vector3.new((index - 2) * 1.1, 5.8, 3), Color3.fromRGB(255, 222, 159), Enum.PartType.Ball) end
	else
		body = piece("ZombieTorso", Vector3.new(2.8, 3.8, 1.8), Vector3.new(0, 3.5, 0), PURPLE)
		piece("ZombieHead", Vector3.new(2.2, 2.2, 2.2), Vector3.new(0, 6.5, 0), GREEN)
		for _, sign in ipairs({ -1, 1 }) do
			piece("ZombieArm", Vector3.new(1, 3, 1), Vector3.new(sign * 2, 3.5, -1.2), GREEN)
			piece("ZombieLeg", Vector3.new(1.1, 2.3, 1.2), Vector3.new(sign * 0.8, 1.2, 0), Color3.fromRGB(73, 89, 149))
			piece("ZombieEye", Vector3.new(0.4, 0.4, 0.3), Vector3.new(sign * 0.5, 6.7, -1.15), RED)
			piece("ZombieShoe", Vector3.new(1.4, 0.5, 2), Vector3.new(sign * 0.8, 0.3, -0.4), Color3.fromRGB(38, 45, 73))
		end
		piece("ZombieMouth", Vector3.new(1, 0.4, 0.15), Vector3.new(0, 6, -1.15), Color3.fromRGB(35, 49, 57))
		piece("ZombieBrow", Vector3.new(1.8, 0.2, 0.2), Vector3.new(0, 7.05, -1.15), Color3.fromRGB(29, 92, 55))
	end
	emitter(body, kind == "chicken" and GOLD or GREEN, 9, 3, 0.35, 0.6)
	label(s, body, kind == "chicken" and "RUN. IT'S HUNGRY." or "BRAAAINS!", kind == "chicken" and GOLD or GREEN)
	return pieces
end
local function chase(s, kind, position, speed)
	local pieces = npc(s, kind, position)
	local nextRoar = 4
	s:loop(function(elapsed)
		local _, target, distance = nearest(s, position)
		if not target or elapsed < 3 then return end
		if elapsed >= nextRoar then nextRoar = elapsed + 5; s:cue("chase", position, 0.65) end
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
		local falling
		if kind ~= "lightning" then
			falling = s:part(kind == "meteor" and "FallingMeteor" or (kind == "magma" and "LavaBomb" or "FallingBomb"), Vector3.new(4, 4, 4), Vector3.new(position.X - 24, TOP + 62, position.Z - 12), Color3.fromRGB(73, 57, 65), Enum.Material.Slate, Enum.PartType.Ball)
			emitter(falling, kind == "meteor" and Color3.fromRGB(255, 153, 50) or RED, 25, 10, 1.5, 0.5)
			glow(falling, RED, 2.5, 20)
		end
		for frame = 1, 11 do
			if not s:wait(0.2) then return end
			warning.Transparency = frame % 2 == 0 and 0.55 or 0.18
			if falling then
				local alpha = frame / 11
				local start = kind == "magma" and Vector3.new(-105, TOP + 30, 0) or Vector3.new(position.X - 24, TOP + 62, position.Z - 12)
				falling.Position = start:Lerp(Vector3.new(position.X, TOP + 3, position.Z), alpha) + Vector3.new(0, kind == "magma" and math.sin(alpha * math.pi) * 26 or 0, 0)
				falling.CFrame *= CFrame.Angles(0.3, 0.2, 0.4)
			end
		end
		warning:Destroy()
		if falling then falling:Destroy() end
		local effect
		if kind == "lightning" then
			effect = s:part("LightningBolt", Vector3.new(0.8, 60, 0.8), Vector3.new(position.X, TOP + 30, position.Z), GOLD, Enum.Material.Neon)
		else
			effect = s:part(kind == "meteor" and "Meteor" or "BombBlast", Vector3.new(radius * 2, radius * 2, radius * 2), Vector3.new(position.X, TOP + 3, position.Z), kind == "meteor" and Color3.fromRGB(255, 130, 64) or RED, Enum.Material.Neon, Enum.PartType.Ball)
			effect.Transparency = 0.25
		end
		s:area(Vector3.new(position.X, TOP + 4, position.Z), radius, damage, kind == "magma" and 8 or 14, kind)
		if not s:active() then return end
		impact(s, Vector3.new(position.X, TOP + 3, position.Z), radius, kind == "lightning" and GOLD or RED, kind == "lightning" and "storm" or (kind == "magma" and "eruption" or "impact"))
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

local function weapon(s, owner, spec)
	local character = s:character(owner)
	if not character then return function() end end
	local tool = Instance.new("Tool")
	tool.Name = spec.Name
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = spec.Gun and "Equip. Face a survivor, then click / tap to fire." or "Equip. Face a nearby survivor, then click / tap to swing."
	tool:SetAttribute("EventWeapon", true)
	tool:SetAttribute("OwnerUserId", owner.UserId)
	tool:SetAttribute("WeaponKind", spec.Gun and "Blaster" or "Blade")
	tool:SetAttribute("Damage", spec.Damage)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = spec.Gun and Vector3.new(0.6, 1.2, 0.7) or Vector3.new(0.45, 1.25, 0.45)
	handle.Color = Color3.fromRGB(64, 72, 89)
	handle.Material = Enum.Material.Metal
	handle.Massless, handle.CanCollide, handle.CanTouch, handle.CanQuery = true, false, false, false
	handle.Parent = tool
	local function decoration(name, size, offset, color)
		local part = Instance.new("Part")
		part.Name, part.Size, part.Color = name, size, color
		part.Material = Enum.Material.Neon
		part.CFrame = handle.CFrame * CFrame.new(offset)
		part.Massless, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
		part.Parent = tool
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1, weld.Parent = handle, part, part
	end
	if spec.Gun then
		decoration("BlasterBody", Vector3.new(1, 0.85, 2.4), Vector3.new(0, 0.5, -0.8), spec.Color)
		decoration("BlasterBarrel", Vector3.new(0.45, 0.45, 1.1), Vector3.new(0, 0.5, -2.2), GOLD)
		tool.Grip = CFrame.new(0, -0.2, -0.6)
	else
		local length = spec.Knife and 1.9 or 4
		decoration("Blade", Vector3.new(0.55, length, 0.25), Vector3.new(0, length / 2 + 0.65, 0), spec.Color)
		decoration("BladeGuard", Vector3.new(1.7, 0.3, 0.45), Vector3.new(0, 0.6, 0), GOLD)
	end
	local backpack = owner:FindFirstChildOfClass("Backpack")
	tool.Parent = backpack or character
	local readyAt, nextAttack, released = os.clock() + 3, 0, false
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, s.Container }
	params.IgnoreWater = true
	local activation
	activation = tool.Activated:Connect(function()
		-- Equip state, lifetime, identity, aim, range, cooldown and obstruction
		-- are checked on the server. No damage or target comes from the client.
		if released or not s:active() or tool.Parent ~= owner.Character or owner.Character ~= character or os.clock() < readyAt or os.clock() < nextAttack then return end
		local _, _, root = s:character(owner)
		if not root then return end
		nextAttack = os.clock() + spec.Cooldown
		local origin, direction = root.Position + Vector3.new(0, 0.7, 0), root.CFrame.LookVector
		local chosen, chosenRoot, best = nil, nil, spec.Range + 1
		for _, target in ipairs(s:players()) do
			local _, _, targetRoot = s:character(target)
			if target ~= owner and targetRoot and (not spec.Target or spec.Target(target)) then
				local delta = targetRoot.Position + Vector3.new(0, 0.7, 0) - origin
				local distance = delta.Magnitude
				local along = delta:Dot(direction)
				local sideways = (delta - direction * along).Magnitude
				local aimed = spec.Gun and sideways <= 2.8 or (not spec.Gun and along >= distance * 0.35)
				if distance > 0.1 and distance <= spec.Range and along > 0 and aimed and distance < best then
					chosen, chosenRoot, best = target, targetRoot, distance
				end
			end
		end
		local endpoint = origin + direction * spec.Range
		if chosenRoot then
			local targetPoint = chosenRoot.Position + Vector3.new(0, 0.7, 0)
			local obstruction = workspace:Raycast(origin, targetPoint - origin, params)
			if obstruction and not obstruction.Instance:IsDescendantOf(chosen.Character) then
				chosen, chosenRoot, endpoint = nil, nil, obstruction.Position
			else endpoint = targetPoint end
		else
			local obstruction = workspace:Raycast(origin, direction * spec.Range, params)
			if obstruction then endpoint = obstruction.Position end
		end
		local visual = beamPart(s, spec.Gun and "BlasterShot" or "SwordSlash", origin, endpoint, spec.Gun and 0.35 or 0.6, spec.Color)
		s:cue(spec.Gun and "gunshot" or "sword", origin, 0.45)
		s:spawn(function() if s:wait(0.18) then visual:Destroy() end end)
		if chosen and s:character(chosen) then
			s.Context.Damage(chosen, spec.Damage, owner)
			if s:active() and spec.OnHit then spec.OnHit(chosen) end
		end
	end)
	local release = s:resource(owner, character, function()
		released = true
		if activation then activation:Disconnect() end
		tool:Destroy()
	end)
	return release
end

local definitions = {}
local disasterIds = {
	rising_lava = true, meteor_shower = true, zombie_outbreak = true, acid_rain = true,
	tidal_wave = true, lightning_storm = true, falling_bombs = true, earthquake = true,
	tornado = true, volcanic_eruption = true, ufo_invasion = true, kraken_attack = true,
	blizzard = true, meteor_apocalypse = true, flash_flood = true, singularity = true,
}
local reliefIds = { supply_drop = true, moon_gravity = true, speed_frenzy = true, rocket_jump = true }
local pvpIds = { murder_mystery = true, sword_duel = true, free_swords = true, battle_kit = true, blaster_brawl = true }
local cues = {
	rising_lava = "eruption", volcanic_eruption = "eruption", meteor_shower = "impact", meteor_apocalypse = "impact",
	acid_rain = "storm", tidal_wave = "storm", lightning_storm = "storm", earthquake = "impact", tornado = "storm",
	blizzard = "storm", flash_flood = "storm", kraken_attack = "storm", ufo_invasion = "sciFi", singularity = "sciFi",
	chicken_chase = "chase", zombie_outbreak = "chase", cops_robbers = "chase", freeze_tag = "chase",
	murder_mystery = "role", sword_duel = "sword", free_swords = "sword", battle_kit = "supply", blaster_brawl = "gunshot",
}
local themes = {
	rising_lava = "Inferno", volcanic_eruption = "Eruption", meteor_apocalypse = "Eruption",
	acid_rain = "Storm", tidal_wave = "Storm", lightning_storm = "Storm", tornado = "Storm",
	kraken_attack = "Storm", flash_flood = "Storm", blizzard = "Blizzard",
	ufo_invasion = "Alien", singularity = "Alien",
}
local stagedIds = {
	volcanic_eruption = true, ufo_invasion = true, kraken_attack = true,
	blizzard = true, meteor_apocalypse = true, flash_flood = true, singularity = true,
}
local conflicts = {
	cops_robbers = { "roles", "movement" }, hot_potato = { "roles", "event_timer" }, cursed_crown = { "roles" },
	freeze_tag = { "roles", "movement" }, murder_mystery = { "roles", "weapons", "movement" },
	sword_duel = { "roles", "weapons" }, free_swords = { "roles", "weapons" },
	battle_kit = { "roles", "weapons" }, blaster_brawl = { "roles", "weapons" },
	rising_lava = { "waterline", "navigation" }, volcanic_eruption = { "waterline", "navigation" },
	flash_flood = { "waterline", "navigation", "forced_motion" },
	vanishing_islands = { "arena_geometry", "navigation" }, shrinking_islands = { "arena_geometry", "navigation" },
	meteor_apocalypse = { "arena_geometry", "navigation" }, bridge_roulette = { "arena_geometry", "navigation" },
	earthquake = { "arena_geometry", "forced_motion" },
	laser_sweep = { "ground_sweep" }, spinner = { "ground_sweep" }, laser_grid = { "ground_sweep" }, shockwaves = { "ground_sweep" },
	tornado = { "forced_motion" }, singularity = { "forced_motion" }, blizzard = { "forced_motion", "surface_style" },
	ufo_invasion = { "forced_motion" }, tidal_wave = { "forced_motion", "navigation" },
	moon_gravity = { "movement", "forced_motion" }, speed_frenzy = { "movement" },
	rocket_jump = { "movement", "surface_style" }, slippery_islands = { "surface_style" },
}
local visualBudgets = {
	volcanic_eruption = 82, flash_flood = 77, singularity = 66, meteor_apocalypse = 60,
	kraken_attack = 58, ufo_invasion = 58, blizzard = 60, acid_rain = 52,
	rising_lava = 50, tornado = 34, zombie_outbreak = 40, chicken_chase = 20,
	free_swords = 48, blaster_brawl = 48, murder_mystery = 14, battle_kit = 14,
	shockwaves = 75,
}
local function add(id, name, description, duration, callback, minimum, weight, metadata)
	metadata = metadata or {}
	local category = metadata.Category or (pvpIds[id] and "PvP" or (disasterIds[id] and "Disaster" or (reliefIds[id] and "Relief" or "Challenge")))
	table.insert(definitions, {
		Id = id, Name = name, Description = description, Duration = duration,
		MinPlayers = minimum or 1, Weight = weight or 1,
		Category = category,
		Intensity = metadata.Intensity or (duration > 20 and 3 or (category == "Relief" and 1 or 2)),
		Cue = metadata.Cue or cues[id] or (category == "Relief" and "relief" or "warning"),
		Theme = metadata.Theme or themes[id],
		Channel = metadata.Channel or (pvpIds[id] and "PvP" or (category == "Relief" and "Relief" or "ArenaHazard")),
		ConflictKeys = metadata.ConflictKeys or conflicts[id] or {},
		VisualBudget = metadata.VisualBudget or visualBudgets[id] or 30,
		Persistent = metadata.Persistent == true,
		Run = function(context, presser)
			local scope = newScope(context, name)
			local ok, err = pcall(function()
				callback(scope, context, presser)
				if not stagedIds[id] and not metadata.Staged and context.SetStage and scope:active() then context.SetStage("Active", description) end
			end)
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
			toast(c, robber.DisplayName .. " escaped! +35 tokens.", "good")
		end
	end)
end, 2, 1.3)

add("rising_lava", "THE LAVA IS RISING", "Jump between the green escape crates. Low ground burns once the magma reaches the islands.", 18, function(s)
	local lava = s:part("RisingLava", Vector3.new(156, 2, 156), Vector3.new(0, 13, 0), Color3.fromRGB(255, 104, 47), Enum.Material.Neon)
	lava.Transparency = 0.12
	emitter(lava, GOLD, 45, 9, 1, 1.1)
	local bubbles = {}
	for index = 1, 12 do
		local angle = index * math.pi / 6
		local bubble = s:part("LavaBubble", Vector3.new(5, 3, 5), Vector3.new(math.cos(angle) * 42, 13, math.sin(angle) * 42), GOLD, Enum.Material.Neon, Enum.PartType.Ball)
		table.insert(bubbles, bubble)
	end
	for _, platform in ipairs(s.Context.World.Platforms) do escapeCrates(s, platform.Position, GREEN) end
	s:loop(function(elapsed)
		if elapsed < 4 then return end
		local level = math.min(35.5, 16 + (elapsed - 4) * 2.1)
		lava.Position = Vector3.new(0, level - 1, 0)
		for index, bubble in ipairs(bubbles) do bubble.Position = Vector3.new(bubble.Position.X, level - 0.2 + math.sin(elapsed * 3 + index) * 0.7, bubble.Position.Z) end
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
			local safeMarker = marker(s, platforms[index].Position, 8, GREEN, "SafeIsland")
			label(s, safeMarker, "SAFE ISLAND: GET HERE!", GREEN)
			table.insert(markers, safeMarker)
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
				if not protected then s:hit(player, 42, 2, "music") end
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
			if bridge then hideBridge(s, bridge) end
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
	emitter(wave, Color3.fromRGB(219, 251, 255), 55, 14, 0.7, 0.8)
	local foam = {}
	for index = 1, 13 do
		local part = s:part("WaveCrest", Vector3.new(8, 3.5, 14), Vector3.new(-79, TOP + 10, -78 + index * 12), Color3.fromRGB(233, 253, 255), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		table.insert(foam, part)
	end
	s:loop(function(elapsed)
		if elapsed < 4 then return end
		local x = -79 + (elapsed - 4) * 15
		wave.Position = Vector3.new(x, TOP + 4, 0)
		for index, part in ipairs(foam) do part.Position = Vector3.new(x - 1 + math.sin(elapsed * 3 + index), TOP + 9.5, part.Position.Z) end
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

add("greedy_gold", "GREED IS DANGEROUS", "Gold tokens are worth ten each. Red tokens are traps. Collect carefully!", 16, function(s, c)
	local tokens = {}
	for index = 1, 30 do
		local platform = c.World.Platforms[(index - 1) % #c.World.Platforms + 1]
		local fake = index % 4 == 0
		local position = Vector3.new(platform.Position.X + random:NextNumber(-7, 7), TOP + 2.5, platform.Position.Z + random:NextNumber(-7, 7))
		local coin = s:part(fake and "TrapCoin" or "RewardCoin", Vector3.new(0.4, 1.8, 1.8), position, fake and RED or GOLD, Enum.Material.Neon, Enum.PartType.Cylinder)
		coin.Orientation = Vector3.new(0, 0, 90)
		table.insert(tokens, { Part = coin, Fake = fake, Base = position, Collected = false })
	end
	s:loop(function(elapsed)
		for _, coin in ipairs(tokens) do
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

add("supply_drop", "A MOMENT OF MERCY", "Grab a glowing supply crate for healing and tokens. First come, first saved.", 12, function(s, c)
	local crates = {}
	local platforms = shuffled(c.World.Platforms)
	for index = 1, math.min(6, #platforms) do
		local position = platforms[index].Position
		local crate = s:part("SupplyCrate", Vector3.new(3, 3, 3), Vector3.new(position.X, TOP + 2, position.Z), GREEN, Enum.Material.SmoothPlastic)
		label(s, crate, "+35 HP / +15 TOKENS", GREEN)
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
	local stormCloud = s:part("TornadoStormCloud", Vector3.new(28, 11, 28), Vector3.new(0, TOP + 23, 0), Color3.fromRGB(92, 98, 122), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	emitter(stormCloud, Color3.fromRGB(205, 214, 234), 38, 20, 0.7, 0.65, Enum.NormalId.Bottom)
	local debris = {}
	for index = 1, 14 do
		local shard = s:part("TwisterDebris", Vector3.new(1.8, 0.5, 2.6), Vector3.new(0, 45, 0), index % 2 == 0 and Color3.fromRGB(142, 109, 82) or Color3.fromRGB(180, 199, 172), Enum.Material.WoodPlanks)
		table.insert(debris, shard)
	end
	local lastGust = 0
	s:loop(function(elapsed)
		local position = Vector3.new(math.cos(elapsed * 0.48) * 46, TOP, math.sin(elapsed * 0.48) * 46)
		stormCloud.Position = position + Vector3.new(0, 23, 0)
		for index, shard in ipairs(debris) do
			local angle, height = elapsed * (3 + index % 3) + index, 3 + index * 1.1
			shard.CFrame = CFrame.new(position + Vector3.new(math.cos(angle) * (4 + height * 0.33), height, math.sin(angle) * (4 + height * 0.33))) * CFrame.Angles(elapsed * 2, angle, 0.5)
		end
		for index, disc in ipairs(discs) do disc.Position = position + Vector3.new(math.sin(elapsed * 5 + index), index * 2, math.cos(elapsed * 5 + index)) end
		if elapsed < 4 then return end
		if elapsed - lastGust > 5 then lastGust = elapsed; s:cue("storm", position, 0.9) end
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

add("cursed_crown", "THE CURSED CROWN", "The crowned survivor earns tokens while marked. Tag another player to pass the draining curse.", 18, function(s, c)
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
				local data = { Until = os.clock() + 2 }
				frozen[player] = data
				data.Release = s:buff(player, { WalkSpeed = 0, JumpPower = 0, JumpHeight = 0 })
				s.HitTimes["freeze:" .. player.UserId] = os.clock() + 5
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
		for index = 1, count do hideBridge(s, bridges[index]) end
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

add("volcanic_eruption", "VOLCANO: JUMP FOR YOUR LIFE", "Jump up the GREEN crates, then dodge lava-bomb circles from high ground. Magma punishes missed jumps.", 28, function(s, c)
	local volcanic = Color3.fromRGB(84, 62, 67)
	for index = 1, 12 do
		local diameter = 49 - index * 2.8
		local layer = s:part("VolcanoCrag", Vector3.new(3.7, diameter, diameter), Vector3.new(-105, 1 + index * 3.4, 0), volcanic, Enum.Material.Slate, Enum.PartType.Cylinder)
		layer.Orientation = Vector3.new(0, 0, 90)
	end
	local crater = s:part("VolcanoCrater", Vector3.new(1.4, 15, 15), Vector3.new(-105, 43, 0), Color3.fromRGB(255, 139, 54), Enum.Material.Neon, Enum.PartType.Cylinder)
	crater.Orientation = Vector3.new(0, 0, 90)
	emitter(crater, GOLD, 30, 25, 2.2, 1.2)
	glow(crater, RED, 3, 40)
	local plume = s:part("AshPlume", Vector3.new(20, 8, 20), Vector3.new(-105, 61, 0), Color3.fromRGB(88, 79, 89), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	plume.Transparency = 0.4
	emitter(plume, Color3.fromRGB(144, 136, 140), 35, 12, 2.5, 2)
	for _, platform in ipairs(c.World.Platforms) do escapeCrates(s, platform.Position, GREEN) end
	local lava = s:part("VolcanicMagma", Vector3.new(158, 2, 158), Vector3.new(0, 14, 0), Color3.fromRGB(255, 113, 46), Enum.Material.Neon)
	lava.Transparency = 0.2
	emitter(lava, GOLD, 45, 9, 0.8, 1)
	s:phase("THE VOLCANO IS WAKING UP!", "Jump up the GREEN crates. Keep clear of bomb circles.", "eruption", "Warning")
	s:spawn(function()
		if not s:wait(5) then return end
		s:phase("ERUPTION! Lava bombs incoming!", "Dodge the circles. Prepare for rising magma.", "eruption", "Active")
		for wave = 1, 5 do
			local platforms = shuffled(c.World.Platforms)
			for index = 1, 3 do strike(s, platforms[index].Position, 7.5, 32, "magma") end
			if not s:wait(3.5) then return end
		end
	end)
	local finale = false
	s:loop(function(elapsed)
		plume.Position = Vector3.new(-105 + math.sin(elapsed) * 1.5, 61 + math.sin(elapsed * 2), 0)
		if elapsed < 10 then return end
		if not finale then finale = true; s:phase("THE MAGMA IS RISING!", "Stay on the top GREEN crate or a roof. Dodge lava bombs.", "eruption", "Finale") end
		local level = math.min(39, 18 + (elapsed - 10) * 2.2)
		lava.Position = Vector3.new(0, level - 1, 0)
		for _, player in ipairs(s:players()) do
			local _, _, root = s:character(player)
			if root and root.Position.Y < level + 2 then s:hit(player, 20, 1, "volcanoLava") end
		end
	end)
end, 1, 1.5)

add("ufo_invasion", "THEY CAME FOR THE BUTTON", "Leave the green target circles before the UFO's tractor beam activates. Dodge the final laser salvos.", 26, function(s, c)
	local pieces = {}
	local function piece(name, size, offset, color, shape)
		local part = s:part(name, size, Vector3.new(0, 74, 0) + offset, color, Enum.Material.Metal, shape)
		table.insert(pieces, { Part = part, Offset = offset })
		return part
	end
	local saucer = piece("UFOHull", Vector3.new(4, 28, 28), Vector3.zero, Color3.fromRGB(96, 117, 143), Enum.PartType.Cylinder)
	saucer.Orientation = Vector3.new(0, 0, 90)
	-- Cylinder orientation is kept in the piece's local offset frame.
	pieces[1].Rotation = CFrame.Angles(0, 0, math.pi / 2)
	local dome = piece("UFODome", Vector3.new(14, 7, 14), Vector3.new(0, 3, 0), Color3.fromRGB(113, 244, 229), Enum.PartType.Ball)
	dome.Transparency = 0.28
	for index = 1, 12 do
		local angle = index * math.pi / 6
		local light = piece("AlienRimLight", Vector3.new(2.3, 1.1, 2.3), Vector3.new(math.cos(angle) * 12, -1.2, math.sin(angle) * 12), index % 2 == 0 and GREEN or PURPLE, Enum.PartType.Ball)
		light.Material = Enum.Material.Neon
	end
	glow(dome, GREEN, 2, 45)
	local beam = s:part("AlienTractorBeam", Vector3.new(39, 17, 17), Vector3.new(0, 53, 0), GREEN, Enum.Material.Neon, Enum.PartType.Cylinder)
	beam.Orientation = Vector3.new(0, 0, 90)
	beam.Transparency = 1
	local beamPosition, lockTime, targeting, warning = Vector3.zero, 0, false, nil
	local nextLock = 4
	s:phase("A UFO HAS LOCKED ONTO THE ARENA!", "Move away from GREEN targets before the tractor beam activates.", "sciFi", "Warning")
	s:loop(function(elapsed)
		if elapsed >= nextLock and elapsed < 20 then
			local players = s:players()
			if #players > 0 then
				local target = players[random:NextInteger(1, #players)]
				local _, _, root = s:character(target)
				if root then
					if warning then warning:Destroy() end
					beamPosition, lockTime, targeting = Vector3.new(root.Position.X, TOP, root.Position.Z), elapsed, true
					warning = marker(s, beamPosition, 8.5, GREEN, "AlienTarget")
					label(s, warning, "TRACTOR BEAM: MOVE!", GREEN)
					nextLock = elapsed + 6
					s:phase("TRACTOR BEAM LOCKING ON!", "Leave the green target. The beam lifts anyone inside.", "sciFi", "Active")
				end
			end
		end
		local shipPosition = targeting and beamPosition + Vector3.new(0, 45, 0) or Vector3.new(math.sin(elapsed * 0.3) * 42, 76, math.cos(elapsed * 0.3) * 42)
		for _, item in ipairs(pieces) do item.Part.CFrame = CFrame.new(shipPosition + item.Offset) * (item.Rotation or CFrame.new()) end
		local beamActive = targeting and elapsed - lockTime >= 2.2 and elapsed - lockTime < 4.6
		beam.Transparency = beamActive and 0.7 or 1
		beam.Position = beamPosition + Vector3.new(0, 22, 0)
		if targeting and elapsed - lockTime >= 4.6 then targeting = false; if warning then warning:Destroy(); warning = nil end end
		if beamActive then
			for _, player in ipairs(s:players()) do
				local _, _, root = s:character(player)
				if root and flatDistance(root.Position, beamPosition) < 8.5 and root.Position.Y < TOP + 40 then
					root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X * 0.7, 31, root.AssemblyLinearVelocity.Z * 0.7)
					s:hit(player, 12, 1, "alienBeam")
				end
			end
		end
	end)
	s:spawn(function()
		if not s:wait(19) then return end
		s:phase("FINAL LASER SALVO!", "Dodge the yellow laser targets. Stay mobile.", "sciFi", "Finale")
		for _ = 1, 2 do
			for index, player in ipairs(shuffled(s:players())) do
				if index > 3 then break end
				local _, _, root = s:character(player)
				if root then strike(s, root.Position, 5.5, 28, "lightning") end
			end
			if not s:wait(3) then return end
		end
	end)
end, 1, 1.4)

add("kraken_attack", "KRAKEN BELOW!", "The monster marks islands before slamming them. Then jump over its sweeping tentacles or climb a roof.", 27, function(s, c)
	local body = s:part("KrakenHead", Vector3.new(29, 26, 29), Vector3.new(0, 28, -104), Color3.fromRGB(86, 67, 147), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	local face = {}
	for _, sign in ipairs({ -1, 1 }) do
		local eye = s:part("KrakenEye", Vector3.new(6, 6, 2.2), Vector3.new(sign * 6.8, 36, -91), GOLD, Enum.Material.Neon, Enum.PartType.Ball)
		local pupil = s:part("KrakenPupil", Vector3.new(2, 4.5, 2.4), eye.Position + Vector3.new(0, 0, 0.8), Color3.fromRGB(39, 26, 66), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		table.insert(face, { Part = eye, Offset = eye.Position - body.Position })
		table.insert(face, { Part = pupil, Offset = pupil.Position - body.Position })
	end
	label(s, body, "SOMETHING IS VERY WRONG", PURPLE)
	local tentacles = {}
	for index = 1, 6 do
		local segments = {}
		for segment = 1, 5 do
			local part = s:part("KrakenTentacle", Vector3.new(6 - segment * 0.65, 6 - segment * 0.65, 9), Vector3.new(0, 15, -90), Color3.fromRGB(119, 86, 175), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
			table.insert(segments, part)
		end
		table.insert(tentacles, segments)
	end
	local attacking = {}
	s:phase("TENTACLES ARE RISING FROM THE VOID!", "Leave any purple-marked island before the tentacle lands.", "storm", "Warning")
	s:loop(function(elapsed)
		body.Position = Vector3.new(0, 28 + math.sin(elapsed * 1.3) * 2, -104)
		for _, detail in ipairs(face) do detail.Part.Position = body.Position + detail.Offset end
		for index, segments in ipairs(tentacles) do
			if attacking[index] then continue end
			for segment, part in ipairs(segments) do
				local angle = index * math.pi / 3 + segment * 0.1 + elapsed * 0.2
				part.CFrame = CFrame.new(math.cos(angle) * (10 + segment * 5), 10 + segment * 3 + math.sin(elapsed * 2 + segment) * 3, -98 + math.sin(angle) * (10 + segment * 5)) * CFrame.Angles(segment * 0.25, angle, 0)
			end
		end
	end)
	s:spawn(function()
		if not s:wait(4) then return end
		for wave = 1, 3 do
			s:phase("THE KRAKEN IS STRIKING!", "Escape the marked islands. The tentacles crush low ground.", "storm", "Active")
			local platforms = shuffled(c.World.Platforms)
			for index = 1, 2 do
				local target = platforms[index].Position
				local limb = (wave - 1) * 2 + index
				local warning = marker(s, target, 10, PURPLE, "KrakenWarning")
				label(s, warning, "TENTACLE STRIKE!", PURPLE)
				attacking[limb] = true
				s:spawn(function()
					local origin = Vector3.new(target.X * 1.35, TOP - 8, target.Z * 1.35)
					for frame = 1, 12 do
						if not s:wait(0.2) then return end
						local progress = frame / 12
						for segment, part in ipairs(tentacles[limb]) do
							local fraction = segment / 5
							local tip = origin:Lerp(Vector3.new(target.X, TOP + 3 + (1 - progress) * 34, target.Z), fraction)
							part.CFrame = CFrame.new(tip) * CFrame.Angles(0, math.atan2(target.X, target.Z), math.sin(progress * math.pi) * 0.5)
						end
					end
					warning:Destroy()
					s:area(Vector3.new(target.X, TOP + 4, target.Z), 10, 34, 10, "tentacle")
					if not s:active() then return end
					impact(s, Vector3.new(target.X, TOP + 1, target.Z), 10, PURPLE, "impact")
					if not s:wait(1.2) then return end
					attacking[limb] = nil
				end)
			end
			if not s:wait(4.5) then return end
		end
		if not s:active() then return end
		s:phase("TENTACLE SWEEP!", "JUMP over the purple arm or climb a roof!", "warning", "Finale")
		local sweep = s:part("KrakenSweepingTentacle", Vector3.new(148, 2, 2.5), Vector3.new(0, TOP + 1.5, 0), PURPLE, Enum.Material.SmoothPlastic)
		s:loop(function(age)
			sweep.CFrame = CFrame.new(0, TOP + 1.5, 0) * CFrame.Angles(0, age * 0.7, 0)
			if age < 2 then return end
			for _, player in ipairs(s:players()) do
				local _, _, root = s:character(player)
				if root then
					local relative = sweep.CFrame:PointToObjectSpace(root.Position)
					if math.abs(relative.Z) < 3 and math.abs(relative.X) < 74 and relative.Y < 4 then s:hit(player, 25, 1.5, "krakenSweep") end
				end
			end
		end)
	end)
end, 1, 1.4)

add("blizzard", "WHITEOUT", "Reach an ORANGE heat shelter before the cold arrives. Wind gusts push exposed survivors toward the edge.", 26, function(s, c)
	local warm = {}
	for index, platform in ipairs(c.World.Platforms) do
		if index % 2 == 0 then
			local position = platform.Position + Vector3.new(0, 0, -5)
			table.insert(warm, position)
			local roof = s:part("BlizzardShelter", Vector3.new(10, 0.7, 8), Vector3.new(position.X, TOP + 8, position.Z), Color3.fromRGB(237, 250, 255), Enum.Material.Ice)
			for _, offset in ipairs({ -4, 4 }) do s:part("ShelterPost", Vector3.new(0.5, 8, 0.5), Vector3.new(position.X + offset, TOP + 4, position.Z + 3), GOLD) end
			local heater = s:part("WarmHeater", Vector3.new(2, 2, 2), Vector3.new(position.X, TOP + 1.5, position.Z), Color3.fromRGB(255, 156, 77), Enum.Material.Neon)
			glow(heater, GOLD, 3, 16)
			emitter(heater, GOLD, 8, 3, 0.35, 0.8)
			label(s, roof, "WARM SHELTER", GOLD)
			marker(s, position, 6.5, GOLD, "WarmZone")
		end
	end
	for _, part in ipairs(surfaceParts(c)) do s:save(part, { Color = Color3.fromRGB(219, 244, 255), Material = Enum.Material.Snow }) end
	local snowCloud = s:part("BlizzardCloud", Vector3.new(156, 1, 156), Vector3.new(0, 71, 0), Color3.new(1, 1, 1))
	snowCloud.Transparency = 1
	local snow = emitter(snowCloud, Color3.new(1, 1, 1), 120, 22, 0.65, 2.5, Enum.NormalId.Bottom)
	snow.SpreadAngle = Vector2.new(12, 12)
	local streaks = {}
	for index = 1, 18 do
		local streak = s:part("WindStreak", Vector3.new(13, 0.13, 0.13), Vector3.new(-72 + index * 8, TOP + 6 + index % 5, -70 + index * 7), Color3.fromRGB(228, 250, 255), Enum.Material.Neon)
		streak.Transparency = 0.45
		table.insert(streaks, streak)
	end
	s:phase("WHITEOUT APPROACHING!", "Find an ORANGE heat shelter before the cold arrives.", "storm", "Warning")
	local announced, final, lastGust = false, false, -1
	s:loop(function(elapsed)
		local direction = math.floor(elapsed / 6) % 2 == 0 and 1 or -1
		for index, streak in ipairs(streaks) do streak.Position = Vector3.new(((elapsed * 24 * direction + index * 9 + 160) % 160) - 80, TOP + 6 + index % 5, -70 + index * 7) end
		if elapsed < 7 then return end
		if not announced then announced = true; s:phase("THE FREEZE HAS ARRIVED!", "ORANGE shelters stop cold damage and wind gusts.", "storm", "Active") end
		if elapsed >= 18 and not final then final = true; s:phase("TEMPERATURE DROPPING!", "Stay in an ORANGE shelter. The final gusts are brutal.", "storm", "Finale") end
		local gust = math.floor((elapsed - 7) / 5)
		local gusting = (elapsed - 7) % 5 > 2
		if gust ~= lastGust then lastGust = gust; s:cue("storm", Vector3.new(0, TOP, 0), 1) end
		for _, player in ipairs(s:players()) do
			local _, _, root = s:character(player)
			if root then
				local sheltered = false
				for _, position in ipairs(warm) do if flatDistance(root.Position, position) <= 7 and root.Position.Y < TOP + 9 then sheltered = true; break end end
				if not sheltered then
					if gusting then root.AssemblyLinearVelocity += Vector3.new(direction * 2.5, 0, 0) end
					s:hit(player, final and 10 or 7, 1, "frost")
				end
			end
		end
	end)
end, 1, 1.25)

add("meteor_apocalypse", "THE SKY IS BREAKING", "Three marked islands take huge impacts, then crumble. Escape each strike and jump the final shockwave.", 28, function(s, c)
	local asteroid = s:part("ApocalypseAsteroid", Vector3.new(34, 30, 32), Vector3.new(0, TOP + 103, 0), Color3.fromRGB(72, 61, 71), Enum.Material.Slate, Enum.PartType.Ball)
	emitter(asteroid, Color3.fromRGB(255, 164, 78), 40, 24, 2.3, 1)
	local selected = shuffled(c.World.Platforms)
	s:phase("THE SKY IS BREAKING APART!", "Evacuate the marked islands. Impacted islands will crumble.", "impact", "Warning")
	s:spawn(function()
		if not s:wait(3) then return end
		for wave = 1, 3 do
			local platform = selected[wave]
			local position = platform.Position
			local warning = marker(s, position, 12, RED, "ApocalypseTarget")
			label(s, warning, "ISLAND WILL CRUMBLE!", RED)
			s:phase("AN ISLAND HAS BEEN MARKED!", "Leave the marked island NOW. It collapses after impact.", "warning", "Active")
			if not s:wait(3.7) then return end
			warning:Destroy()
			strike(s, position, 11, 45, "meteor")
			if not s:wait(2.6) then return end
			for _, part in ipairs(platform.Parent:GetDescendants()) do
				if part:IsA("BasePart") then s:save(part, { CanCollide = false, Transparency = 0.95 }) end
			end
			local bridge = c.World.Bridges and c.World.Bridges[table.find(c.World.Platforms, platform)]
			if bridge then hideBridge(s, bridge) end
			s:cue("impact", position, 1.5)
		end
	end)
	local startedFinale = false
	local ring = {}
	for index = 1, 20 do
		local segment = s:part("ApocalypseShockwave", Vector3.new(3, 0.7, 4), Vector3.new(0, TOP + 1, 0), GOLD, Enum.Material.Neon)
		segment.Transparency = 1
		table.insert(ring, segment)
	end
	s:loop(function(elapsed)
		asteroid.CFrame = CFrame.new(0, TOP + 103 - math.min(35, elapsed * 1.5), 0) * CFrame.Angles(elapsed * 0.05, elapsed * 0.08, elapsed * 0.03)
		if elapsed < 23 then return end
		if not startedFinale then startedFinale = true; s:phase("FINAL SHOCKWAVE!", "JUMP over the gold ring. Remaining islands stay solid.", "impact", "Finale") end
		local radius = (elapsed - 23) * 20
		for index, segment in ipairs(ring) do
			local angle = index * math.pi * 2 / #ring
			segment.Transparency = radius > 83 and 1 or 0.15
			segment.Size = Vector3.new(2.4, 0.7, math.max(3, radius * 0.34))
			segment.CFrame = CFrame.new(math.cos(angle) * radius, TOP + 1, math.sin(angle) * radius) * CFrame.Angles(0, -angle, 0)
		end
		if radius > 83 then return end
		for _, player in ipairs(s:players()) do
			local _, _, root = s:character(player)
			if root and math.abs(flatDistance(root.Position, Vector3.zero) - radius) < 3.5 and root.Position.Y < TOP + 5 then s:hit(player, 35, 4, "apocalypseRing") end
		end
	end)
end, 1, 1.4)

add("flash_flood", "MONSOON: FLOAT OR FLEE", "Jump onto GREEN crates before water rises. Drifting rafts offer a risky shortcut above the current.", 27, function(s, c)
	for _, platform in ipairs(c.World.Platforms) do escapeCrates(s, platform.Position, GREEN) end
	shower(s, BLUE)
	local water = s:part("FlashFloodWater", Vector3.new(159, 2, 159), Vector3.new(0, 13, 0), Color3.fromRGB(62, 167, 219), Enum.Material.Glass)
	water.Transparency = 0.4
	local rafts = {}
	for index = 1, 6 do
		local angle = index * math.pi / 3
		local raft = s:part("RescueRaft", Vector3.new(13, 1.3, 8), Vector3.new(math.cos(angle) * 37, 17, math.sin(angle) * 37), Color3.fromRGB(218, 166, 102), Enum.Material.WoodPlanks, nil, true)
		label(s, raft, "RESCUE RAFT", GREEN)
		local ring = s:part("RaftBuoy", Vector3.new(0.8, 4, 4), raft.Position + Vector3.new(0, 1, 0), Color3.fromRGB(255, 171, 76), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		ring.Orientation = Vector3.new(0, 0, 90)
		table.insert(rafts, { Part = raft, Buoy = ring, Angle = angle })
	end
	s:phase("MONSOON! HIGH GROUND NOW!", "Jump onto GREEN crates. Floodwater rises after six seconds.", "storm", "Warning")
	local active, final = false, false
	s:loop(function(elapsed)
		local level = math.min(38, 15 + math.max(0, elapsed - 6) * 1.8)
		water.Position = Vector3.new(0, level - 1, 0)
		for _, raft in ipairs(rafts) do
			local angle = raft.Angle + math.max(0, elapsed - 6) * 0.035
			raft.Part.CFrame = CFrame.new(math.cos(angle) * 39, level + 0.9, math.sin(angle) * 39) * CFrame.Angles(0, -angle, math.sin(elapsed * 1.7) * 0.025)
			raft.Buoy.Position = raft.Part.Position + Vector3.new(0, 1.1, 0)
		end
		if elapsed < 6 then return end
		if not active then active = true; s:phase("THE FLOOD IS RISING!", "Jump up the GREEN crates or board a drifting rescue raft.", "storm", "Active") end
		if elapsed >= 18 and not final then final = true; s:phase("THE CURRENT IS STRONGER!", "Stay above water. Rafts and top GREEN crates are safe.", "storm", "Finale") end
		for _, player in ipairs(s:players()) do
			local _, _, root = s:character(player)
			if root and root.Position.Y < level + 1.5 then
				root.AssemblyLinearVelocity += Vector3.new(1.4, 1, 0.7)
				s:hit(player, 16, 1, "flood")
			end
		end
	end)
end, 1, 1.25)

add("singularity", "A HOLE IN THE SKY", "Stand near a GREEN anchor to resist the black hole. Dodge orbiting debris during the final collapse.", 26, function(s, c)
	local core = s:part("SingularityCore", Vector3.new(13, 13, 13), Vector3.new(0, TOP + 19, 0), Color3.fromRGB(10, 12, 30), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	local halo = s:part("SingularityHalo", Vector3.new(0.7, 23, 23), core.Position, PURPLE, Enum.Material.Neon, Enum.PartType.Cylinder)
	halo.Orientation = Vector3.new(0, 0, 90)
	halo.Transparency = 0.4
	glow(halo, PURPLE, 2.5, 50)
	emitter(core, PURPLE, 45, 13, 0.6, 1.2)
	local anchors = {}
	for _, platform in ipairs(c.World.Platforms) do
		local position = platform.Position + Vector3.new(0, 0, -6)
		local anchor = s:part("GravityAnchor", Vector3.new(1.8, 5.5, 1.8), Vector3.new(position.X, TOP + 2.75, position.Z), GREEN, Enum.Material.Neon)
		label(s, anchor, "GRAVITY ANCHOR", GREEN)
		marker(s, position, 6, GREEN, "AnchorSafeZone")
		table.insert(anchors, position)
	end
	local orbit = {}
	for index = 1, 12 do
		local rock = s:part("OrbitalDebris", Vector3.new(3.3, 3.3, 3.3), Vector3.new(0, TOP + 3, 0), Color3.fromRGB(148, 137, 180), Enum.Material.Slate)
		emitter(rock, PURPLE, 3, 2, 0.25, 0.3)
		table.insert(orbit, rock)
	end
	s:phase("THE SKY HAS A HOLE IN IT!", "GREEN anchors protect you from the pull. Find one now.", "sciFi", "Warning")
	local active, finale, lastPulse = false, false, 0
	s:loop(function(elapsed)
		halo.CFrame = CFrame.new(core.Position) * CFrame.Angles(0.18, elapsed * 0.4, math.pi / 2)
		local dangerous = elapsed >= 17
		for index, rock in ipairs(orbit) do
			local angle = elapsed * 0.6 + index * math.pi / 6
			local radius = dangerous and 59 or 35
			rock.CFrame = CFrame.new(math.cos(angle) * radius, TOP + 3 + math.sin(elapsed + index) * 0.6, math.sin(angle) * radius) * CFrame.Angles(elapsed, angle, index)
		end
		if elapsed < 5 then return end
		if not active then active = true; s:phase("THE SINGULARITY IS PULLING!", "Stay beside a GREEN anchor to resist gravity.", "sciFi", "Active") end
		if dangerous and not finale then finale = true; s:phase("ORBITAL DEBRIS INCOMING!", "Keep close to an anchor, but JUMP over passing debris.", "warning", "Finale") end
		if elapsed - lastPulse > 5 then lastPulse = elapsed; s:cue("sciFi", core.Position, 1.2) end
		for _, player in ipairs(s:players()) do
			local _, _, root = s:character(player)
			if root then
				local protected = false
				for _, position in ipairs(anchors) do if flatDistance(root.Position, position) <= 7 then protected = true; break end end
				local delta = Vector3.new(-root.Position.X, 0, -root.Position.Z)
				if not protected and delta.Magnitude > 1 then
					root.AssemblyLinearVelocity += delta.Unit * 2.7 + Vector3.new(0, delta.Magnitude < 17 and 1.2 or 0, 0)
					if delta.Magnitude < 9 then s:hit(player, 12, 1, "singularity") end
				end
				if dangerous then
					for _, rock in ipairs(orbit) do if (root.Position - rock.Position).Magnitude < 4.2 then s:hit(player, 20, 1.3, "orbitalDebris") end end
				end
			end
		end
	end)
end, 1, 1.35)

add("murder_mystery", "ONE KNIFE. ONE SHERIFF.", "A murderer and sheriff hide among the survivors. Equip your gear; face opponents and click or tap. Innocents should escape.", 30, function(s, c)
	local players = shuffled(s:players())
	if #players < 3 then return end
	local murderer, sheriff = players[1], players[2]
	s:phase("CHECK YOUR ROLE. TRUST CAREFULLY.", "Roles are private. Equip your gear, face an opponent, then click or tap.", "warning", "Warning")
	for _, player in ipairs(players) do
		if player == murderer then s:role(player, "Murderer"); s:hint(player, "MURDERER: Equip your knife. Face a nearby survivor; click / tap.")
		elseif player == sheriff then s:role(player, "Sheriff"); s:hint(player, "SHERIFF: Equip your blaster. Face the murderer; click / tap.")
		else s:role(player, "Innocent"); s:hint(player, "INNOCENT: Hide or flee. Survive until the mystery ends.") end
	end
	s:buff(murderer, { WalkSpeed = 24 })
	local releaseKnife = weapon(s, murderer, { Name = "Murderer's Knife", Knife = true, Color = RED, Range = 6.5, Damage = 65, Cooldown = 0.85 })
	local releaseGun = weapon(s, sheriff, { Name = "Sheriff Blaster", Gun = true, Color = BLUE, Range = 90, Damage = 110, Cooldown = 1.35, Target = function(target) return target == murderer end })
	local resolved = false
	s:loop(function(elapsed)
		if resolved or elapsed < 3 then return end
		if not c.IsAlive(murderer) then
			resolved = true
			releaseKnife(); releaseGun()
			s:phase("THE MURDERER HAS BEEN STOPPED!", "The surviving innocents are safe. The next event is coming.", "relief", "Finale")
			for _, player in ipairs(s:players()) do c.Award(player, 12, 0) end
		elseif elapsed >= 29 then
			resolved = true
			for _, player in ipairs(s:players()) do if player ~= murderer then c.Award(player, 15, 0) end end
			s:phase("THE MYSTERY IS OVER!", "Survivors earned a reward. Weapons vanish when the event ends.", "relief", "Finale")
		end
	end)
end, 3, 2.3)

add("sword_duel", "A DUEL OF BAD DECISIONS", "Two survivors get swords. Equip, face your rival and click or tap to swing. Other survivors cannot be hit.", 28, function(s, c, presser)
	local players = shuffled(s:players())
	if #players < 2 then return end
	local first = presser and c.IsAlive(presser) and presser or players[1]
	local second = players[1] == first and players[2] or players[1]
	s:role(first, "Duelist", BLUE); s:role(second, "Duelist", RED)
	s:hint(first, "DUEL: Equip your sword. Face your rival; click / tap to swing.")
	s:hint(second, "DUEL: Equip your sword. Face your rival; click / tap to swing.")
	weapon(s, first, { Name = "Duel Sword", Color = BLUE, Range = 7, Damage = 38, Cooldown = 0.7, Target = function(target) return target == second end })
	weapon(s, second, { Name = "Duel Sword", Color = RED, Range = 7, Damage = 38, Cooldown = 0.7, Target = function(target) return target == first end })
	toast(c, first.DisplayName .. " challenges " .. second.DisplayName .. " to a sword duel!")
	local paid = false
	s:loop(function(elapsed)
		if paid or elapsed < 3 then return end
		if c.IsAlive(first) ~= c.IsAlive(second) then
			paid = true
			c.Award(c.IsAlive(first) and first or second, 20, 0)
		end
	end)
end, 2, 2.1)

add("free_swords", "EVERYONE BROUGHT A SWORD", "Every survivor gets a sword. No teams. Equip, face a nearby opponent, and click or tap to swing.", 28, function(s)
	for _, player in ipairs(s:players()) do
		s:role(player, "Swordfighter")
		s:hint(player, "SWORD BRAWL: Equip your sword. Face a nearby enemy; click / tap.")
		weapon(s, player, { Name = "Chaos Sword", Color = GOLD, Range = 7, Damage = 32, Cooldown = 0.65 })
	end
end, 2, 2.1)

add("battle_kit", "ONE LUCKY ARSENAL", "One random survivor receives a blaster, knife and extra health. Everyone else should use the houses for cover.", 26, function(s, c)
	local players = s:players()
	if #players < 2 then return end
	local chosen = players[random:NextInteger(1, #players)]
	local _, humanoid = s:character(chosen)
	s:role(chosen, "Armed Survivor", PURPLE)
	s:hint(chosen, "BATTLE KIT: Equip blaster or knife. Face your enemy; click / tap.")
	s:buff(chosen, { MaxHealth = humanoid.MaxHealth + 40 })
	humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + 40)
	weapon(s, chosen, { Name = "Gifted Blaster", Gun = true, Color = PURPLE, Range = 85, Damage = 28, Cooldown = 0.8 })
	weapon(s, chosen, { Name = "Gifted Knife", Knife = true, Color = GOLD, Range = 6.5, Damage = 40, Cooldown = 0.75 })
	toast(c, chosen.DisplayName .. " received a battle kit! Houses block blaster shots.")
end, 2, 2)

add("blaster_brawl", "FREE BLASTERS. BAD IDEA.", "Everyone receives a blaster. Equip, face a survivor, then click or tap. Use houses to block incoming shots.", 28, function(s)
	for _, player in ipairs(s:players()) do
		s:role(player, "Blasterfighter")
		s:hint(player, "BLASTER BRAWL: Equip your blaster. Face your enemy; click / tap.")
		weapon(s, player, { Name = "Chaos Blaster", Gun = true, Color = BLUE, Range = 90, Damage = 25, Cooldown = 0.7 })
	end
end, 2, 2.3)

local function randomSurvivor(s)
	local players = s:players()
	return #players > 0 and players[random:NextInteger(1, #players)] or nil
end
local function highlightSurvivor(s, player, color)
	local character = s:character(player)
	if not character then return end
	local highlight = Instance.new("Highlight")
	highlight.Name, highlight.Adornee = "PersonalMark", character
	highlight.FillColor, highlight.OutlineColor, highlight.FillTransparency = color, color, 0.65
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = s.Container
	s:resource(player, character, function() highlight:Destroy() end)
end
local function mutation(kind, text, hint)
	return function(s, c)
		local houses = c.World.Houses or {}
		if #houses == 0 or not c.World.mutateHouse then return end
		local chosen = randomSurvivor(s)
		local house = chosen and c.World.resolveHouse and c.World.resolveHouse(chosen)
		local assigned = chosen and chosen:GetAttribute("HouseIndex")
		house = house or (assigned and houses[assigned]) or houses[random:NextInteger(1, #houses)]
		local index = house.Index
		local owner = chosen and (chosen.DisplayName .. "'s house") or ("House " .. index)
		local warning = marker(s, house.Platform.Position, 11, GOLD, "HouseMutationWarning")
		label(s, warning, "HOUSE CHANGE INCOMING!", GOLD)
		s:phase(text .. " " .. owner, hint .. " This change lasts until the round ends.", "warning", "Warning")
		s:spawn(function()
			if not s:wait(2.5) then return end
			warning:Destroy()
			if c.World.mutateHouse(index, kind) then
				s:cue("impact", house.Platform.Position + Vector3.new(0, 5, 0), 1.2)
				s:phase(owner .. " HAS CHANGED!", hint .. " The button can still cause more chaos.", "warning", "Active")
			end
		end)
	end
end
local mutationMetadata = { Channel = "MapMutation", Category = "Challenge", ConflictKeys = { "house_transform" }, Persistent = true, VisualBudget = 1, Intensity = 2, Staged = true }
add("house_lift", "YOUR HOUSE HAS AN ELEVATOR", "One cottage rises above its island. Get clear of the glowing target before the house moves; use its new ramp for cover.", 12, mutation("lift", "A HOUSE IS ABOUT TO RISE!", "Leave the gold circle while the cottage moves upward."), 1, 1.5, mutationMetadata)
add("house_relocate", "WRONG ADDRESS", "A random cottage moves across its island. Watch the marked house and dodge its new position.", 12, mutation("relocate", "SOMEBODY'S HOUSE IS MOVING!", "Keep clear of the marked cottage until it settles."), 1, 1.5, mutationMetadata)
add("house_shrink", "TINY HOUSE PROBLEM", "A cottage contracts into a cramped shelter. Escape before the gold warning ends, then find another hiding place.", 12, mutation("shrink", "THE HOUSE IS GETTING SMALLER!", "Exit the marked cottage before its walls shrink inward."), 1, 1.3, mutationMetadata)
add("house_tilt", "ARCHITECTURE HAS LEFT THE CHAT", "One cottage tilts sideways. Leave its marked footprint before the shift; the unusual cover remains for this round.", 12, mutation("tilt", "A HOUSE IS LOSING ITS BALANCE!", "Leave the gold circle. The cottage is about to lean sideways."), 1, 1.5, mutationMetadata)
add("house_paint", "PAINTBALL RENOVATION", "One cottage changes into a bright new color scheme. Its strange new look stays until the round ends.", 12, mutation("paint", "SURPRISE RENOVATION!", "The marked house is getting a new paint job."), 1, 0.75, mutationMetadata)

add("iron_survivor", "ONE SURVIVOR IS BUILT DIFFERENT", "A random survivor receives temporary armor and extra health. Everyone can keep pressing the button.", 20, function(s, c)
	local chosen = randomSurvivor(s)
	local _, humanoid = s:character(chosen)
	if not humanoid then return end
	s:buff(chosen, { MaxHealth = humanoid.MaxHealth + 60 })
	humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + 60)
	highlightSurvivor(s, chosen, BLUE)
	s:hint(chosen, "IRON SURVIVOR: +60 armor health for twenty seconds. Stay in the fight.")
	toast(c, chosen.DisplayName .. " just received iron armor!", "good")
	s:cue("supply", chosen.Character.HumanoidRootPart.Position, 0.8)
end, 1, 1.2, { Channel = "Targeted", Category = "Relief", ConflictKeys = { "target_armor" }, VisualBudget = 0, Intensity = 1 })

add("rocket_boots", "ROCKET BOOTS: ONE SIZE", "One survivor gets huge jumps and extra speed. Take shortcuts carefully: a bad landing still eliminates you.", 18, function(s, c)
	local chosen = randomSurvivor(s)
	local _, humanoid, root = s:character(chosen)
	if not root then return end
	s:buff(chosen, { WalkSpeed = math.max(23, humanoid.WalkSpeed), JumpPower = 76, JumpHeight = 13 })
	highlightSurvivor(s, chosen, GREEN)
	s:hint(chosen, "ROCKET BOOTS: Your jumps are much stronger. Aim for solid ground!")
	toast(c, chosen.DisplayName .. " received rocket boots!", "good")
	s:cue("supply", root.Position, 0.8)
end, 1, 1.25, { Channel = "Targeted", Category = "Relief", ConflictKeys = { "target_movement" }, VisualBudget = 0, Intensity = 1 })

add("heavy_feet", "SOMEBODY GOT CONCRETE SHOES", "A random survivor slows down after three seconds. Stay near safety and survive the handicap for a token reward.", 18, function(s, c)
	local chosen = randomSurvivor(s)
	if not chosen then return end
	highlightSurvivor(s, chosen, PURPLE)
	s:hint(chosen, "CONCRETE SHOES: You slow down in three seconds. Reach a safe spot NOW.")
	toast(c, chosen.DisplayName .. " is getting concrete shoes!")
	s:spawn(function()
		if not s:wait(3) or not s:character(chosen) then return end
		s:buff(chosen, { WalkSpeed = 9 })
		s:hint(chosen, "CONCRETE SHOES: Keep moving carefully. Survive to earn fifteen tokens.")
		if s:wait(14) and s:character(chosen) then c.Award(chosen, 15, 0) end
	end)
end, 1, 1.35, { Channel = "Targeted", ConflictKeys = { "target_movement" }, VisualBudget = 0 })

add("hunter_drone", "ONE VERY PERSONAL PROBLEM", "A hunting drone follows one marked survivor. Keep moving: it locks your last position, warns, then explodes there.", 22, function(s, c)
	local chosen = randomSurvivor(s)
	local _, _, target = s:character(chosen)
	if not target then return end
	highlightSurvivor(s, chosen, RED)
	s:hint(chosen, "DRONE TARGET: Keep moving. Leave each red circle before the blast.")
	toast(c, "A hunter drone has chosen " .. chosen.DisplayName .. "!")
	local drone = s:part("HunterDrone", Vector3.new(3.4, 1.5, 3.4), target.Position + Vector3.new(0, 12, 0), PURPLE, Enum.Material.Metal)
	glow(drone, RED, 1, 15)
	local nextAttack = 3
	s:loop(function(elapsed)
		local _, _, root = s:character(chosen)
		if not root then drone.Transparency = 1; return end
		drone.CFrame = CFrame.new(root.Position + Vector3.new(math.sin(elapsed * 2) * 4, 12, math.cos(elapsed * 2) * 4)) * CFrame.Angles(0, elapsed * 2, 0)
		if elapsed < nextAttack then return end
		nextAttack = elapsed + 3.5
		strike(s, root.Position, 6, 36, "bomb")
	end)
end, 1, 1.6, { Channel = "Targeted", Category = "Disaster", ConflictKeys = { "target_hunter" }, VisualBudget = 14, Intensity = 3 })

add("gifted_railgun", "THE BUTTON CHOSE VIOLENCE", "One random survivor receives a powerful rail blaster. Hide behind a house, or close the distance while it reloads.", 24, function(s, c)
	local chosen = randomSurvivor(s)
	if not chosen then return end
	s:hint(chosen, "RAIL BLASTER: Equip, face your target and click / tap. Shots hit hard but reload slowly.")
	weapon(s, chosen, { Name = "Gifted Rail Blaster", Gun = true, Color = GOLD, Range = 105, Damage = 70, Cooldown = 1.8 })
	toast(c, chosen.DisplayName .. " received a rail blaster. Houses block its shots!")
end, 2, 2.2, { Channel = "PvP", Category = "PvP", ConflictKeys = { "weapons" }, VisualBudget = 12, Cue = "gunshot", Intensity = 3 })

add("jackpot_runner", "RUN FOR YOUR MONEY", "One survivor gets a glowing jackpot. They earn tokens by running, but standing still too long hurts.", 20, function(s, c)
	local chosen = randomSurvivor(s)
	local _, _, root = s:character(chosen)
	if not root then return end
	highlightSurvivor(s, chosen, GOLD)
	s:hint(chosen, "JACKPOT RUNNER: Move five studs each second to earn tokens. Standing still burns after three seconds.")
	toast(c, chosen.DisplayName .. " must run for their jackpot!")
	local last, idle, nextCheck = root.Position, 0, 3
	s:loop(function(elapsed)
		local _, _, current = s:character(chosen)
		if not current or elapsed < nextCheck then return end
		nextCheck = elapsed + 1
		if flatDistance(last, current.Position) >= 5 then c.Award(chosen, 3, 0); idle = 0
		else idle += 1; if idle >= 3 then s:hit(chosen, 14, 1, "jackpotIdle") end end
		last = current.Position
	end)
end, 1, 1.6, { Channel = "Targeted", ConflictKeys = { "target_runner" }, VisualBudget = 0, Intensity = 2 })

local personalEffects = {
	{ Id = "tokens", Label = "+8 bonus tokens", Duration = 2, Run = function(s, c, player) c.Award(player, 8, 0) end },
	{ Id = "heal", Label = "+20 health", Duration = 2, Run = function(s, _, player)
		local _, humanoid = s:character(player); if humanoid then humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + 20) end
	end },
	{ Id = "speed", Label = "Turbo legs: +7 speed for 8 seconds", Duration = 8, Run = function(s, _, player)
		local _, humanoid = s:character(player); if humanoid then s:buff(player, { WalkSpeed = humanoid.WalkSpeed + 7 }) end
	end },
	{ Id = "jump", Label = "Spring legs: stronger jumps for 8 seconds", Duration = 8, Run = function(s, _, player)
		local _, humanoid = s:character(player); if humanoid then s:buff(player, { JumpPower = humanoid.JumpPower + 18, JumpHeight = humanoid.JumpHeight + 3 }) end
	end },
	{ Id = "shield", Label = "Lucky shield: protected for 5 seconds", Duration = 5, Run = function(s, _, player)
		local character = s:character(player); if not character then return end
		local shield = Instance.new("ForceField"); shield.Name = "EventPersonalShield"; shield.Parent = character
		s:resource(player, character, function() shield:Destroy() end)
	end },
	{ Id = "slow", Label = "Sticky shoes: slower for 6 seconds", Duration = 6, Run = function(s, _, player)
		local _, humanoid = s:character(player); if humanoid then s:buff(player, { WalkSpeed = math.max(8, humanoid.WalkSpeed - 5) }) end
	end },
	{ Id = "sting", Label = "The button bit you: -8 health", Duration = 2, Run = function(_, c, player) c.Damage(player, 8) end },
	{ Id = "marked", Label = "Glowing target: visible for 7 seconds", Duration = 7, Run = function(s, _, player) highlightSurvivor(s, player, RED) end },
}
-- Every real press has its own small consequence. Root owns expiration and
-- replaces the presser's previous personal scope before creating a new one.
function Events.runPersonal(context, presser)
	if not presser or not context.IsAlive(presser) then return function() end, 0, "" end
	local effect = personalEffects[random:NextInteger(1, #personalEffects)]
	local scope = newScope(context, "Personal_" .. effect.Id)
	local ok, err = pcall(function()
		effect.Run(scope, context, presser)
		if context.PersonalHint and scope:character(presser) then context.PersonalHint(presser, effect.Label, effect.Duration) end
	end)
	if not ok then scope:close(); error(err) end
	return function() scope:close() end, effect.Duration, effect.Label
end

-- Saturating the arena hurts; repeatedly pressing never cancels a warning or
-- removes a running hazard. This pulse has no delayed work or visual objects.
Events.Overload = {
	Id = "button_overload", Name = "BUTTON OVERLOAD",
	Description = "Too much chaos: the button shocks nearby survivors.",
	Category = "Disaster", Channel = "ArenaHazard", ConflictKeys = {}, VisualBudget = 0,
	Intensity = 3, Cue = "impact", Instant = true, Duration = 0.5,
	Run = function(c, presser)
		if c.Active and not c.Active() then return function() end end
		toast(c, "BUTTON OVERLOAD! The button shocks anyone standing nearby.", "bad")
		local button = c.World.Button
		local position = button and button.Position or Vector3.new(0, TOP + 2, 0)
		for _, player in ipairs(c.Players()) do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if c.IsAlive(player) and root and (player == presser or (flatDistance(root.Position, position) <= 18 and math.abs(root.Position.Y - position.Y) <= 12)) then
				c.Damage(player, player == presser and 14 or 10)
			end
		end
		return function() end
	end,
}

Events.Definitions = definitions
function Events.choose(aliveCount, previousId, threatLevel, history, activeDefinitions)
	local recent = history
	if not recent then
		recent = previousId and { { Id = previousId } } or {}
	end
	return Director.select(definitions, aliveCount or 1, threatLevel or 1, recent, random, activeDefinitions)
end
return Events
