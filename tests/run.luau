local fs = require("@lune/fs")
local luau = require("@lune/luau")
local Config = require("../src/shared/Config")
local Catalog = require("../src/shared/Catalog")
local Profile = require("../src/shared/Profile")
local Economy = require("../src/shared/Economy")
local Rules = require("../src/shared/Rules")
local RoundRules = require("../src/shared/RoundRules")
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
test("A free press awards exactly one point, one press, and two coins", function()
	local data = Profile.new(30)
	assert(Economy.press(data, 0, Config, Catalog))
	eq(data.Points, 1); eq(data.Presses, 1); eq(data.Coins, 32)
end)
test("A rejected taxed press changes nothing", function()
	local data = Profile.new(4)
	assert(not Economy.press(data, 5, Config, Catalog))
	eq(data.Coins, 4); eq(data.Presses, 0); eq(data.Points, 0)
end)
test("A taxed press charges once and still gives rewards", function()
	local data = Profile.new(5)
	assert(Economy.press(data, 5, Config, Catalog))
	eq(data.Coins, 2); eq(data.Points, 1)
end)
test("Insufficient points cannot purchase or equip an item", function()
	local data = Profile.new(30)
	assert(not Economy.purchase(data, "skin_gold", Catalog))
	eq(data.Points, 0); eq(data.Owned.skin_gold, nil); eq(data.Equipped.Skin, "skin_classic")
end)
test("Purchases charge once; re-equipping an owned item is free", function()
	local data = Profile.new(30); data.Points = 130
	assert(Economy.purchase(data, "skin_gold", Catalog))
	eq(data.Points, 30); eq(data.Equipped.Skin, "skin_gold")
	assert(Economy.purchase(data, "skin_gold", Catalog)); eq(data.Points, 30)
end)
test("Forged item and category requests leave the economy unchanged", function()
	local data = Profile.new(30); data.Points = 100
	assert(not Economy.purchase(data, "free_admin_coins", Catalog))
	assert(not Economy.unequip(data, "Coins", Catalog))
	eq(data.Points, 100); eq(data.Coins, 30)
end)
test("Multipliers use the highest owned tier and never stack", function()
	local data = Profile.new(0)
	data.Owned.boost_2 = true; data.Owned.boost_3 = true
	eq(Economy.multiplier(data, Catalog), 3)
	eq(Economy.awardCoins(data, 10, Catalog), 30); eq(data.Coins, 30)
	assert(Economy.press(data, 5, Config, Catalog)); eq(data.Coins, 31)
end)
test("Unequip resets skins and removes optional cosmetics", function()
	local data = Profile.new(30); data.Equipped.Skin = "skin_gold"; data.Equipped.Pet = "pet_orb"
	assert(Economy.unequip(data, "Skin", Catalog)); eq(data.Equipped.Skin, "skin_classic")
	assert(Economy.unequip(data, "Pet", Catalog)); eq(data.Equipped.Pet, nil)
	assert(not Economy.unequip(data, "Multiplier", Catalog))
end)
test("Corrupt and nonfinite save values are sanitized", function()
	local data = Profile.normalize({ Coins = 0/0, Points = math.huge, Presses = -10, Owned = "invalid", Equipped = false }, Catalog, 30)
	eq(data.Coins, 30); eq(data.Points, 0); eq(data.Presses, 0); eq(data.Owned.skin_classic, true)
end)
test("Unknown items, unowned equips, and category mismatches are dropped", function()
	local data = Profile.normalize({ Owned = { fake = true, pet_orb = true }, Equipped = { Skin = "skin_gold", Title = "pet_orb", Pet = "pet_orb" } }, Catalog, 30)
	eq(data.Owned.fake, nil); eq(data.Equipped.Skin, "skin_classic"); eq(data.Equipped.Title, nil); eq(data.Equipped.Pet, "pet_orb")
end)
test("Save snapshots do not share mutable ownership or equipment", function()
	local data = Profile.new(30); local snapshot = Profile.copy(data)
	data.Owned.pet_orb = true; data.Equipped.Pet = "pet_orb"
	eq(snapshot.Owned.pet_orb, nil); eq(snapshot.Equipped.Pet, nil)
end)
test("Presses require a loaded, living, nearby player and expired cooldown", function()
	assert(not Rules.canPress(10, 0, 1, true, false, Config))
	assert(not Rules.canPress(10, 0, 1, false, true, Config))
	assert(not Rules.canPress(10, 0, 16, true, true, Config))
	assert(not Rules.canPress(10, 11, 1, true, true, Config))
	assert(Rules.canPress(10, 10, 15, true, true, Config))
end)
test("Rounds distinguish last survivor, a draw, solo completion, and sudden death", function()
	eq(RoundRules.outcome(3, 5, false), "Continue")
	eq(RoundRules.outcome(1, 5, false), "Winner")
	eq(RoundRules.outcome(0, 5, false), "Draw")
	eq(RoundRules.outcome(1, 1, false), "Continue")
	eq(RoundRules.outcome(1, 1, true), "SoloSurvived")
	eq(RoundRules.outcome(2, 5, true), "SuddenDeath")
end)
test("Lobby readiness and threat progression are bounded", function()
	assert(not RoundRules.canStart(0, Config)); assert(RoundRules.canStart(1, Config))
	eq(RoundRules.threat(0, Config), 1); eq(RoundRules.threat(999, Config), 5)
	eq(RoundRules.status(false, true, false), "Queued")
	eq(RoundRules.status(true, true, false), "Playing")
	assert(not Rules.canPress(10, 0, 1, true, true, Config, false))
end)
test("Existing version-one saves migrate without losing progress or ownership", function()
	local old = Profile.new(999); old.Version = 1; old.Wins = nil; old.Rounds = nil
	old.Owned.pet_chicken = true; old.Equipped.Pet = "pet_chicken"; old.Presses = 45
	local data = Profile.normalize(old, Catalog, 30)
	eq(data.Wins, 0); eq(data.Rounds, 0); eq(data.Presses, 45); eq(data.Coins, 999)
	eq(data.Equipped.Pet, "pet_chicken"); eq(data.Version, 2)
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
test("World themes and lobby round displays restore correctly", function()
	local original = world.Floor.Color
	world.theme("Cosmic"); assert(world.Floor.Color ~= original)
	world.theme("Normal"); eq(world.Floor.Color, original)
	world.counter({ Phase = "Round", RoundNumber = 3, AliveCount = 4, RoundPlayers = 12, ReadyAt = 0, QueuedCount = 2 })
	assert(world.RoundLabel.Text ~= "")
	world.counter({ Phase = "Waiting", ReadyAt = 0, QueuedCount = 0, AliveCount = 0 })
	eq(world.Prompt.Enabled, false)
end)
test("At least twenty-four survival events register with unique IDs and valid durations", function()
	local events = environment.load("src/server/Events.luau")
	assert(#events.Definitions >= 24)
	local seen = {}
	for _, event in ipairs(events.Definitions) do assert(not seen[event.Id]); seen[event.Id] = true; assert(event.Duration > 0 and type(event.Run) == "function") end
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
	local data = h.Data.get(player); assert(data); eq(data.Coins, 30)
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
	eq(h.Data.get(player), nil); assert(h.Kicks[102]); eq(h.Stored.u_102.Profile.Coins, 900)
	eq(h.Stored.u_102.Session.Id, "other-server")
end)
test("An expired session can be reclaimed without losing the saved profile", function()
	local h = dataHarness(); local player = h.Player(103)
	h.Stored.u_103 = { Profile = Profile.new(99), Session = { Id = "gone-server", UpdatedAt = os.time() - Config.SessionLeaseSeconds - 1 } }
	h.Data.load(player)
	eq(h.Data.get(player).Coins, 99); eq(h.Stored.u_103.Session.Id, "offline-job:test-guid")
end)
test("An unavailable store does not create or overwrite a live profile", function()
	local h = dataHarness(); local player = h.Player(104)
	h.Stored.u_104 = { Profile = Profile.new(700) }; h.Fail(true)
	h.Data.load(player)
	eq(h.Data.get(player), nil); assert(h.Kicks[104]); eq(h.Stored.u_104.Profile.Coins, 700)
end)
test("A server that loses its lease cannot overwrite the new owner's data", function()
	local h = dataHarness(); local player = h.Player(105)
	h.Data.load(player); h.Data.get(player).Coins = 12345
	h.Stored.u_105 = { Profile = Profile.new(88), Session = { Id = "new-owner", UpdatedAt = os.time() } }
	h.Data.save(player, false)
	eq(h.Stored.u_105.Profile.Coins, 88); eq(h.Data.get(player), nil); assert(h.Kicks[105])
end)
test("Studio practice mode never touches persistent stores", function()
	local h = dataHarness(true); local player = h.Player(106)
	h.Data.load(player); assert(h.Data.get(player))
	h.Data.save(player, true); eq(h.Accesses(), 0); eq(h.Stored.u_106, nil)
end)
test("Competitive wins are saved; solo survival never farms competitive wins", function()
	local h = dataHarness(true); local player = h.Player(107)
	h.Data.load(player)
	h.Data.finishRound(player, false, true)
	eq(h.Data.get(player).Wins, 0); eq(h.Data.get(player).Rounds, 1)
	eq(h.Data.get(player).Coins, 70); eq(h.Data.get(player).Points, 8)
	h.Data.finishRound(player, true, true)
	eq(h.Data.get(player).Wins, 1); eq(h.Data.get(player).Rounds, 2)
	eq(h.Data.get(player).Coins, 190); eq(h.Data.get(player).Points, 28)
end)
local function roundHarness(count)
	local env = Environment.new()
	local players = env.Game:GetService("Players")
	env.Services.Players = players
	local profiles, outcomes, eventContexts, messages = {}, {}, {}, {}
	local arena = env.load("src/server/World.luau").build()
	local fakeEvent = { Id = "test", Name = "TEST HAZARD", Description = "Test", Duration = 10,
		Run = function(context) table.insert(eventContexts, context); return function() end end }
	env.Env.script = { Parent = { Events = { choose = function() return fakeEvent end } } }
	local data = {
		get = function(player) return profiles[player] end,
		push = function() end,
		award = function(player, coins, points) local p = profiles[player]; if p then Economy.awardCoins(p, coins, Catalog); p.Points += points or 0 end end,
		finishRound = function(player, won, survived) table.insert(outcomes, { Player = player, Won = won, Survived = survived }) end,
		save = function() end,
	}
	local remote = { FireAllClients = function() end, FireClient = function(_, _, message) table.insert(messages, message) end }
	local rounds = env.load("src/server/RoundService.luau").new({ World = arena, Data = data,
		Remotes = { State = remote, Toast = remote, Countdown = remote }, RefreshCosmetics = function() end, PlaySound = function() end,
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
	return { Env = env, Round = rounds, World = arena, Players = list, Profiles = profiles, Outcomes = outcomes, Contexts = eventContexts, Messages = messages, Add = add, Character = character }
end
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
	local h = roundHarness(2); h.Round:start()
	h.Round:eliminate(h.Players[2], "Test elimination")
	h.Round:tick(); eq(h.Round.State.Phase, "Results"); eq(#h.Outcomes, 2)
	local winners = 0
	for _, outcome in ipairs(h.Outcomes) do if outcome.Won then winners += 1; eq(outcome.Player, h.Players[1]) end end
	eq(winners, 1)
	for _, player in ipairs(h.Players) do eq(player:GetAttribute("Status"), "Queued"); eq(player:GetAttribute("InRound"), false) end
end)
test("Solo rounds end with survival rewards rather than a competitive win", function()
	local h = roundHarness(1); h.Round:start(); h.Env.time(250); h.Round:tick()
	eq(h.Round.State.Phase, "Results"); eq(h.Outcomes[1].Won, false); eq(h.Outcomes[1].Survived, true)
end)
test("Lobby presses, concurrent presses, and callbacks from expired events are rejected", function()
	local h = roundHarness(2); h.Round:start(); h.Env.time(105)
	local visitor = h.Add(3); assert(not h.Round:startEvent(visitor))
	local player = h.Players[1]; player.Character:PivotTo(roblox.CFrame.new(h.World.Button.Position + roblox.Vector3.new(0, 4, 0)))
	assert(h.Round:startEvent(player)); assert(not h.Round:startEvent(player)); eq(h.Profiles[player].Presses, 1)
	local context = h.Contexts[1]; h.Round:clearEvent(false)
	local coins = h.Profiles[player].Coins; local health = player.Character:FindFirstChildOfClass("Humanoid").Health
	context.Damage(player, 100); context.Award(player, 999, 999); context.Eliminate(player, "Stale job"); context.SetRole(player, "Robber")
	eq(h.Profiles[player].Coins, coins); eq(player.Character:FindFirstChildOfClass("Humanoid").Health, health); eq(player:GetAttribute("Role"), "Survivor"); assert(h.Round:isAlive(player))
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
test("Overtime warns before damage and a player can dodge a storm strike", function()
	local h = roundHarness(2); h.Round:start(); h.Env.time(250); h.Round:tick()
	assert(h.Round.State.SuddenDeath); eq(h.Round.State.Phase, "Round")
	for _, player in ipairs(h.Players) do eq(player.Character:FindFirstChildOfClass("Humanoid").Health, 100) end
	local ring = h.Round.OvertimeEffects:FindFirstChild("StormWarning"); assert(ring)
	for _, player in ipairs(h.Players) do player.Character:PivotTo(roblox.CFrame.new(ring.Position + roblox.Vector3.new(30, 4, 0))) end
	h.Env.Delayed[#h.Env.Delayed]()
	for _, player in ipairs(h.Players) do eq(player.Character:FindFirstChildOfClass("Humanoid").Health, 100) end
	h.Env.time(310); h.Round:tick(); eq(h.Round.State.Phase, "Results")
	for _, outcome in ipairs(h.Outcomes) do eq(outcome.Won, false); eq(outcome.Survived, false) end
end)
print("\n" .. passed .. " checks passed. Physics, input, and live DataStores require Studio / a published experience.")
