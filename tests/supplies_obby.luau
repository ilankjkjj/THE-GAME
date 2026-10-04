-- Server supply and lobby-obstacle checks use real Luau and Roblox instances.
-- A virtual clock checks expiry and rewards; Studio still owns actual physics.
local Environment = require("../scripts/RobloxEnvironment")
local roblox = require("@lune/roblox")
local Config = require("../src/shared/Config")
local Catalog = require("../src/shared/Catalog")
local Profile = require("../src/shared/Profile")
local passed = 0
local function test(name, callback)
	local ok, err = pcall(callback)
	if not ok then error("FAIL: " .. name .. "\n" .. tostring(err)) end
	passed += 1
	print("PASS: " .. name)
end
local function eq(actual, expected)
	assert(actual == expected, tostring(actual) .. " ~= " .. tostring(expected))
end

local function harness(inventory)
	local env = Environment.new()
	local players = env.Game:GetService("Players")
	env.Services.Players = players
	local current = 100
	env.Env.task.delay = function(seconds, callback)
		table.insert(env.Delayed, { Due = current + seconds, Callback = callback })
	end
	local function avatar(name)
		local character = roblox.Instance.new("Model")
		character.Name, character.Parent = name, env.Workspace
		local humanoid = roblox.Instance.new("Humanoid")
		humanoid.Health, humanoid.MaxHealth = 100, 100
		humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight = Config.BaseWalkSpeed, Config.BaseJumpPower, Config.BaseJumpHeight
		humanoid.UseJumpPower = true
		humanoid.Parent = character
		local root = roblox.Instance.new("Part")
		root.Name, root.Size = "HumanoidRootPart", roblox.Vector3.new(2, 2, 1)
		root.Position, root.Parent = roblox.Vector3.new(0, 34, 0), character
		character.PrimaryPart = root
		return character, humanoid, root
	end
	local player = roblox.Instance.new("Player")
	player.Name, player.UserId, player.Parent = "SupplyTester", 781, players
	player:SetAttribute("InRound", true)
	local character, humanoid, root = avatar(player.Name)
	player.Character = character
	local backpack = roblox.Instance.new("Backpack")
	backpack.Parent = player
	local data = Profile.new(Config.StartingTokens)
	data.Inventory = table.clone(inventory or {})
	local loaded, pushes, awardTotal = true, 0, 0
	local toasts, cues = {}, {}
	local service = {
		get = function(subject) return subject == player and loaded and data or nil end,
		push = function(subject) eq(subject, player); pushes += 1 end,
		award = function(subject, amount) eq(subject, player); data.Tokens += amount; awardTotal += amount end,
	}
	local remotes = {
		Toast = { FireClient = function(_, subject, text, kind) eq(subject, player); table.insert(toasts, { Text = text, Kind = kind }) end },
		Cue = { FireClient = function(_, subject, cue) eq(subject, player); table.insert(cues, cue) end },
	}
	local h = { Env = env, Player = player, Character = character, Humanoid = humanoid, Root = root, Backpack = backpack, Data = data, Service = service, Remotes = remotes, Toasts = toasts, Cues = cues }
	function h.clock(value) current = value; env.time(value) end
	function h.advance(seconds)
		local target = current + seconds
		while true do
			local index, due
			for key, job in ipairs(env.Delayed) do
				if job.Due <= target and (not due or job.Due < due) then index, due = key, job.Due end
			end
			if not index then break end
			local job = table.remove(env.Delayed, index)
			current = job.Due; env.time(current)
			job.Callback()
		end
		current = target; env.time(current)
	end
	function h.tool(id)
		for _, parent in ipairs({ player.Character, backpack }) do
			for _, child in ipairs(parent:GetChildren()) do if child:IsA("Tool") and child:GetAttribute("SupplyId") == id then return child end end
		end
	end
	function h.equip(id)
		local tool = assert(h.tool(id), "missing supply tool " .. id)
		tool.Parent = player.Character
		return tool
	end
	function h.replaceCharacter()
		local replacement, newHumanoid, newRoot = avatar("ReplacementAvatar")
		player.Character = replacement
		return replacement, newHumanoid, newRoot
	end
	function h.setLoaded(value) loaded = value end
	function h.pushCount() return pushes end
	function h.awardTotal() return awardTotal end
	function h.now() return current end
	h.clock(current)
	h.Supplies = env.load("src/server/Supplies.luau").new(service, remotes)
	return h
end

test("Catalog has four consumables with five-unit stock limits", function()
	eq(#Catalog.Items, 4)
	for _, id in ipairs({ "medkit", "soda", "spring", "shield" }) do
		local item = assert(Catalog.ById[id])
		eq(item.MaxStock, 5); assert(item.Price > 0)
	end
end)

test("Supplies grant one physical tool per stocked type, without spending inventory", function()
	local h = harness({ medkit = 5, soda = 4, spring = 3, shield = 2 })
	h.Supplies:grant(h.Player, 7)
	eq(#h.Backpack:GetChildren(), 4)
	for id, stock in pairs(h.Data.Inventory) do
		local tool = assert(h.tool(id))
		eq(tool.CanBeDropped, false); assert(tool:FindFirstChild("Handle"))
		eq(h.Data.Inventory[id], stock)
	end
	eq(h.pushCount(), 0)
end)

test("Backpack and unrelated-character activation cannot consume supplies", function()
	local h = harness({ medkit = 2 })
	h.Humanoid.Health = 30; h.Supplies:grant(h.Player, 1)
	local tool = h.tool("medkit")
	tool.Activated:Fire()
	eq(h.Data.Inventory.medkit, 2); eq(h.Humanoid.Health, 30)
	local unrelated = roblox.Instance.new("Model"); unrelated.Parent = h.Env.Workspace
	tool.Parent = unrelated; tool.Activated:Fire()
	eq(h.Data.Inventory.medkit, 2); eq(h.pushCount(), 0)
end)

test("Lobby, dead, unloaded, and replacement avatars cannot consume equipped supplies", function()
	local h = harness({ medkit = 2 })
	h.Humanoid.Health = 40; h.Supplies:grant(h.Player, 1)
	local tool = h.equip("medkit")
	h.Player:SetAttribute("InRound", false); tool.Activated:Fire()
	eq(h.Data.Inventory.medkit, 2)
	h.Player:SetAttribute("InRound", true); h.Humanoid.Health = 0; tool.Activated:Fire()
	eq(h.Data.Inventory.medkit, 2)
	h.Humanoid.Health = 40; h.setLoaded(false); tool.Activated:Fire()
	eq(h.Data.Inventory.medkit, 2)
	h.setLoaded(true); h.replaceCharacter(); tool.Parent = h.Player.Character; tool.Activated:Fire()
	eq(h.Data.Inventory.medkit, 2); eq(h.pushCount(), 0)
end)

test("A full-health medkit remains stocked and can be used after taking damage", function()
	local h = harness({ medkit = 2 })
	h.Supplies:grant(h.Player, 1)
	local tool = h.equip("medkit")
	local activated = tool.Activated
	activated:Fire()
	eq(h.Data.Inventory.medkit, 2); eq(tool.Parent, h.Character); eq(h.pushCount(), 0)
	h.Humanoid.Health = 40; activated:Fire()
	eq(h.Humanoid.Health, 75); eq(h.Data.Inventory.medkit, 1); eq(h.pushCount(), 1)
	activated:Fire(); activated:Fire()
	eq(h.Humanoid.Health, 75); eq(h.Data.Inventory.medkit, 1); eq(h.pushCount(), 1)
end)

test("Medkit healing is capped at max health and empty stock gives no free heal", function()
	local h = harness({ medkit = 1 })
	h.Supplies:grant(h.Player, 1)
	local tool = h.equip("medkit")
	h.Data.Inventory.medkit = nil; h.Humanoid.Health = 90; tool.Activated:Fire()
	eq(h.Humanoid.Health, 90); eq(h.pushCount(), 0)
	h.Data.Inventory.medkit = 1; tool.Activated:Fire()
	eq(h.Humanoid.Health, 100); eq(h.Data.Inventory.medkit, nil)
end)

test("Speed and jump boosts consume once, have bounded bonuses, and expire at eight seconds", function()
	local h = harness({ soda = 2, spring = 2 })
	h.Supplies:grant(h.Player, 1)
	local sodaActivated = h.equip("soda").Activated; sodaActivated:Fire(); sodaActivated:Fire()
	local springActivated = h.equip("spring").Activated; springActivated:Fire(); springActivated:Fire()
	eq(h.Humanoid.WalkSpeed, Config.BaseWalkSpeed + 6)
	eq(h.Humanoid.JumpPower, Config.BaseJumpPower + 15)
	eq(h.Data.Inventory.soda, 1); eq(h.Data.Inventory.spring, 1)
	h.advance(7.9)
	eq(h.Humanoid.WalkSpeed, Config.BaseWalkSpeed + 6)
	eq(h.Humanoid.JumpPower, Config.BaseJumpPower + 15)
	h.advance(0.11)
	eq(h.Humanoid.WalkSpeed, Config.BaseWalkSpeed); eq(h.Humanoid.JumpPower, Config.BaseJumpPower)
end)

test("Early round cleanup removes tools and boosts; old expiry callbacks cannot change a new session", function()
	local h = harness({ soda = 2, spring = 2, medkit = 1 })
	h.Supplies:grant(h.Player, 1)
	h.equip("soda").Activated:Fire(); h.equip("spring").Activated:Fire()
	h.advance(2); h.Supplies:clear(h.Player); h.Supplies:clear(h.Player)
	eq(h.Humanoid.WalkSpeed, Config.BaseWalkSpeed); eq(h.Humanoid.JumpPower, Config.BaseJumpPower)
	assert(not h.tool("medkit")); eq(h.Data.Inventory.medkit, 1)
	h.Supplies:grant(h.Player, 2)
	h.equip("soda").Activated:Fire()
	h.advance(6.1)
	eq(h.Humanoid.WalkSpeed, Config.BaseWalkSpeed + 6)
	h.advance(2)
	eq(h.Humanoid.WalkSpeed, Config.BaseWalkSpeed)
end)

test("Supply expiry does not overwrite movement owned by an event", function()
	local h = harness({ soda = 1, spring = 1 })
	h.Supplies:grant(h.Player, 1)
	h.equip("soda").Activated:Fire(); h.equip("spring").Activated:Fire()
	h.Humanoid.WalkSpeed, h.Humanoid.JumpPower = 19, 44
	h.advance(8.1); h.Supplies:clear(h.Player)
	eq(h.Humanoid.WalkSpeed, 19); eq(h.Humanoid.JumpPower, 44)
end)

test("Shield blocks native damage for five seconds, then expires", function()
	local h = harness({ shield = 2 })
	h.Supplies:grant(h.Player, 1)
	local activated = h.equip("shield").Activated; activated:Fire(); activated:Fire()
	eq(h.Data.Inventory.shield, 1)
	assert(h.Character:FindFirstChild("SupplyShield"))
	h.Humanoid:TakeDamage(40); eq(h.Humanoid.Health, 100)
	h.advance(4.9); h.Humanoid:TakeDamage(40); eq(h.Humanoid.Health, 100)
	h.advance(0.11); assert(not h.Character:FindFirstChild("SupplyShield"))
	h.Humanoid:TakeDamage(40); eq(h.Humanoid.Health, 60)
end)

test("Shield and buff cleanup leaves a replacement avatar untouched", function()
	local h = harness({ shield = 1, soda = 1 })
	h.Supplies:grant(h.Player, 1)
	h.equip("shield").Activated:Fire(); h.equip("soda").Activated:Fire()
	local replacement, humanoid = h.replaceCharacter()
	humanoid.WalkSpeed = 18
	h.Supplies:clear(h.Player); h.advance(10)
	assert(not h.Character:FindFirstChild("SupplyShield"))
	assert(not replacement:FindFirstChild("SupplyShield")); eq(humanoid.WalkSpeed, 18)
end)

test("Unused stock survives round cleanup and profile reload into the next session", function()
	local h = harness({ medkit = 2, soda = 3, spring = 4, shield = 5 })
	h.Supplies:grant(h.Player, 1); h.Supplies:clear(h.Player)
	local saved = Profile.copy(h.Data)
	local reloaded = Profile.normalize(saved, Catalog, Config.StartingTokens)
	for id, stock in pairs(saved.Inventory) do eq(reloaded.Inventory[id], stock) end
	h.Data.Inventory = table.clone(reloaded.Inventory)
	h.Supplies:grant(h.Player, 2)
	for _, id in ipairs({ "medkit", "soda", "spring", "shield" }) do assert(h.tool(id)) end
end)

test("Supplies keep their remaining duration across event cleanup and expire after event restoration", function()
	local h = harness({ soda = 1 })
	h.Supplies:grant(h.Player, 9); h.equip("soda").Activated:Fire()
	h.advance(3)
	h.Humanoid.WalkSpeed = Config.BaseWalkSpeed
	h.Supplies:reapply(h.Player)
	eq(h.Humanoid.WalkSpeed, Config.BaseWalkSpeed + 6)
	h.Humanoid.WalkSpeed = 29
	h.Supplies:reapply(h.Player); eq(h.Humanoid.WalkSpeed, 35)
	h.Humanoid.WalkSpeed = 0
	h.advance(5); h.Supplies:update(); eq(h.Humanoid.WalkSpeed, 0)
	h.Humanoid.WalkSpeed = 35
	h.Supplies:update(); eq(h.Humanoid.WalkSpeed, 29)
	h.Humanoid.WalkSpeed = Config.BaseWalkSpeed; h.Supplies:reapply(h.Player)
	eq(h.Humanoid.WalkSpeed, Config.BaseWalkSpeed)
end)

local function obbyHarness()
	local h = harness()
	h.Player:SetAttribute("InRound", false)
	h.World = h.Env.load("src/server/World.luau").build()
	h.Obby = h.Env.load("src/server/ObbyService.luau").new(h.World, h.Service, h.Remotes)
	function h.touch(order)
		local part = order == #h.World.ObbyCheckpoints + 1 and h.World.ObbyFinish or h.World.ObbyCheckpoints[order]
		if part then h.Root.Position = part.Position + roblox.Vector3.new(0, part.Size.Y / 2 + 3, 0) end
		return h.Obby:touch(h.Player, order)
	end
	function h.course(interval)
		assert(h.touch(1))
		for order = 2, #h.World.ObbyCheckpoints + 1 do
			h.advance(interval or 1)
			local accepted = h.touch(order)
			if order <= #h.World.ObbyCheckpoints then assert(accepted, "checkpoint rejected " .. order) else return accepted end
		end
	end
	return h
end

test("Stacked event boosts restore their baseline while a supply overlay retains only its remaining duration", function()
	local h=harness({soda=1});h.Supplies:grant(h.Player,11);h.equip("soda").Activated:Fire()
	h.World=h.Env.load("src/server/World.luau").build()
	h.Env.Env.Random.new=function()return {NextInteger=function()return 3 end,NextNumber=function(_,low,high)return ((low or 0)+(high or 1))/2 end}end
	local events=h.Env.load("src/server/Events.luau")
	local ctx={World=h.World,Players=function()return {h.Player}end,IsAlive=function()return true end,Active=function()return true end,SetRole=function()end,Damage=function()end}
	local speed
	for _,event in ipairs(events.Definitions)do if event.Id=="speed_frenzy"then speed=event end end
	h.Supplies:suspend(h.Player);local cleanup=speed.Run(ctx,h.Player);h.Supplies:reapply(h.Player)
	eq(h.Humanoid.WalkSpeed,35)
	h.Supplies:suspend(h.Player);local personal=events.runPersonal(ctx,h.Player);h.Supplies:reapply(h.Player)
	eq(h.Humanoid.WalkSpeed,42)
	h.Supplies:suspend(h.Player);cleanup();h.Supplies:reapply(h.Player)
	eq(h.Humanoid.WalkSpeed,42)
	h.Supplies:suspend(h.Player);personal();h.Supplies:reapply(h.Player)
	eq(h.Humanoid.WalkSpeed,Config.BaseWalkSpeed+6)
	h.advance(8);h.Supplies:update();eq(h.Humanoid.WalkSpeed,Config.BaseWalkSpeed)
end)

test("A suspended supply expires without turning an event's equal-valued speed into its former baseline", function()
	local h=harness({soda=1});h.Supplies:grant(h.Player,11);h.equip("soda").Activated:Fire()
	h.Supplies:suspend(h.Player);h.Supplies:suspend(h.Player);eq(h.Humanoid.WalkSpeed,Config.BaseWalkSpeed)
	h.Humanoid.WalkSpeed=Config.BaseWalkSpeed+6 -- An independent event's base happens to equal the old overlay.
	h.advance(8);h.Supplies:reapply(h.Player);eq(h.Humanoid.WalkSpeed,Config.BaseWalkSpeed+6)
end)

test("Obby exposes ten ordered physical checkpoints and a distinct finish", function()
	local h = obbyHarness()
	eq(#h.World.ObbyCheckpoints, 10)
	for order, part in ipairs(h.World.ObbyCheckpoints) do
		eq(part.Name, "ObbyCheckpoint" .. order); eq(part:GetAttribute("ObbyOrder"), order)
		assert(part.CanCollide and part.CanTouch)
	end
	eq(h.World.ObbyFinish:GetAttribute("ObbyOrder"), 11)
end)

test("Obby rejects forged order, skipped steps, duplicates, and distant touches", function()
	local h = obbyHarness()
	for _, order in ipairs({ 0, -1, 12, 100, 1.5, "1", math.huge, 0 / 0, false, {} }) do
		assert(not h.Obby:touch(h.Player, order), "forged order accepted")
	end
	assert(not h.touch(2)); assert(not h.touch(11)); eq(h.awardTotal(), 0)
	h.Root.Position = h.World.ObbyCheckpoints[1].Position + roblox.Vector3.new(100, 0, 0)
	assert(not h.Obby:touch(h.Player, 1))
	assert(h.touch(1)); assert(not h.touch(1)); assert(not h.touch(3))
	eq(h.Player:GetAttribute("ObbyCheckpoint"), 1); eq(h.awardTotal(), 0)
end)

test("Obby requires time between checkpoint contacts and the full minimum course time", function()
	local h = obbyHarness()
	assert(h.touch(1)); assert(not h.touch(2))
	h.advance(0.19); assert(not h.touch(2))
	h.advance(0.02); assert(h.touch(2))
	for order = 3, 11 do
		h.advance(0.21)
		local accepted = h.touch(order)
		if order < 11 then assert(accepted) else assert(not accepted) end
	end
	eq(h.awardTotal(), 0); eq(h.Player:GetAttribute("ObbyCheckpoint"), 0)
end)

test("Obby rejects round participants, dead avatars, unloaded data, and replacement-avatar progress", function()
	local h = obbyHarness()
	h.Player:SetAttribute("InRound", true); assert(not h.touch(1))
	h.Player:SetAttribute("InRound", false); h.Humanoid.Health = 0; assert(not h.touch(1))
	h.Humanoid.Health = 100; h.setLoaded(false); assert(not h.touch(1))
	h.setLoaded(true); assert(h.touch(1)); h.advance(1)
	local replacement, humanoid, root = h.replaceCharacter()
	root.Position = h.World.ObbyCheckpoints[2].Position + roblox.Vector3.new(0, 3, 0)
	assert(not h.Obby:touch(h.Player, 2)); eq(h.awardTotal(), 0)
	root.Position = h.World.ObbyCheckpoints[1].Position + roblox.Vector3.new(0, 3, 0)
	assert(h.Obby:touch(h.Player, 1)); eq(h.Obby.Runs[h.Player].Character, replacement)
	h.Player:SetAttribute("InRound", true)
	root.Position = h.World.ObbyFinish.Position + roblox.Vector3.new(0, 3, 0)
	assert(not h.Obby:touch(h.Player, 11)); eq(h.awardTotal(), 0)
	eq(humanoid.Health, 100)
end)

test("Valid obby completion awards exactly twenty tokens once and enforces the sixty-second cooldown", function()
	local h = obbyHarness()
	local initial = h.Data.Tokens
	assert(h.course(1)); eq(h.awardTotal(), Config.ObbyTokens); eq(h.Data.Tokens, initial + Config.ObbyTokens)
	local rewardAt = h.Obby.RewardAt[h.Player]
	eq(rewardAt, h.now() + Config.ObbyCooldown)
	assert(not h.touch(11)); eq(h.awardTotal(), Config.ObbyTokens)
	assert(not h.course(1)); eq(h.awardTotal(), Config.ObbyTokens); eq(h.Obby.RewardAt[h.Player], rewardAt)
	h.clock(rewardAt + 0.01)
	assert(h.course(1)); eq(h.awardTotal(), Config.ObbyTokens * 2)
end)

test("Entering the round before the finish awards no obby tokens", function()
	local h = obbyHarness()
	assert(h.touch(1))
	for order = 2, 10 do h.advance(1); assert(h.touch(order)) end
	h.advance(1); h.Player:SetAttribute("InRound", true)
	assert(not h.touch(11)); eq(h.awardTotal(), 0)
	h.Obby:reset(h.Player); eq(h.Player:GetAttribute("ObbyCheckpoint"), 0)
end)

test("Obby player removal discards stale avatar progress", function()
	local h = obbyHarness()
	assert(h.touch(1)); h.Obby:removed(h.Player)
	eq(h.Obby.Runs[h.Player], nil); eq(h.Player:GetAttribute("ObbyCheckpoint"), 0)
	h.Player.Parent = nil; assert(not h.touch(1)); eq(h.awardTotal(), 0)
end)

print("\n" .. passed .. " supply and obby checks passed. Actual jumping, equipping, and network behavior require Studio.")
