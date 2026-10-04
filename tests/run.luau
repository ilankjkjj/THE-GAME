local fs = require("@lune/fs")
local luau = require("@lune/luau")
local Config = require("../src/shared/Config")
local Catalog = require("../src/shared/Catalog")
local Profile = require("../src/shared/Profile")
local Economy = require("../src/shared/Economy")
local Rules = require("../src/shared/Rules")
local RoundRules = require("../src/shared/RoundRules")
local Director = require("../src/shared/DisasterDirector")
local AudioCatalog = require("../src/shared/AudioCatalog")
local Environment = require("../scripts/RobloxEnvironment")
local roblox = require("@lune/roblox")
local passed = 0
local function test(name, callback)
	local ok, err = pcall(callback)
	if not ok then error("FAIL: " .. name .. "\n" .. tostring(err)) end
	passed += 1
	print("PASS: " .. name)
end
local function eq(actual, expected) assert(actual == expected, tostring(actual) .. " ~= " .. tostring(expected)) end
local function compileTree(path)
	for _, name in ipairs(fs.readDir(path)) do
		local child = path .. "/" .. name
		if fs.isDir(child) then compileTree(child)
		elseif name:match("%.luau$") then luau.compile(fs.readFile(child)) end
	end
end
test("All production Luau compiles", function() compileTree("src") end)
test("Every shop item has a unique valid ID and category", function()
	local ids = {}
	for _, item in ipairs(Catalog.Items) do
		assert(not ids[item.Id]); ids[item.Id] = true
		assert(table.find(Catalog.Categories, item.Category))
		assert(item.Price >= 0 and item.Price % 1 == 0)
		eq(Catalog.ById[item.Id], item)
	end
end)
test("Presses increase lifetime count without minting tokens", function()
	local data = Profile.new(30); assert(Economy.press(data)); eq(data.Presses, 1); eq(data.Tokens, 30)
end)
test("Every supply purchase charges tokens once and increases consumable stock", function()
	local data = Profile.new(200)
	assert(Economy.purchase(data, "medkit", Catalog)); eq(data.Tokens, 170); eq(data.Inventory.medkit, 1)
	assert(Economy.purchase(data, "medkit", Catalog)); eq(data.Tokens, 140); eq(data.Inventory.medkit, 2)
end)
test("Insufficient funds, unknown supplies and full stacks leave balances unchanged", function()
	local data = Profile.new(0); assert(not Economy.purchase(data, "shield", Catalog)); eq(data.Inventory.shield, nil)
	data.Tokens = 999; data.Inventory.medkit = 5
	assert(not Economy.purchase(data, "medkit", Catalog)); assert(not Economy.purchase(data, "skin_gold", Catalog)); eq(data.Tokens, 999)
end)
test("Only owned consumables can be consumed and counts never become negative", function()
	local data = Profile.new(100); assert(Economy.purchase(data, "soda", Catalog))
	assert(Economy.consume(data, "soda", Catalog)); eq(data.Inventory.soda, nil)
	assert(not Economy.consume(data, "soda", Catalog)); assert(not Economy.consume(data, "fake", Catalog))
end)
test("Nonfinite token awards are rejected and rewards cannot multiply or overflow", function()
	local data = Profile.new(30)
	eq(Economy.award(data, 0/0), 0); eq(Economy.award(data, math.huge), 0); eq(Economy.award(data, -100), 0)
	eq(Economy.award(data, 10.9), 10); eq(data.Tokens, 40)
	data.Tokens = 1e12 - 2; eq(Economy.award(data, 99), 2); eq(data.Tokens, 1e12)
end)
test("Corrupt saves sanitize tokens, counters and consumable inventory", function()
	local data = Profile.normalize({Version=3,Tokens=0/0,Presses=-1,Inventory={medkit=999,soda=-5,shield=math.huge,fake=100}},Catalog,30)
	eq(data.Tokens,30); eq(data.Presses,0); eq(data.Inventory.medkit,5); eq(data.Inventory.soda,nil); eq(data.Inventory.shield,nil); eq(data.Inventory.fake,nil)
end)
test("Version-two balances migrate once while cosmetic ownership is retired", function()
	local old = {Version=2,Coins=200,Points=40,Presses=90,Wins=3,Owned={pet_orb=true},Equipped={Pet="pet_orb"}}
	local data=Profile.normalize(old,Catalog,30)
	eq(data.Version,3); eq(data.Tokens,240); eq(data.Wins,3); eq(data.Presses,90); eq(data.Owned,nil); eq(data.Equipped,nil)
	eq(Profile.normalize(data,Catalog,30).Tokens,240)
end)
test("Save snapshots do not share mutable inventory", function()
	local data=Profile.new(30); data.Inventory.medkit=2; local copy=Profile.copy(data)
	data.Inventory.medkit=1; eq(copy.Inventory.medkit,2)
end)
test("Presses require a loaded, living, nearby player and expired cooldown", function()
	assert(not Rules.canPress(10, 0, 1, true, false, Config))
	assert(not Rules.canPress(10, 0, 1, false, true, Config))
	assert(not Rules.canPress(10, 0, 16, true, true, Config))
	assert(not Rules.canPress(10, 11, 1, true, true, Config))
	assert(Rules.canPress(10, 10, 15, true, true, Config))
end)
test("Rounds distinguish last survivor, a draw, solo completion, and an expired draw", function()
	eq(RoundRules.outcome(3, 5, false), "Continue")
	eq(RoundRules.outcome(1, 5, false), "Winner")
	eq(RoundRules.outcome(0, 5, false), "Draw")
	eq(RoundRules.outcome(1, 1, false), "Continue")
	eq(RoundRules.outcome(1, 1, true), "SoloSurvived")
	eq(RoundRules.outcome(2, 5, true), "Timeout")
end)
test("Lobby readiness and threat progression are bounded", function()
	assert(not RoundRules.canStart(0, Config)); assert(RoundRules.canStart(1, Config))
	eq(RoundRules.threat(0, Config), 1); eq(RoundRules.threat(999, Config), 5)
	eq(RoundRules.status(false, true, false), "Queued")
	eq(RoundRules.status(true, true, false), "Playing")
	assert(not Rules.canPress(10, 0, 1, true, true, Config, false))
end)
test("The disaster director opens with a disaster and excludes the last four events", function()
	local definitions = {
		{ Id = "calm", Category = "Relief", MinPlayers = 1 },
		{ Id = "chase", Category = "Challenge", MinPlayers = 2 },
		{ Id = "volcano", Category = "Disaster", Intensity = 3, MinPlayers = 1 },
		{ Id = "wave", Category = "Disaster", Intensity = 2, MinPlayers = 1 },
		{ Id = "ufo", Category = "Disaster", Intensity = 3, MinPlayers = 1 },
		{ Id = "snow", Category = "Disaster", Intensity = 2, MinPlayers = 1 },
		{ Id = "meteor", Category = "Disaster", Intensity = 3, MinPlayers = 1 },
	}
	local random = { NextNumber = function(_, low) return low end }
	eq(Director.select(definitions, 1, 1, {}, random).Category, "Disaster")
	local history = {}
	for index = 3, 6 do Director.remember(history, definitions[index]) end
	eq(Director.select(definitions, 1, 4, history, random).Id, "calm")
	Director.remember(history, definitions[7]); eq(#history, 4); eq(history[1].Id, "wave")
	assert(Director.select(definitions, 0, 5, history, random) == nil)
	assert(Director.weight(definitions[3], 5, "Challenge") > Director.weight(definitions[3], 1, nil))
	assert(Director.weight(definitions[1], 5, "Relief") < Director.weight(definitions[1], 1, "Disaster"))
end)
test("The event audio catalog uses bounded cues and bundled asset fallbacks", function()
	for _, name in ipairs({ "warning", "eruption", "storm", "scifi", "impact", "roundstart", "roundend", "reward" }) do
		local cue = AudioCatalog[name]; assert(cue)
		assert(cue.SoundId:match("^rbxasset://sounds/"))
		assert(cue.Volume > 0 and cue.Volume <= 0.6 and cue.PlaybackSpeed > 0 and cue.Duration <= 5)
	end
end)
local environment = Environment.new()
local world
test("The room constructs using valid Roblox classes and properties", function()
	world = environment.load("src/server/World.luau").build()
	assert(world.Root and world.Button and world.Prompt and world.Click)
	eq(world.Button.Anchored, true)
	eq(world.Prompt.MaxActivationDistance, Config.PressDistance)
	local spawns = 0
	for _, instance in ipairs(world.Root:GetDescendants()) do if instance:IsA("SpawnLocation") then spawns += 1 end end
	assert(spawns >= 2)
	eq(#world.ArenaSpawns, 12); eq(#world.Platforms, 12)
	assert(world.LobbySpawn.X > 150 and world.JoinPrompt)
end)
test("Classic houses fit players, roof stairs are absent and lobby spawns stay hidden", function()
	local spawns,parts=0,0
	for _, instance in ipairs(world.Root:GetDescendants()) do
		if instance:IsA("BasePart") then parts+=1 end
		assert(not instance.Name:match("RoofStair") and instance.Name~="RoofLookoutDeck")
		if instance:IsA("SpawnLocation") then spawns+=1; eq(instance.Transparency,1); eq(instance.CanCollide,false); eq(instance.CanTouch,false); eq(instance.CanQuery,false) end
	end
	eq(spawns,4); assert(parts<1800)
	for _, platform in ipairs(world.Platforms) do assert(platform.Size.X>=26 and platform.Size.Z>=26) end
	eq(#world.ObbyCheckpoints,10); assert(world.ObbyFinish and world.ObbyStart)
	for index,part in ipairs(world.ObbyCheckpoints) do eq(part:GetAttribute("ObbyOrder"),index); assert(part.CanCollide) end
end)
test("World themes and lobby round displays restore correctly", function()
	local original = world.Floor.Color
	world.theme("Cosmic"); assert(world.Floor.Color ~= original)
	world.theme("Normal"); eq(world.Floor.Color, original)
	world.counter({ Phase = "Round", RoundNumber = 3, AliveCount = 4, RoundPlayers = 12, ReadyAt = 0, QueuedCount = 2 })
	assert(world.RoundLabel.Text ~= "")
	world.counter({ Phase = "Waiting", ReadyAt = 0, QueuedCount = 0, AliveCount = 0 })
	eq(world.Prompt.Enabled, false)
end)
test("All disaster lighting presets restore daylight, atmosphere and original arena colors", function()
	world.theme("Normal")
	local lighting = environment.Services.Lighting
	local clock, brightness, density, haze, tint = lighting.ClockTime, lighting.Brightness, world.Atmosphere.Density, world.Atmosphere.Haze, world.ColorCorrection.TintColor
	local accent = world.Accents[1].Color
	for _, theme in ipairs({ "Storm", "Eruption", "Blizzard", "Alien", "Inferno" }) do
		world.theme(theme); eq(world.Theme, theme); assert(world.Atmosphere.Density > density)
		world.resetArena(); eq(world.Theme, "Normal"); eq(lighting.ClockTime, clock); eq(lighting.Brightness, brightness)
		eq(world.Atmosphere.Density, density); eq(world.Atmosphere.Haze, haze); eq(world.ColorCorrection.TintColor, tint); eq(world.Accents[1].Color, accent)
	end
end)
test("At least twenty-four survival events register with unique IDs and valid durations", function()
	local events = environment.load("src/server/Events.luau")
	assert(#events.Definitions >= 24)
	local seen = {}
	for _, event in ipairs(events.Definitions) do assert(not seen[event.Id]); seen[event.Id] = true; assert(event.Duration > 0 and type(event.Run) == "function") end
end)
test("The live event selector applies disaster metadata and recent-history exclusions", function()
	local events = environment.load("src/server/Events.luau")
	assert(#events.Definitions >= 41)
	for _, event in ipairs(events.Definitions) do
		assert(table.find({ "Disaster", "Challenge", "Relief", "PvP" }, event.Category)); assert(event.Intensity >= 1 and event.Intensity <= 3)
		assert(AudioCatalog[string.lower(event.Cue)], event.Id .. " has no audio cue")
	end
	local history = {}
	for index = 1, 12 do
		local selected = events.choose(1, history[#history] and history[#history].Id, 5, history)
		assert(selected and selected.MinPlayers <= 1)
		if index == 1 then eq(selected.Category, "Disaster") end
		for _, recent in ipairs(history) do assert(selected.Id ~= recent.Id) end
		Director.remember(history, selected)
	end
end)
test("Arena resets restore temporary island changes", function()
	local platform = world.Platforms[1]
	local size, transparency, canCollide = platform.Size, platform.Transparency, platform.CanCollide
	platform.Size = roblox.Vector3.new(5, 3, 5); platform.Transparency = 1; platform.CanCollide = false
	world.resetArena()
	eq(platform.Size, size); eq(platform.Transparency, transparency); eq(platform.CanCollide, canCollide)
end)
test("Desktop and mobile HUD, shop, and leaderboard use valid UI properties", function()
	local UI = environment.load("src/client/UI.luau")
	local ui = UI.new({ Press = function() end, Shop = function() end, Emote = function() end, Queue = function() end, Spectate = function() end })
	ui:profile(Profile.new(30), 1, false)
	ui:state({ Phase = "Intermission", PhaseEndsAt = 115, EventName = "BOARDING", EventDescription = "Join the next round", ReadyAt = 0, AliveCount = 0, LobbyCount = 2, QueuedCount = 2, Roster = { { UserId = 1, Name = "TestPlayer", Status = "Queued", Role = "Lobby", Wins = 3, Presses = 15 } } })
	for _, size in ipairs({ { 1280, 720 }, { 390, 844 }, { 844, 390 } }) do
		environment.viewport(unpack(size)); ui:resize()
		ui:open("Shop"); ui:renderShop(); assert(ui.Panel.Visible)
		ui:leaders({ { Name = "TestPlayer", Wins = 12, Presses = 1234 } }, "GLOBAL WINS")
		ui:open("Leaderboard"); ui:tick(true); ui:close()
		ui:open("Roster"); ui:close()
		eq(ui.Panel.Visible, false)
	end
end)
local kicks = {}
roblox.implementMethod("Player", "Kick", function(player, message) kicks[player.UserId] = message end)
local function dataHarness(studio)
	local env = Environment.new()
	local players = env.Game:GetService("Players")
	local stored, ranks = {}, {}
	local failing = false
	local accesses = 0
	local store = { UpdateAsync = function(_, key, transform)
		accesses += 1
		if failing then error("Simulated store outage") end
		local result = transform(stored[key])
		if result then stored[key] = result end
		return result
	end }
	local ordered = { UpdateAsync = function(_, key, transform) ranks[key] = transform(ranks[key]); return ranks[key] end }
	env.Services.Players = players
	env.Services.DataStoreService = { GetDataStore = function() return store end, GetOrderedDataStore = function() return ordered end }
	env.Services.RunService = { IsStudio = function() return studio == true end }
	env.Services.HttpService = { GenerateGUID = function() return "test-guid" end }
	env.Env.game.JobId = "offline-job"
	local data = env.load("src/server/DataService.luau")
	data.init({ Profile = { FireClient = function() end } })
	local function player(userId)
		local object = roblox.Instance.new("Player")
		object.Name = "TestPlayer" .. userId
		object.UserId = userId
		object.Parent = players
		return object
	end
	return { Data = data, Stored = stored, Ranks = ranks, Kicks = kicks, Player = player,
		Fail = function(value) failing = value end, Accesses = function() return accesses end }
end
test("Live profiles load, save progress, and release their session lease", function()
	local h = dataHarness(); local player = h.Player(101)
	h.Data.load(player)
	local data = h.Data.get(player); assert(data); eq(data.Tokens, 30)
	assert(h.Stored.u_101.Session)
	Economy.press(data, 0, Config, Catalog)
	h.Data.save(player, false)
	eq(h.Stored.u_101.Profile.Presses, 1); eq(h.Ranks["101"], 1)
	h.Data.save(player, true)
	eq(h.Stored.u_101.Session, nil); eq(h.Data.get(player), nil)
end)
test("A fresh foreign session prevents load and leaves existing progress intact", function()
	local h = dataHarness(); local player = h.Player(102)
	local previous = Profile.new(900); previous.Presses = 500
	h.Stored.u_102 = { Profile = previous, Session = { Id = "other-server", UpdatedAt = os.time() } }
	h.Data.load(player)
	eq(h.Data.get(player), nil); assert(h.Kicks[102]); eq(h.Stored.u_102.Profile.Tokens, 900)
	eq(h.Stored.u_102.Session.Id, "other-server")
end)
test("An expired session can be reclaimed without losing the saved profile", function()
	local h = dataHarness(); local player = h.Player(103)
	h.Stored.u_103 = { Profile = Profile.new(99), Session = { Id = "gone-server", UpdatedAt = os.time() - Config.SessionLeaseSeconds - 1 } }
	h.Data.load(player)
	eq(h.Data.get(player).Tokens, 99); eq(h.Stored.u_103.Session.Id, "offline-job:test-guid")
end)
test("An unavailable store does not create or overwrite a live profile", function()
	local h = dataHarness(); local player = h.Player(104)
	h.Stored.u_104 = { Profile = Profile.new(700) }; h.Fail(true)
	h.Data.load(player)
	eq(h.Data.get(player), nil); assert(h.Kicks[104]); eq(h.Stored.u_104.Profile.Tokens, 700)
end)
test("A server that loses its lease cannot overwrite the new owner's data", function()
	local h = dataHarness(); local player = h.Player(105)
	h.Data.load(player); h.Data.get(player).Tokens = 12345
	h.Stored.u_105 = { Profile = Profile.new(88), Session = { Id = "new-owner", UpdatedAt = os.time() } }
	h.Data.save(player, false)
	eq(h.Stored.u_105.Profile.Tokens, 88); eq(h.Data.get(player), nil); assert(h.Kicks[105])
end)
test("Studio practice mode never touches persistent stores", function()
	local h = dataHarness(true); local player = h.Player(106)
	h.Data.load(player); assert(h.Data.get(player))
	h.Data.save(player, true); eq(h.Accesses(), 0); eq(h.Stored.u_106, nil)
end)
test("Wins and practice survival award tokens without cosmetic multipliers", function()
	local h=dataHarness(true);local player=h.Player(107);h.Data.load(player)
	eq(h.Data.finishRound(player,false,true),Config.SoloTokens);eq(h.Data.get(player).Wins,0)
	eq(h.Data.finishRound(player,true,true),Config.WinnerTokens);eq(h.Data.get(player).Wins,1)
	eq(h.Data.get(player).Tokens,30+Config.SoloTokens+Config.WinnerTokens)
	eq(h.Data.knockout(player),Config.KnockoutTokens);eq(h.Data.get(player).KOs,1)
end)
local function roundHarness(count)
	local env = Environment.new()
	local players = env.Game:GetService("Players")
	env.Services.Players = players
	local profiles, outcomes, eventContexts, messages, cues = {}, {}, {}, {}, {}
	local arena = env.load("src/server/World.luau").build()
	local fakeEvent = { Id = "test", Name = "TEST HAZARD", Description = "Test", Duration = 10, MinPlayers = 1,
		Run = function(context) table.insert(eventContexts, context); return function() end end }
	env.Env.script = { Parent = { Events = { choose = function() return fakeEvent end, Definitions = { fakeEvent } } } }
	local data = {
		get = function(player) return profiles[player] end,
		push = function() end,
		award = function(player, tokens) local p = profiles[player]; if p then return Economy.award(p, tokens) end; return 0 end,
		knockout = function(player) local p=profiles[player]; p.KOs+=1; return Economy.award(p,Config.KnockoutTokens) end,
		finishRound = function(player, won, survived) table.insert(outcomes, { Player = player, Won = won, Survived = survived }); return survived and (won and Config.WinnerTokens or Config.SoloTokens) or 0 end,
		save = function() end,
	}
	local remote = { FireAllClients = function() end, FireClient = function(_, _, message) table.insert(messages, message) end }
	local rounds = env.load("src/server/RoundService.luau").new({ World = arena, Data = data,
		Remotes = { State = remote, Toast = remote, Countdown = remote, Cue = { FireAllClients = function(_, payload) table.insert(cues, payload) end } }, RefreshRole = function() end, PlaySound = function() end,
		ArenaTeam = roblox.Instance.new("Team"), LobbyTeam = roblox.Instance.new("Team") })
	local function character(player)
		local model = roblox.Instance.new("Model"); model.Name = player.Name
		local root = roblox.Instance.new("Part"); root.Name = "HumanoidRootPart"; root.CFrame = roblox.CFrame.new(arena.LobbySpawn); root.Position = arena.LobbySpawn; root.Parent = model
		local humanoid = roblox.Instance.new("Humanoid"); humanoid.Health = 100; humanoid.MaxHealth = 100; humanoid.Parent = model
		model.PrimaryPart = root; model.Parent = env.Workspace; player.Character = model
		return model
	end
	local list = {}
	local function add(index)
		local player = roblox.Instance.new("Player"); player.Name = "Player" .. index; player.DisplayName = player.Name; player.UserId = index; player.Parent = players
		profiles[player] = Profile.new(30); character(player); rounds:added(player); table.insert(list, player)
		return player
	end
	for index = 1, count do add(index) end
	return { Env = env, Round = rounds, World = arena, Players = list, Profiles = profiles, Outcomes = outcomes, Contexts = eventContexts, Messages = messages, Cues = cues, Add = add, Character = character }
end
local function pressTestHazard(h)
	h.Env.time(105)
	local player=h.Players[1];player.Character:PivotTo(roblox.CFrame.new(h.World.Button.Position+roblox.Vector3.new(0,4,0)))
	assert(h.Round:startEvent(player))
end
test("Idle rounds never auto-trigger an event or give a free survival award", function()
	local h=roundHarness(1); h.Round:start(); h.Env.time(200); h.Round:tick()
	eq(h.Round.State.EventCount,0); assert(not h.Round.EventActive); assert(not h.Round:startEvent(nil))
	h.Env.time(250);h.Round:tick();eq(h.Round.State.Results.Outcome,"NoContest");eq(h.Outcomes[1].Survived,false)
end)
test("Lobby intermission boards a capped FIFO queue and leaves late arrivals safe", function()
	local h = roundHarness(13)
	h.Round:tick(); eq(h.Round.State.Phase, "Intermission")
	h.Env.time(115); h.Round:tick(); eq(h.Round.State.Phase, "Round")
	eq(h.Round.State.AliveCount, 12); eq(h.Round.State.LobbyCount, 1); eq(h.Round.State.QueuedCount, 1)
	assert(h.Round:isAlive(h.Players[1])); assert(not h.Round:isAlive(h.Players[13]))
	local late = h.Add(14); assert(not h.Round:isAlive(late)); eq(late:GetAttribute("Status"), "Queued")
	assert(late.Character.PrimaryPart.Position.X > 150)
end)
test("Both fallen players are eliminated before a winner can be awarded", function()
	local h = roundHarness(2); h.Round:start()
	for _, player in ipairs(h.Players) do player.Character:PivotTo(roblox.CFrame.new(0, 0, 0)) end
	h.Round:tick(); eq(h.Round.State.Phase, "Results")
	for _, outcome in ipairs(h.Outcomes) do eq(outcome.Won, false); eq(outcome.Survived, false) end
end)
test("Resetting cannot substitute a fresh avatar for the original round life", function()
	local h = roundHarness(3); h.Round:start()
	local player = h.Players[1]
	local old = player.Character; local replacement = h.Character(player)
	assert(not h.Round:isAlive(player)); h.Round:character(player, replacement)
	eq(h.Round.Alive[player], nil); eq(player:GetAttribute("Status"), "Eliminated")
	assert(replacement.PrimaryPart.Position.X > 150)
	old:Destroy()
end)
test("A last survivor earns exactly one win and every entrant returns to the lobby", function()
	local h = roundHarness(2); h.Round:start(); pressTestHazard(h)
	h.Round:eliminate(h.Players[2], "Test elimination")
	h.Round:tick(); eq(h.Round.State.Phase, "Results"); eq(#h.Outcomes, 2)
	local winners = 0
	for _, outcome in ipairs(h.Outcomes) do if outcome.Won then winners += 1; eq(outcome.Player, h.Players[1]) end end
	eq(winners, 1)
	for _, player in ipairs(h.Players) do eq(player:GetAttribute("Status"), "Queued"); eq(player:GetAttribute("InRound"), false) end
end)
test("Solo rounds end with survival rewards rather than a competitive win", function()
	local h = roundHarness(1); h.Round:start(); pressTestHazard(h); h.Env.time(250); h.Round:tick()
	eq(h.Round.State.Phase, "Results"); eq(h.Outcomes[1].Won, false); eq(h.Outcomes[1].Survived, true)
end)
test("Lobby presses, concurrent presses, and callbacks from expired events are rejected", function()
	local h = roundHarness(2); h.Round:start(); h.Env.time(105)
	local visitor = h.Add(3); assert(not h.Round:startEvent(visitor))
	local player = h.Players[1]; player.Character:PivotTo(roblox.CFrame.new(h.World.Button.Position + roblox.Vector3.new(0, 4, 0)))
	assert(h.Round:startEvent(player)); assert(not h.Round:startEvent(player)); eq(h.Profiles[player].Presses, 1)
	local context = h.Contexts[1]; h.Round:clearEvent(false)
	local coins = h.Profiles[player].Tokens; local health = player.Character:FindFirstChildOfClass("Humanoid").Health
	context.Damage(player, 100); context.Award(player, 999, 999); context.Eliminate(player, "Stale job"); context.SetRole(player, "Robber")
	eq(h.Profiles[player].Tokens, coins); eq(player.Character:FindFirstChildOfClass("Humanoid").Health, health); eq(player:GetAttribute("Role"), "Survivor"); assert(h.Round:isAlive(player))
end)
test("Leaving the round immediately removes moon forces and event instructions", function()
	local h = roundHarness(3); h.Round:start(); local player = h.Players[1]
	local attachment = roblox.Instance.new("Attachment"); attachment.Name = "EventMoonAttachment"; attachment.Parent = player.Character.PrimaryPart
	local force = roblox.Instance.new("VectorForce"); force.Name = "EventMoonGravity"; force.Parent = player.Character.PrimaryPart
	player:SetAttribute("EventHint", "Jump!"); player:SetAttribute("EventTimer", 200)
	h.Round:toggleQueue(player)
	eq(force.Parent, nil); eq(attachment.Parent, nil); eq(player:GetAttribute("EventHint"), nil); eq(player:GetAttribute("EventTimer"), nil)
	assert(player.Character.PrimaryPart.Position.X > 150); eq(player:GetAttribute("Queued"), false)
end)
test("Event phases publish instructions while expired jobs cannot emit cues or change phases", function()
	local h = roundHarness(2); h.Round:start(); h.Env.time(105)
	pressTestHazard(h); local context = h.Contexts[1]
	context.SetStage("Finale", "Climb above the lava!")
	eq(h.Round.State.EventStage, "Finale"); eq(h.Round.State.EventDescription, "Climb above the lava!")
	for _ = 1, 20 do context.Cue("impact", roblox.Vector3.new(0, 30, 0), 9) end
	eq(#h.Cues, 7); eq(h.Cues[#h.Cues].Strength, 1)
	h.Round:clearEvent(false); eq(h.Round.State.EventStage, "Cooldown")
	local cueCount = #h.Cues
	context.Cue("impact", nil, 1); context.SetStage("Finale", "Stale instruction")
	eq(#h.Cues, cueCount); eq(h.Round.State.EventStage, "Cooldown")
	h.Env.time(120); h.Round:cue("unrecognized", nil, 1); eq(#h.Cues, cueCount)
end)
test("Deterministic event previews are restricted to Studio and reject unknown hazards", function()
	local h = roundHarness(2); h.Round:start(); h.Env.time(105)
	assert(not h.Round:preview("test")); assert(not h.Round:startEvent(nil, "test")); eq(h.Round.State.EventCount, 0)
	h.Round.Context.StudioPreview = true
	assert(not h.Round:preview("unknown")); eq(h.Round.State.EventCount, 0)
	assert(h.Round:preview("test")); eq(h.Round.State.EventCount, 1); eq(h.Round.State.EventId, "test")
	local old = h.Contexts[1]
	assert(h.Round:preview("test")); eq(h.Round.State.EventCount, 2); assert(not old.Active())
	h.Round.State.SuddenDeath = true; assert(not h.Round:preview("test"))
end)
test("Expired multiplayer rounds draw without starting an automatic storm", function()
	local h=roundHarness(2);h.Round:start();pressTestHazard(h);h.Env.time(250);h.Round:tick()
	eq(h.Round.State.Phase,"Results");eq(h.Round.State.Results.Outcome,"Timeout");eq(h.Round.OvertimeEffects,nil)
	for _,row in ipairs(h.Round.State.Results.Rows) do eq(row.Survived,false) end
end)
test("PvP lethal damage credits one KO and reward, then results list the winner", function()
	local h=roundHarness(2);h.Round:start();pressTestHazard(h)
	local attacker,victim=h.Players[1],h.Players[2]
	local context=h.Contexts[1];context.Damage(victim,100,attacker);context.Damage(victim,100,attacker)
	eq(h.Profiles[attacker].KOs,1);eq(h.Profiles[attacker].Tokens,30+Config.KnockoutTokens)
	h.Round:tick();eq(h.Round.State.Results.WinnerUserId,attacker.UserId)
	eq(h.Round.State.Results.Rows[1].KOs,1);eq(h.Round.State.Results.Rows[1].Tokens,Config.KnockoutTokens+Config.WinnerTokens)
end)
test("Mystery roles and instructions go to their owner without replicated role leaks", function()
	local h=roundHarness(3);h.Round:start();local sent={}
	h.Round.Context.Remotes.PrivateState={FireClient=function(_,player,payload)table.insert(sent,{Player=player,Payload=payload})end}
	h.Round:setRole(h.Players[1],"Murderer");h.Round:setRole(h.Players[2],"Sheriff");h.Round:publish()
	eq(h.Players[1]:GetAttribute("Role"),"Survivor");eq(h.Players[2]:GetAttribute("Role"),"Survivor")
	eq(sent[1].Player,h.Players[1]);eq(sent[1].Payload.Role,"Murderer")
	pressTestHazard(h); h.Contexts[1].SetHint(h.Players[1],"MURDERER: stay hidden")
	eq(h.Players[1]:GetAttribute("EventHint"),nil)
	eq(sent[#sent].Player,h.Players[1]);eq(sent[#sent].Payload.Hint,"MURDERER: stay hidden")
	for _,row in ipairs(h.Round.State.Roster) do assert(row.Role~="Murderer" and row.Role~="Sheriff") end
end)
print("\n" .. passed .. " checks passed. Physics, input, and live DataStores require Studio / a published experience.")
