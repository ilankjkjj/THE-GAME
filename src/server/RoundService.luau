local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local RoundRules = require(Shared.RoundRules)
local Catalog = require(Shared.Catalog)
local Economy = require(Shared.Economy)
local Rules = require(Shared.Rules)
local Events = require(script.Parent.Events)
local Rounds = {}
Rounds.__index = Rounds
local function now() return workspace:GetServerTimeNow() end
local function living(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return character, humanoid, root
end
function Rounds.new(context)
	return setmetatable({
		Context = context, Alive = {}, Entrants = {}, EventCleanup = nil, EventActive = false,
		NextAutoAt = 0, LastEventId = nil, RoundId = 0, EventGeneration = 0, LastPublished = 0, LastOvertime = 0,
		State = {
			Phase = "Waiting", PhaseEndsAt = 0, RoundEndsAt = 0, ReadyAt = 0,
			RoundNumber = 0, RoundMode = "Last survivor", EventName = "YOUR NEXT ADVENTURE", EventDescription = "Join the queue. Survive the chaos. Be the last one standing.",
			EventId = "idle", Presser = "", EventCount = 0, ThreatLevel = 1,
			AliveCount = 0, RoundPlayers = 0, LobbyCount = 0, QueuedCount = 0,
			Roster = {}, Winner = "", SuddenDeath = false,
		},
	}, Rounds)
end
function Rounds:isAlive(player)
	if self.State.Phase ~= "Round" or not self.Alive[player] or player.Parent ~= Players then return false end
	if player.Character ~= self.Alive[player] then return false end
	local _, humanoid = living(player)
	return humanoid ~= nil and humanoid.Health > 0
end
function Rounds:clearCharacterEffects(player)
	player:SetAttribute("EventHint", nil)
	player:SetAttribute("EventTimer", nil)
	local character, humanoid = living(player)
	if character then
		for _, item in ipairs(character:GetDescendants()) do
			if item.Name == "EventMoonGravity" or item.Name == "EventMoonAttachment" then item:Destroy() end
		end
	end
	if humanoid then
		humanoid.WalkSpeed = Config.BaseWalkSpeed
		humanoid.JumpPower = Config.BaseJumpPower
		humanoid.JumpHeight = Config.BaseJumpHeight
		humanoid.AutoRotate = true
	end
end
function Rounds:players()
	local result = {}
	for player in pairs(self.Alive) do if self:isAlive(player) then table.insert(result, player) end end
	table.sort(result, function(a, b) return a.UserId < b.UserId end)
	return result
end
function Rounds:setStatus(player, status)
	player:SetAttribute("Status", status)
	player:SetAttribute("InRound", status == "Playing")
	player.Team = status == "Playing" and self.Context.ArenaTeam or self.Context.LobbyTeam
	player.Neutral = false
	local stats = player:FindFirstChild("leaderstats")
	if stats and stats:FindFirstChild("Status") then stats.Status.Value = status end
end
function Rounds:setRole(player, role)
	player:SetAttribute("Role", role or (self:isAlive(player) and "Survivor" or "Lobby"))
	self.Context.RefreshCosmetics(player)
end
function Rounds:teleportLobby(player)
	self:clearCharacterEffects(player)
	local character, humanoid, root = living(player)
	if not root then return end
	character:PivotTo(CFrame.new(self.Context.World.LobbySpawn + Vector3.new(math.random(-8, 8), 0, math.random(-5, 5))))
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	if humanoid then
		humanoid.WalkSpeed = Config.BaseWalkSpeed
		humanoid.JumpPower = Config.BaseJumpPower
		humanoid.AutoRotate = true
	end
end
function Rounds:publish()
	local roster, lobby, queued = {}, 0, 0
	for _, player in ipairs(Players:GetPlayers()) do
		local data = self.Context.Data.get(player)
		local inRound = self:isAlive(player)
		if not inRound then lobby += 1 end
		if data and not inRound and player:GetAttribute("Queued") then queued += 1 end
		table.insert(roster, { UserId = player.UserId, Name = player.DisplayName, Status = player:GetAttribute("Status") or "Lobby", Role = player:GetAttribute("Role") or "Lobby", Wins = data and data.Wins or 0, Presses = data and data.Presses or 0 })
	end
	table.sort(roster, function(a, b)
		if (a.Status == "Playing") ~= (b.Status == "Playing") then return a.Status == "Playing" end
		if a.Wins == b.Wins then return a.UserId < b.UserId end
		return a.Wins > b.Wins
	end)
	self.State.Roster = roster
	self.State.LobbyCount = lobby
	self.State.QueuedCount = queued
	self.State.AliveCount = #self:players()
	self.Context.World.counter(self.State)
	self.Context.Remotes.State:FireAllClients(table.clone(self.State))
	self.LastPublished = now()
end
function Rounds:added(player)
	player:SetAttribute("Queued", true)
	player:SetAttribute("QueuedAt", now())
	self:setStatus(player, "Queued")
	self:setRole(player, "Lobby")
	self:teleportLobby(player)
	self:publish()
end
function Rounds:character(player, character)
	-- Forfeit the old life before waiting for the replacement avatar to load.
	if self.Alive[player] and self.Alive[player] ~= character then self:eliminate(player, "You reset your character.", false) end
	local humanoid = character:WaitForChild("Humanoid", 10)
	character:WaitForChild("HumanoidRootPart", 10)
	if player.Character ~= character then return end
	if not self:isAlive(player) then self:teleportLobby(player) end
	if humanoid then
		humanoid.Died:Connect(function()
			if player.Character == character then self:eliminate(player, "Eliminated. Your next round is queued!", false) end
		end)
	end
	self.Context.RefreshCosmetics(player)
end
function Rounds:eliminate(player, reason, kill)
	if not self.Alive[player] then return end
	self.Alive[player] = nil
	self:setStatus(player, "Eliminated")
	self:setRole(player, "Spectator")
	self:clearCharacterEffects(player)
	self.Context.Remotes.Toast:FireClient(player, reason or "Eliminated! Watch the survivors or wait for the next round.", "info")
	local _, humanoid = living(player)
	if kill ~= false and humanoid and humanoid.Health > 0 then humanoid.Health = 0 end
	self:publish()
end
function Rounds:toggleQueue(player)
	if not self.Context.Data.get(player) then return end
	local queued = not player:GetAttribute("Queued")
	player:SetAttribute("Queued", queued)
	if queued then player:SetAttribute("QueuedAt", now()) end
	if self.Alive[player] then self:eliminate(player, "You returned to the lobby.", false); self:teleportLobby(player) end
	self:setStatus(player, queued and "Queued" or "Lobby")
	self:setRole(player, "Lobby")
	self.Context.Remotes.Toast:FireClient(player, queued and "You're queued for the next round!" or "Queue paused. Explore the lobby or spectate.", "good")
	self:publish()
end
function Rounds:eligible()
	local result = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local _, humanoid, root = living(player)
		if self.Context.Data.get(player) and player:GetAttribute("Queued") and humanoid and humanoid.Health > 0 and root then table.insert(result, player) end
	end
	table.sort(result, function(a, b)
		local first, second = a:GetAttribute("QueuedAt") or 0, b:GetAttribute("QueuedAt") or 0
		return first == second and a.UserId < b.UserId or first < second
	end)
	return result
end
function Rounds:clearEvent(reward)
	self.EventGeneration += 1
	if self.EventCleanup then
		local ok, err = pcall(self.EventCleanup)
		if not ok then warn("[Survival] Event cleanup: " .. tostring(err)) end
	end
	self.EventCleanup = nil
	self.EventActive = false
	self.Context.World.Effects:ClearAllChildren()
	self.Context.World.resetArena()
	self.Context.World.theme("Normal")
	self.Context.Remotes.Countdown:FireAllClients(-1)
	for _, player in ipairs(Players:GetPlayers()) do self:clearCharacterEffects(player) end
	for _, player in ipairs(self:players()) do
		self:setRole(player, "Survivor")
		local _, humanoid = living(player)
		if humanoid then humanoid.WalkSpeed = Config.BaseWalkSpeed; humanoid.JumpPower = Config.BaseJumpPower; humanoid.AutoRotate = true end
		if reward then self.Context.Data.award(player, Config.SurvivalCoins, Config.SurvivalPoints) end
	end
	self.State.ReadyAt = now() + Config.EventGap
	self.NextAutoAt = now() + Config.AutoEventSeconds
end
function Rounds:startEvent(presser)
	if self.State.Phase ~= "Round" or self.State.SuddenDeath or self.EventActive or now() < self.State.ReadyAt then return false end
	local activePlayers = self:players()
	if #activePlayers == 0 then return false end
	local event = Events.choose(#activePlayers, self.LastEventId, self.State.ThreatLevel)
	if not event then return false end
	if presser then
		if not self:isAlive(presser) then return false end
		local _, humanoid, root = living(presser)
		local valid, reason = Rules.canPress(now(), self.State.ReadyAt, root and (root.Position - self.Context.World.Button.Position).Magnitude or math.huge, humanoid ~= nil and humanoid.Health > 0, self.Context.Data.get(presser) ~= nil, Config, true)
		if not valid then self.Context.Remotes.Toast:FireClient(presser, reason, "info"); return false end
		Economy.press(self.Context.Data.get(presser), 0, Config, Catalog)
		self.Context.Data.push(presser)
	end
	self.EventActive = true
	self.EventGeneration += 1
	self.State.EventCount += 1
	self.State.EventName, self.State.EventDescription, self.State.EventId = event.Name, event.Description, event.Id
	self.State.Presser = presser and presser.DisplayName or "THE ARENA"
	self.State.ReadyAt = now() + event.Duration
	self.LastEventId = event.Id
	local roundId = self.RoundId
	local generation = self.EventGeneration
	local function active()
		return self.RoundId == roundId and self.State.Phase == "Round" and self.EventActive and self.EventGeneration == generation
	end
	local context = {
		World = self.Context.World, Data = self.Context.Data, Remotes = self.Context.Remotes,
		State = self.State, RoundId = roundId,
		Players = function() return self:players() end,
		IsAlive = function(player) return active() and self:isAlive(player) end,
		Active = active,
		Eliminate = function(player, reason) if active() then self:eliminate(player, reason) end end,
		Damage = function(player, amount)
			if not active() or not self:isAlive(player) then return end
			local _, humanoid = living(player)
			humanoid:TakeDamage(amount)
			if humanoid.Health <= 0 then self:eliminate(player, "The event got you! Next round is queued.", false) end
		end,
		Award = function(player, coins, points) if active() and self:isAlive(player) then return self.Context.Data.award(player, coins, points) end end,
		SetRole = function(player, role) if active() and player.Parent == Players then self:setRole(player, role) end end,
		Publish = function() if active() then self:publish() end end,
	}
	local skin = presser and Catalog.ById[self.Context.Data.get(presser).Equipped.Skin] or Catalog.ById.skin_classic
	self.Context.World.press(Color3.fromRGB(unpack(skin.Color)))
	self.Context.PlaySound(presser)
	self:publish()
	local ok, cleanup = xpcall(function() return event.Run(context, presser or activePlayers[1]) end, debug.traceback)
	if ok and type(cleanup) == "function" then self.EventCleanup = cleanup
	elseif not ok then warn("[Survival] Event failed: " .. tostring(cleanup)); self:clearEvent(false) end
	self:publish()
	return true
end
function Rounds:start()
	local eligible = self:eligible()
	if not RoundRules.canStart(#eligible, Config) then self.State.Phase = "Waiting"; self.State.PhaseEndsAt = 0; return end
	self.Context.World.resetArena()
	self.RoundId += 1
	self.Alive, self.Entrants = {}, {}
	if self.OvertimeEffects then self.OvertimeEffects:Destroy(); self.OvertimeEffects = nil end
	self.State.RoundNumber += 1
	self.State.Phase = "Round"
	self.State.RoundEndsAt = now() + Config.RoundSeconds
	self.State.PhaseEndsAt = self.State.RoundEndsAt
	self.State.ReadyAt = now() + Config.FirstEventDelay
	self.State.EventCount, self.State.ThreatLevel = 0, 1
	self.State.SuddenDeath, self.State.Winner = false, ""
	self.State.EventName = "SURVIVE THE ISLANDS"
	self.State.EventDescription = "The button starts the next hazard. Stay alive to earn rewards!"
	self.State.EventId = "round_start"
	self.LastEventId = nil
	self.NextAutoAt = self.State.ReadyAt + Config.AutoEventSeconds
	for index = 1, math.min(#eligible, Config.MaxRoundPlayers) do
		local player = eligible[index]
		local character, humanoid, root = living(player)
		self.Alive[player], self.Entrants[player] = character, true
		player:SetAttribute("QueuedAt", now() + index / 100)
		self:setStatus(player, "Playing")
		self:setRole(player, "Survivor")
		humanoid.Health = humanoid.MaxHealth
		humanoid.WalkSpeed, humanoid.JumpPower = Config.BaseWalkSpeed, Config.BaseJumpPower
		humanoid.UseJumpPower = true
		humanoid.JumpHeight = Config.BaseJumpHeight
		for _, child in ipairs(character:GetChildren()) do if child:IsA("ForceField") then child:Destroy() end end
		character:PivotTo(CFrame.new(self.Context.World.ArenaSpawns[index]))
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
	self.State.RoundPlayers = #self:players()
	self.State.RoundMode = self.State.RoundPlayers == 1 and "Solo survival" or "Last survivor"
	self:publish()
end
function Rounds:finish(outcome)
	local survivors = self:players()
	local winner = survivors[1]
	self.State.Phase = "Results"
	self.State.PhaseEndsAt = now() + Config.ResultsSeconds
	self.State.Winner = outcome == "Winner" and (winner.DisplayName .. " wins!") or (outcome == "SoloSurvived" and "SOLO SURVIVAL COMPLETE!" or (outcome == "Timeout" and "STORM DRAW • NO WINNER" or "NO SURVIVORS. THE BUTTON WINS."))
	self.State.EventName = self.State.Winner
	self.State.EventDescription = outcome == "Winner" and "+120 base coins • +20 points • +1 win" or (outcome == "SoloSurvived" and "+40 base coins • +8 points. Competitive wins need 2+ players." or "Your next chance is coming up.")
	self:clearEvent(false)
	if self.OvertimeEffects then self.OvertimeEffects:Destroy(); self.OvertimeEffects = nil end
	for player in pairs(self.Entrants) do
		if player.Parent == Players then
			local survived = (outcome == "Winner" or outcome == "SoloSurvived") and table.find(survivors, player) ~= nil
			self.Context.Data.finishRound(player, outcome == "Winner" and player == winner, survived)
			task.spawn(self.Context.Data.save, player, false)
			self:setStatus(player, player:GetAttribute("Queued") and "Queued" or "Lobby")
			self:setRole(player, "Lobby")
			self:teleportLobby(player)
		end
	end
	self.Alive, self.Entrants = {}, {}
	self:publish()
end
function Rounds:removed(player)
	self.Alive[player] = nil
	self.Entrants[player] = nil
end
function Rounds:checkBounds()
	-- Remove dead, replaced, and fallen avatars before deciding the winner.
	for _, player in ipairs(Players:GetPlayers()) do
		local _, humanoid, root = living(player)
		if self.Alive[player] then
			if not self:isAlive(player) or not root then self:eliminate(player, "Your life ended. Next round is queued!", false)
			elseif root.Position.Y < 6 or root.Position.Y > 150 or math.abs(root.Position.X) > 100 or math.abs(root.Position.Z) > 100 then self:eliminate(player, "You left the survival arena!") end
		elseif root and humanoid and humanoid.Health > 0 and (root.Position.Y < -10 or root.Position.X < 150 or root.Position.X > 290 or math.abs(root.Position.Z) > 65) then
			self:teleportLobby(player)
		end
	end
end
function Rounds:overtime(current)
	if not self.State.SuddenDeath then
		self:clearEvent(false)
		self.State.SuddenDeath = true
		self.State.EventName = "SUDDEN DEATH • STORM STRIKES"
		self.State.EventDescription = "Move out of the coral warning rings! Storm strikes get wider until one survivor remains."
		self.State.EventId = "overtime"
		self.State.ReadyAt = self.State.RoundEndsAt + Config.OvertimeSeconds
		self.OvertimeEffects = Instance.new("Folder")
		self.OvertimeEffects.Name = "OvertimeStorm"
		self.OvertimeEffects.Parent = self.Context.World.Root
		self.LastOvertime = current - 2
	end
	if current - self.LastOvertime < 2 then return end
	self.LastOvertime = current
	local players = self:players()
	if #players == 0 then return end
	local _, _, root = living(players[math.random(1, #players)])
	local position = root.Position
	local radius = math.min(20, 8 + (current - self.State.RoundEndsAt) / 5)
	local ring = self.Context.World.part(self.OvertimeEffects, "StormWarning", Vector3.new(0.2, radius * 2, radius * 2), Vector3.new(position.X, 30.3, position.Z), Color3.fromRGB(255, 101, 111), Enum.Material.Neon, Enum.PartType.Cylinder)
	ring.Orientation = Vector3.new(0, 0, 90)
	ring.CanCollide, ring.CanTouch, ring.Transparency = false, false, 0.35
	local roundId = self.RoundId
	task.delay(1.2, function()
		if self.RoundId ~= roundId or self.State.Phase ~= "Round" or not self.State.SuddenDeath or not ring.Parent then return end
		local bolt = self.Context.World.part(self.OvertimeEffects, "StormStrike", Vector3.new(2, 110, 2), Vector3.new(position.X, 65, position.Z), Color3.fromRGB(255, 241, 167), Enum.Material.Neon)
		bolt.CanCollide, bolt.CanTouch = false, false
		for _, player in ipairs(self:players()) do
			local _, humanoid, avatar = living(player)
			local distance = Vector3.new(avatar.Position.X - position.X, 0, avatar.Position.Z - position.Z).Magnitude
			if distance <= radius then
				humanoid:TakeDamage(65)
				if humanoid.Health <= 0 then self:eliminate(player, "The storm caught you!", false) end
			end
		end
		ring:Destroy()
		task.delay(0.25, function() if bolt.Parent then bolt:Destroy() end end)
	end)
end
function Rounds:tick()
	local state, current = self.State, now()
	self:checkBounds()
	if state.Phase == "Waiting" then
		if RoundRules.canStart(#self:eligible(), Config) then
			state.Phase = "Intermission"
			state.PhaseEndsAt = current + Config.IntermissionSeconds
			state.EventName = "NEXT ROUND IS BOARDING"
			state.EventDescription = "Stay queued to enter. Browse the shop or practice in the lobby."
		end
	elseif state.Phase == "Intermission" then
		if not RoundRules.canStart(#self:eligible(), Config) then state.Phase = "Waiting"; state.PhaseEndsAt = 0
		elseif current >= state.PhaseEndsAt then self:start() end
	elseif state.Phase == "Results" then
		if current >= state.PhaseEndsAt then state.Phase = "Waiting"; state.PhaseEndsAt = 0 end
	elseif state.Phase == "Round" then
		state.ThreatLevel = RoundRules.threat(Config.RoundSeconds - (state.RoundEndsAt - current), Config)
		local outcome = RoundRules.outcome(#self:players(), state.RoundPlayers, current >= state.RoundEndsAt)
		if outcome == "Winner" or outcome == "Draw" or outcome == "SoloSurvived" then self:finish(outcome); return end
		if outcome == "SuddenDeath" then
			if current >= state.RoundEndsAt + Config.OvertimeSeconds then self:finish("Timeout"); return end
			self:overtime(current)
		end
		if state.SuddenDeath then -- The storm owns overtime; regular events resume next round.
		elseif self.EventActive and current >= state.ReadyAt then self:clearEvent(true)
		elseif not self.EventActive and current >= self.NextAutoAt then self:startEvent(nil) end
	end
	if current - self.LastPublished >= 0.5 then self:publish() end
end
function Rounds:shutdown()
	self.State.Phase = "Waiting"
	self:clearEvent(false)
	if self.OvertimeEffects then self.OvertimeEffects:Destroy(); self.OvertimeEffects = nil end
end
return Rounds
