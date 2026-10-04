local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local RoundRules = require(Shared.RoundRules)
local Economy = require(Shared.Economy)
local Rules = require(Shared.Rules)
local Director = require(Shared.DisasterDirector)
local AudioCatalog = require(Shared.AudioCatalog)
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
		Context = context, Alive = {}, Entrants = {}, ActiveEvents = {}, PersonalEffects = {}, LastPlayerPress = {}, EventActive = false,
		LastEventId = nil, History = {}, RoundId = 0, EventGeneration = 0, LastPublished = 0, KORecorded = {},
		CueWindow = 0, CueCount = 0,
		State = {
			Phase = "Waiting", PhaseEndsAt = 0, RoundEndsAt = 0, ReadyAt = 0,
			RoundNumber = 0, RoundMode = "Last survivor", EventName = "YOUR NEXT ADVENTURE", EventDescription = "Join the queue. Survive the chaos. Be the last one standing.",
			EventId = "idle", EventStage = "Idle", EventCategory = "", EventIntensity = 0, Presser = "", EventCount = 0, ThreatLevel = 1,
			AliveCount = 0, RoundPlayers = 0, LobbyCount = 0, QueuedCount = 0,
			Roster = {}, ActiveEvents = {}, Winner = "", SuddenDeath = false,
		},
	}, Rounds)
end
function Rounds:cue(kind, position, strength)
	if not self.Context.Remotes.Cue or type(kind) ~= "string" then return end
	kind = string.lower(kind)
	if not AudioCatalog[kind] then return end
	local current = now()
	if current - self.CueWindow >= 1 then self.CueWindow, self.CueCount = current, 0 end
	if self.CueCount >= 6 then return end
	self.CueCount += 1
	self.Context.Remotes.Cue:FireAllClients({ Kind = kind, Position = position, Strength = math.clamp(strength or 0.5, 0, 1), RoundId = self.RoundId })
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
	if self.Context.Remotes.PrivateState then self.Context.Remotes.PrivateState:FireClient(player, { Clear = true, RoundId = self.RoundId }) end
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
	local private = role and table.find({ "Murderer", "Sheriff", "Innocent" }, role) ~= nil
	player:SetAttribute("Role", private and "Survivor" or role or (self:isAlive(player) and "Survivor" or "Lobby"))
	if self.Context.Remotes.PrivateState then self.Context.Remotes.PrivateState:FireClient(player, { Role = private and role or false, RoundId = self.RoundId }) end
	self.Context.RefreshRole(player)
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
		local role = player:GetAttribute("Role") or "Lobby"
		if table.find({ "Murderer", "Sheriff", "Innocent" }, role) then role = "Survivor" end
		table.insert(roster, { UserId = player.UserId, Name = player.DisplayName, Status = player:GetAttribute("Status") or "Lobby", Role = role, Wins = data and data.Wins or 0, KOs = data and data.KOs or 0, Presses = data and data.Presses or 0 })
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
	self.Context.RefreshRole(player)
end
function Rounds:eliminate(player, reason, kill)
	if not self.Alive[player] then return end
	self.Alive[player] = nil
	local record = self.Entrants[player]
	if record and not record.Place then record.Place = #self:players() + 1 end
	if self.Context.Supplies then self.Context.Supplies:clear(player) end
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
local themes = { lava_rise = "Inferno", volcano = "Eruption", volcanic_eruption = "Eruption", blizzard = "Blizzard", lightning = "Storm", acid_rain = "Storm", ufo_invasion = "Alien", meteor_apocalypse = "Inferno", flash_flood = "Storm", singularity = "Cosmic" }
function Rounds:refreshEffects(player)
	if not self:isAlive(player) then return end
	local role, hint, priority, hintPriority = "Survivor", false, -1, -1
	for _, slot in ipairs(self.ActiveEvents) do
		if slot.Active then
			local importance = slot.Definition.Category == "PvP" and 6 or 2
			if slot.Roles[player] and importance >= priority then role, priority = slot.Roles[player], importance end
			if slot.Hints[player] and importance >= hintPriority then hint, hintPriority = slot.Hints[player], importance end
		end
	end
	self:setRole(player, role)
	if self.Context.Remotes.PrivateState then self.Context.Remotes.PrivateState:FireClient(player, { Hint = hint, RoundId = self.RoundId }) end
end
function Rounds:syncEvents()
	local public = {}
	for _, slot in ipairs(self.ActiveEvents) do
		if slot.Active then table.insert(public, { Id = slot.Definition.Id, Name = slot.Definition.Name, EndsAt = slot.EndsAt, Category = slot.Definition.Category, Intensity = slot.Definition.Intensity or 1 }) end
	end
	self.State.ActiveEvents = public
	self.EventActive = #public > 0
	local latest = self.ActiveEvents[#self.ActiveEvents]
	if latest then
		self.State.EventName, self.State.EventDescription, self.State.EventId = latest.Definition.Name, latest.Description, latest.Definition.Id
		self.State.EventStage, self.State.EventCategory, self.State.EventIntensity = latest.Stage, latest.Definition.Category or "Disaster", latest.Definition.Intensity or 1
		self.State.EventEndsAt = latest.EndsAt
	elseif self.State.Phase == "Round" then
		self.State.EventName, self.State.EventDescription, self.State.EventId = "DARE TO PRESS AGAIN?", "+2 tokens, another event, and a mystery effect just for you.", "breather"
		self.State.EventStage, self.State.EventCategory, self.State.EventIntensity = "Cooldown", "", 0
		self.State.EventEndsAt = 0
	end
	local chosen
	for _, slot in ipairs(self.ActiveEvents) do
		if slot.Active and (slot.Definition.Theme or themes[slot.Definition.Id]) then chosen = slot.Definition.Theme or themes[slot.Definition.Id] end
	end
	self.Context.World.theme(chosen or "Normal")
end
function Rounds:finishSlot(slot, reward)
	if not slot.Active then return end
	slot.Active = false
	self:suspendSupplies()
	if slot.Cleanup then
		local ok, err = pcall(slot.Cleanup)
		if not ok then warn("[Survival] Event cleanup: " .. tostring(err)) end
	end
	local index = table.find(self.ActiveEvents, slot)
	if index then table.remove(self.ActiveEvents, index) end
	if slot.PersonalPlayer and self.PersonalEffects[slot.PersonalPlayer] == slot then
		self.PersonalEffects[slot.PersonalPlayer] = nil
		if slot.PersonalPlayer.Parent == Players and self.Context.Remotes.PrivateState then
			self.Context.Remotes.PrivateState:FireClient(slot.PersonalPlayer, { PersonalHint = false, PersonalEndsAt = 0, RoundId = self.RoundId })
		end
	end
	if not slot.PersonalPlayer then
		if reward then for _, player in ipairs(self:players()) do self:award(player, Config.SurvivalTokens) end end
		if #self.ActiveEvents == 0 and self.Context.World.restoreTransientArena then self.Context.World.restoreTransientArena() end
	end
	self:syncEvents()
	for _, player in ipairs(self:players()) do
		self:refreshEffects(player)
		if self.Context.Supplies then self.Context.Supplies:reapply(player) end
	end
end
function Rounds:suspendSupplies()
	if self.Context.Supplies and self.Context.Supplies.suspend then
		for _, player in ipairs(self:players()) do self.Context.Supplies:suspend(player) end
	end
end
function Rounds:clearEvent(reward)
	for _, slot in ipairs(table.clone(self.ActiveEvents)) do self:finishSlot(slot, reward) end
	local personal = {}
	for _, slot in pairs(self.PersonalEffects) do table.insert(personal, slot) end
	for _, slot in ipairs(personal) do self:finishSlot(slot, false) end
	self.Context.World.Effects:ClearAllChildren()
	if self.Context.World.restoreTransientArena then self.Context.World.restoreTransientArena() end
	self.Context.Remotes.Countdown:FireAllClients(-1)
	self:syncEvents()
end
function Rounds:eventContext(slot)
	local roundId = self.RoundId
	local function active() return slot.Active and self.RoundId == roundId and self.State.Phase == "Round" end
	return {
		World = self.Context.World, Data = self.Context.Data, Remotes = self.Context.Remotes,
		State = self.State, RoundId = roundId, Generation = slot.Generation, EventId = slot.Definition.Id,
		Players = function() return self:players() end,
		IsAlive = function(player) return active() and self:isAlive(player) end,
		Active = active,
		Eliminate = function(player, reason) if active() then self:eliminate(player, reason) end end,
		Damage = function(player, amount, attacker)
			if not active() or not self:isAlive(player) then return end
			if type(amount) ~= "number" or amount ~= amount or amount <= 0 or amount == math.huge then return end
			if attacker and (attacker == player or not self:isAlive(attacker)) then return end
			local _, humanoid = living(player)
			local danger = (attacker or slot.PersonalPlayer) and 1 or (1.2 + (self.State.ThreatLevel - 1) * 0.18 + math.max(0, math.min(3, #self.ActiveEvents - 1)) * 0.08)
			humanoid:TakeDamage(math.min(150, amount * danger))
			if humanoid.Health <= 0 and attacker and not self.KORecorded[player] then
				self.KORecorded[player] = true
				local earned = self.Context.Data.knockout(attacker) or 0
				local record = self.Entrants[attacker]
				if record then record.KOs += 1; record.Tokens += earned end
				self:cue("knockout", nil, 0.5)
			end
			if humanoid.Health <= 0 then self:eliminate(player, "The chaos got you! Next round is queued.", false) end
		end,
		Award = function(player, tokens) if active() and self:isAlive(player) then return self:award(player, tokens) end end,
		SetRole = function(player, role)
			if self.RoundId ~= roundId or player.Parent ~= Players or (not active() and role and role ~= "Survivor") then return end
			slot.Roles[player] = role ~= "Survivor" and role or nil
			self:refreshEffects(player)
		end,
		SetHint = function(player, hint)
			if self.RoundId ~= roundId or player.Parent ~= Players or (not active() and hint) then return end
			slot.Hints[player] = hint or nil
			self:refreshEffects(player)
		end,
		PersonalHint = function(player, hint, duration)
			if active() and self:isAlive(player) and self.Context.Remotes.PrivateState then
				self.Context.Remotes.PrivateState:FireClient(player, { PersonalHint = hint or false, PersonalEndsAt = now() + math.clamp(duration or 6, 0, 30), RoundId = roundId })
			end
		end,
		Publish = function() if active() then self:syncEvents(); self:publish() end end,
		Cue = function(kind, position, strength) if active() then self:cue(kind, position, strength) end end,
		SetStage = function(stage, instruction)
			if not active() or type(stage) ~= "string" then return end
			slot.Stage = stage
			if type(instruction) == "string" then slot.Description = instruction end
			self:syncEvents(); self:publish()
		end,
	}
end
function Rounds:personal(presser)
	if not Events.runPersonal or not self:isAlive(presser) then return end
	if self.PersonalEffects[presser] then self:finishSlot(self.PersonalEffects[presser], false) end
	self.EventGeneration += 1
	local slot = { Active = true, PersonalPlayer = presser, Generation = self.EventGeneration, Definition = { Id = "personal" }, Roles = {}, Hints = {} }
	self.PersonalEffects[presser] = slot
	local context = self:eventContext(slot)
	self:suspendSupplies()
	local ok, cleanup, duration, label = xpcall(function() return Events.runPersonal(context, presser) end, debug.traceback)
	if not ok then warn("[Button] Personal effect failed: " .. tostring(cleanup)); self:finishSlot(slot, false); return end
	slot.Cleanup = type(cleanup) == "function" and cleanup or nil
	slot.EndsAt = now() + math.clamp(duration or 6, 0.5, 30)
	if label and self.Context.Remotes.PrivateState then
		self.Context.Remotes.PrivateState:FireClient(presser, { PersonalHint = label, PersonalEndsAt = slot.EndsAt, RoundId = self.RoundId })
	end
	if self.Context.Supplies then for _, player in ipairs(self:players()) do self.Context.Supplies:reapply(player) end end
end
function Rounds:startEvent(presser, previewId)
	if not presser and not previewId then return false end
	if self.State.Phase ~= "Round" or self.State.SuddenDeath then return false end
	local activePlayers = self:players()
	if #activePlayers == 0 then return false end
	if presser then
		if not self:isAlive(presser) then return false end
		local _, humanoid, root = living(presser)
		local readyAt = math.max(self.State.ReadyAt, self.LastPlayerPress[presser] or 0)
		local valid, reason = Rules.canPress(now(), readyAt, root and (root.Position - self.Context.World.Button.Position).Magnitude or math.huge, humanoid ~= nil and humanoid.Health > 0, self.Context.Data.get(presser) ~= nil, Config, true)
		if not valid then self.Context.Remotes.Toast:FireClient(presser, reason, "info"); return false end
	elseif not self.Context.StudioPreview then return false end
	local event
	if previewId then
		if not self.Context.StudioPreview then return false end
		for _, candidate in ipairs(Events.Definitions) do if candidate.Id == previewId and #activePlayers >= candidate.MinPlayers then event = candidate; break end end
	else
		local function choose()
			local definitions = {}
			for _, slot in ipairs(self.ActiveEvents) do table.insert(definitions, slot.Definition) end
			return Events.choose(#activePlayers, self.LastEventId, self.State.ThreatLevel, self.History, definitions)
		end
		event = #self.ActiveEvents >= Config.MaxActiveEvents and Events.Overload or choose()
		if not event then event = Events.Overload end
	end
	if not event then return false end
	if presser then
		Economy.press(self.Context.Data.get(presser))
		self:award(presser, Config.PressTokens)
		self.Context.Data.push(presser)
		self.LastPlayerPress[presser] = now() + Config.PlayerPressCooldown
		if self.Context.Remotes.PrivateState then self.Context.Remotes.PrivateState:FireClient(presser, { PressReadyAt = self.LastPlayerPress[presser], RoundId = self.RoundId }) end
	end
	self.EventGeneration += 1
	local slot = { Active = true, Definition = event, Generation = self.EventGeneration, EndsAt = now() + event.Duration, Stage = "Warning", Description = event.Description, Roles = {}, Hints = {} }
	if not event.Instant then table.insert(self.ActiveEvents, slot) end
	self.State.EventCount += 1
	self.State.ThreatLevel = math.max(self.State.ThreatLevel, math.clamp(1 + math.floor(self.State.EventCount / 3), 1, 5))
	self.State.Presser = presser and presser.DisplayName or "STUDIO PREVIEW"
	self.State.ReadyAt = now() + Config.PressCooldown
	self.LastEventId = event.Id
	Director.remember(self.History, event)
	self.Context.World.press(Color3.fromRGB(255, 82, 103))
	self.Context.PlaySound(presser)
	self:cue(event.Cue or "eventStart", self.Context.World.Button.Position, 0.35)
	self:syncEvents(); self:publish()
	self:suspendSupplies()
	local ok, cleanup = xpcall(function() return event.Run(self:eventContext(slot), presser or activePlayers[1]) end, debug.traceback)
	if ok and type(cleanup) == "function" then slot.Cleanup = cleanup
	elseif not ok then warn("[Survival] Event failed: " .. tostring(cleanup)); self:finishSlot(slot, false) end
	if event.Instant and slot.Active then self:finishSlot(slot, false) end
	if presser then self:personal(presser) end
	if self.Context.Supplies then for _, player in ipairs(self:players()) do self.Context.Supplies:reapply(player) end end
	self:syncEvents(); self:publish()
	return true
end
function Rounds:preview(eventId)
	-- A server-only Studio BindableEvent can replay a hazard for visual testing.
	if not self.Context.StudioPreview or self.State.Phase ~= "Round" or self.State.SuddenDeath or type(eventId) ~= "string" then return false end
	local valid = false
	for _, event in ipairs(Events.Definitions) do if event.Id == eventId and #self:players() >= event.MinPlayers then valid = true; break end end
	if not valid then return false end
	self:clearEvent(false)
	self.State.ReadyAt = now()
	return self:startEvent(nil, eventId)
end
function Rounds:start()
	local eligible = self:eligible()
	if not RoundRules.canStart(#eligible, Config) then self.State.Phase = "Waiting"; self.State.PhaseEndsAt = 0; return end
	self.Context.World.resetArena()
	self.RoundId += 1
	self.Alive, self.Entrants, self.KORecorded = {}, {}, {}
	self.ActiveEvents, self.PersonalEffects, self.LastPlayerPress = {}, {}, {}
	self.State.ActiveEvents = {}
	self.State.RoundNumber += 1
	self.State.Phase = "Round"
	self.State.RoundEndsAt = now() + Config.RoundSeconds
	self.State.PhaseEndsAt = self.State.RoundEndsAt
	self.State.ReadyAt = now() + Config.FirstEventDelay
	self.State.EventCount, self.State.ThreatLevel = 0, 1
	self.State.SuddenDeath, self.State.Winner = false, ""
	self.State.Results = nil
	self.State.EventName = "THE BUTTON IS CALLING"
	self.State.EventDescription = "Each press: +2 tokens, another event, and a personal perk or penalty. Dare to stack the chaos?"
	self.State.EventId = "round_start"
	self.State.EventStage, self.State.EventCategory, self.State.EventIntensity = "Idle", "", 0
	self.LastEventId, self.History = nil, {}
	for index = 1, math.min(#eligible, Config.MaxRoundPlayers) do
		local player = eligible[index]
		local character, humanoid, root = living(player)
		self.Alive[player] = character
		self.Entrants[player] = { UserId = player.UserId, Name = player.DisplayName, Tokens = 0, KOs = 0 }
		if self.Context.Obby then self.Context.Obby:reset(player) end
		player:SetAttribute("QueuedAt", now() + index / 100)
		player:SetAttribute("HouseIndex", index)
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
		if self.Context.Supplies then self.Context.Supplies:grant(player, self.RoundId) end
	end
	self.State.RoundPlayers = #self:players()
	self.State.RoundMode = self.State.RoundPlayers == 1 and "Solo survival" or "Last survivor"
	self:cue("roundStart", nil, 0.1)
	self:publish()
end
function Rounds:award(player, tokens)
	local earned = self.Context.Data.award(player, tokens) or 0
	local record = self.Entrants[player]
	if record then record.Tokens += earned end
	return earned
end
function Rounds:finish(outcome)
	local survivors = self:players()
	local winner = outcome == "Winner" and survivors[1] or nil
	if self.State.EventCount == 0 then outcome, winner = "NoContest", nil end
	self.State.Phase = "Results"
	self.State.PhaseEndsAt = now() + Config.ResultsSeconds
	self.State.Winner = winner and winner.DisplayName .. " WINS!" or (outcome == "SoloSurvived" and "PRACTICE COMPLETE" or (outcome == "NoContest" and "NO BUTTON PRESS — NO CONTEST" or (outcome == "Timeout" and "TIME UP — DRAW" or "NO SURVIVORS")))
	self.State.EventName = self.State.Winner
	self.State.EventDescription = winner and "+60 tokens and +1 win" or (outcome == "SoloSurvived" and "+20 tokens. Multiplayer wins need 2+ players." or "Press the button next round to start an event.")
	self.State.EventStage, self.State.EventCategory, self.State.EventIntensity = "Idle", "", 0
	self:cue(winner and "victory" or "roundend", nil, 0.5)
	self:clearEvent(false)
	self.Context.World.resetArena()
	local rows = {}
	for player, record in pairs(self.Entrants) do
		local survived = (outcome == "Winner" or outcome == "SoloSurvived") and table.find(survivors, player) ~= nil
		if player.Parent == Players then
			local earned = self.Context.Data.finishRound(player, player == winner, survived) or 0
			record.Tokens += earned
			task.spawn(self.Context.Data.save, player, false)
			if self.Context.Supplies then self.Context.Supplies:clear(player) end
			self:setStatus(player, player:GetAttribute("Queued") and "Queued" or "Lobby")
			self:setRole(player, "Lobby")
			self:teleportLobby(player)
		end
		table.insert(rows, { UserId = record.UserId, Name = record.Name, Place = record.Place or (winner == player and 1 or #survivors), Survived = survived, Tokens = record.Tokens, KOs = record.KOs })
	end
	table.sort(rows, function(a, b) if a.Place == b.Place then return a.UserId < b.UserId end; return a.Place < b.Place end)
	self.State.Results = { Outcome = outcome, WinnerUserId = winner and winner.UserId or 0, WinnerName = winner and winner.DisplayName or "", Rows = rows }
	self.Alive, self.Entrants = {}, {}
	self:publish()
end
function Rounds:removed(player)
	if self.PersonalEffects[player] then self:finishSlot(self.PersonalEffects[player], false) end
	self.LastPlayerPress[player] = nil
	if self.Alive[player] then
		self.Alive[player] = nil
		local record = self.Entrants[player]
		if record then record.Place = #self:players() + 1 end
	end
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
function Rounds:tick()
	local state, current = self.State, now()
	if self.Context.Supplies then self.Context.Supplies:update() end
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
		state.ThreatLevel = math.max(RoundRules.threat(Config.RoundSeconds - (state.RoundEndsAt - current), Config), math.clamp(1 + math.floor(state.EventCount / 3), 1, 5))
		local outcome = RoundRules.outcome(#self:players(), state.RoundPlayers, current >= state.RoundEndsAt)
		if outcome ~= "Continue" then self:finish(outcome); return end
		for _, slot in ipairs(table.clone(self.ActiveEvents)) do if current >= slot.EndsAt then self:finishSlot(slot, true) end end
		local expired = {}
		for player, slot in pairs(self.PersonalEffects) do if not self:isAlive(player) or current >= slot.EndsAt then table.insert(expired, slot) end end
		for _, slot in ipairs(expired) do self:finishSlot(slot, false) end
	end
	if current - self.LastPublished >= 0.5 then self:publish() end
end
function Rounds:shutdown()
	self.State.Phase = "Waiting"
	self:clearEvent(false)
	self.Context.World.resetArena()
end
return Rounds
