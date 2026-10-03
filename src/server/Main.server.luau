local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Catalog = require(Shared.Catalog)
local Economy = require(Shared.Economy)
local Profile = require(Shared.Profile)
local Rules = require(Shared.Rules)
local Data = require(script.Parent.DataService)
local World = require(script.Parent.World).build()
local Events = require(script.Parent.Events)
local Cosmetics = require(script.Parent.Cosmetics)

local network = Instance.new("Folder")
network.Name = "ButtonNetwork"
local remotes = {}
for _, name in ipairs({ "Press", "Shop", "Profile", "State", "Toast", "Countdown", "Leaderboard" }) do
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = network
	remotes[name] = remote
end
local bootstrap = Instance.new("RemoteFunction")
bootstrap.Name = "Bootstrap"
bootstrap.Parent = network
local state = {
	Remaining = Config.SpecialEvery, Total = 0, Special = false,
	EventName = "THE BUTTON IS WAITING", EventDescription = "One press. Thirteen possible regrets.",
	EventId = "idle", Presser = "", ReadyAt = 0, TaxUntil = 0, Cost = 0,
}
local busy = false
local lastRequests = {}
local leaderboard = {}
local leaderboardLabel = "Loading leaderboard..."
local function allow(player, channel, interval)
	local limits = lastRequests[player]
	if not limits then limits = {}; lastRequests[player] = limits end
	local now = os.clock()
	if now < (limits[channel] or 0) then return false end
	limits[channel] = now + interval
	return true
end
local function cost()
	return workspace:GetServerTimeNow() < state.TaxUntil and Config.TaxCost or 0
end
local function publish()
	state.Cost = cost()
	World.counter(state)
	remotes.State:FireAllClients(table.clone(state))
end
local function refreshCosmetics(player)
	Cosmetics.apply(player, Data.get(player))
end
local context = { World = World, Data = Data, Remotes = remotes, State = state }
local function press(player)
	if Data.Closing or not allow(player, "press", 0.15) then return end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local distance = root and (root.Position - World.Button.Position).Magnitude or math.huge
	local data = Data.get(player)
	local valid, reason = Rules.canPress(workspace:GetServerTimeNow(), state.ReadyAt, distance, humanoid ~= nil and humanoid.Health > 0, data ~= nil, Config)
	if not valid or busy then
		if not busy then remotes.Toast:FireClient(player, reason, "info") end
		return
	end
	local accepted, message = Economy.press(data, cost(), Config, Catalog)
	if not accepted then remotes.Toast:FireClient(player, message, "info"); return end
	-- The mutation and busy flag are set before anything yields, so simultaneous presses serialize.
	busy = true
	local remaining, special = Rules.advance(state.Remaining, Config)
	state.Remaining = remaining
	state.Total += 1
	state.Special = special
	state.Presser = player.DisplayName
	local event = special and { Id = "special", Name = "SPECIAL EVENT", Description = "30 seconds of low gravity, a new room, and rewards for everyone!", Duration = Config.SpecialDuration, Run = Events.special } or Events.choose()
	state.EventName = event.Name
	state.EventDescription = event.Description
	state.EventId = event.Id
	state.ReadyAt = workspace:GetServerTimeNow() + math.max(event.Duration, Config.PressCooldown)
	Data.push(player)
	local skin = Catalog.ById[data.Equipped.Skin] or Catalog.ById.skin_classic
	World.press(Color3.fromRGB(unpack(skin.Color)))
	local soundItem = Catalog.ById[data.Equipped.Sound]
	local sound = Instance.new("Sound")
	sound.SoundId = soundItem and soundItem.Sound or "rbxasset://sounds/action_jump_land.mp3"
	sound.PlaybackSpeed = soundItem and soundItem.Pitch or 1
	sound.Volume = 0.45
	sound.RollOffMaxDistance = 100
	sound.Parent = World.Button
	sound:Play()
	Debris:AddItem(sound, 5)
	publish()
	task.spawn(function()
		local ok, cleanup = xpcall(function() return event.Run(context, player) end, debug.traceback)
		if not ok then warn("[Button] Event error: " .. tostring(cleanup)) end
		publish()
		task.wait(math.max(0, state.ReadyAt - workspace:GetServerTimeNow()))
		if ok and type(cleanup) == "function" then
			local cleaned, err = xpcall(cleanup, debug.traceback)
			if not cleaned then warn("[Button] Cleanup error: " .. tostring(err)) end
		end
		-- Restore shared world settings even when a handler fails midway.
		World.Effects:ClearAllChildren()
		World.theme("Normal")
		workspace.Gravity = 196.2
		remotes.Countdown:FireAllClients(-1)
		if special then state.Remaining = Config.SpecialEvery end
		state.Special = false
		state.ReadyAt = workspace:GetServerTimeNow()
		busy = false
		publish()
	end)
end
Data.init(remotes)
bootstrap.OnServerInvoke = function(player)
	if not allow(player, "bootstrap", 0.5) then return nil end
	local data = Data.get(player)
	return {
		State = table.clone(state), Profile = data and Profile.copy(data),
		Multiplier = data and Economy.multiplier(data, Catalog) or 1,
		Persistent = not game:GetService("RunService"):IsStudio() or Config.PersistenceInStudio,
		Leaderboard = leaderboard, LeaderboardLabel = leaderboardLabel,
	}
end
remotes.Press.OnServerEvent:Connect(press)
World.Prompt.Triggered:Connect(press)
World.Click.MouseClick:Connect(press)
remotes.Shop.OnServerEvent:Connect(function(player, action, value)
	if Data.Closing or not allow(player, "shop", 0.3) then return end
	if type(action) ~= "string" or type(value) ~= "string" or #value > 64 then return end
	local data = Data.get(player)
	if not data then return end
	local ok, message
	if action == "Buy" then ok, message = Economy.purchase(data, value, Catalog)
	elseif action == "Unequip" then ok, message = Economy.unequip(data, value, Catalog)
	else return end
	remotes.Toast:FireClient(player, message, ok and "good" or "info")
	if ok then Data.push(player); refreshCosmetics(player) end
end)
local function added(player)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Head", 10)
		character:WaitForChild("HumanoidRootPart", 10)
		if player.Character == character then refreshCosmetics(player) end
	end)
	player:GetAttributeChangedSignal("KingUntil"):Connect(function() refreshCosmetics(player) end)
	Data.load(player)
	refreshCosmetics(player)
end
Players.PlayerAdded:Connect(added)
Players.PlayerRemoving:Connect(function(player)
	lastRequests[player] = nil
	Data.save(player, true)
end)
for _, player in ipairs(Players:GetPlayers()) do task.spawn(added, player) end
network.Parent = ReplicatedStorage
publish()
task.spawn(function()
	local previousCost = state.Cost
	local enabled = true
	while not Data.Closing do
		task.wait(0.25)
		local nextEnabled = not busy
		if cost() ~= previousCost or nextEnabled ~= enabled then
			previousCost = cost(); enabled = nextEnabled; publish()
		end
	end
end)
task.spawn(function()
	while not Data.Closing do
		local entries, label = Data.top()
		if entries then leaderboard = entries end
		leaderboardLabel = label
		local lines = { "MOST BUTTON PRESSES", "", label, "" }
		for rank, entry in ipairs(leaderboard) do
			table.insert(lines, rank .. ". " .. entry.Name .. " — " .. entry.Presses)
		end
		if #leaderboard == 0 then table.insert(lines, "Your first press starts the story.") end
		World.LeaderboardLabel.Text = table.concat(lines, "\n")
		remotes.Leaderboard:FireAllClients(leaderboard, label)
		task.wait(Config.LeaderboardSeconds)
	end
end)
game:BindToClose(function()
	Data.Closing = true
	local pending = 0
	for player in pairs(Data.Records) do
		pending += 1
		task.spawn(function() Data.save(player, true); pending -= 1 end)
	end
	local deadline = os.clock() + 25
	while pending > 0 and os.clock() < deadline do task.wait(0.1) end
end)
