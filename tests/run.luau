local fs = require("@lune/fs")
local luau = require("@lune/luau")
local Config = require("../src/shared/Config")
local Catalog = require("../src/shared/Catalog")
local Profile = require("../src/shared/Profile")
local Economy = require("../src/shared/Economy")
local Rules = require("../src/shared/Rules")
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
test("Exactly the 99th accepted press triggers the special event", function()
	local remaining = Config.SpecialEvery
	for index = 1, 99 do
		local nextValue, special, duration = Rules.advance(remaining, Config)
		remaining = nextValue
		eq(special, index == 99)
		if special then eq(duration, 30) end
	end
	eq(remaining, 0)
	remaining = Config.SpecialEvery
	local nextValue, special = Rules.advance(remaining, Config); eq(nextValue, 98); eq(special, false)
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
	eq(spawns, 4)
end)
test("World themes restore and counters reflect special events", function()
	local original = world.Floor.Color
	world.theme("Cosmic"); assert(world.Floor.Color ~= original)
	world.theme("Normal"); eq(world.Floor.Color, original)
	world.counter({ Special = false, Remaining = 42, ReadyAt = 0, Cost = 5 })
	assert(world.CounterLabel.Text:find("42")); assert(world.Prompt.ActionText:find("5"))
end)
test("All thirteen events register with unique IDs and valid durations", function()
	local events = environment.load("src/server/Events.luau")
	eq(#events.Definitions, 13)
	local seen = {}
	for _, event in ipairs(events.Definitions) do assert(not seen[event.Id]); seen[event.Id] = true; assert(event.Duration > 0 and type(event.Run) == "function") end
end)
test("Temporary visual events and the special event clean up their world effects", function()
	local events = environment.load("src/server/Events.luau")
	local awardedCoins, awardedPoints = 0, 0
	local context = { World = world, State = {}, Data = { awardAll = function(coins, points) awardedCoins += coins; awardedPoints += points end }, Remotes = { Toast = { FireAllClients = function() end } } }
	for _, event in ipairs(events.Definitions) do
		if table.find({ "chicken", "rain", "coins", "remodel" }, event.Id) then
			local cleanup = event.Run(context)
			assert(#world.Effects:GetChildren() > 0)
			cleanup(); eq(#world.Effects:GetChildren(), 0)
		end
	end
	local cleanup = events.special(context)
	eq(awardedCoins, 100); eq(awardedPoints, 25)
	eq(environment.Workspace.Gravity, 90)
	cleanup(); eq(#world.Effects:GetChildren(), 0); assert(math.abs(environment.Workspace.Gravity - 196.2) < 0.001)
end)
test("Desktop and mobile HUD, shop, and leaderboard use valid UI properties", function()
	local UI = environment.load("src/client/UI.luau")
	local ui = UI.new({ Press = function() end, Shop = function() end, Emote = function() end })
	ui:profile(Profile.new(30), 1, false)
	ui:state({ Remaining = 99, Special = false, EventName = "WAITING", EventDescription = "Press the button", ReadyAt = 0, Cost = 0 })
	for _, size in ipairs({ { 1280, 720 }, { 390, 844 }, { 844, 390 } }) do
		environment.viewport(unpack(size)); ui:resize()
		ui:open("Shop"); ui:renderShop(); assert(ui.Panel.Visible)
		ui:leaders({ { Name = "TestPlayer", Presses = 1234 } }, "GLOBAL")
		ui:open("Leaderboard"); ui:tick(true); ui:close()
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
print("\n" .. passed .. " checks passed. Physics, input, and live DataStores require Studio / a published experience.")
