local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")
local Debris = game:GetService("Debris")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Catalog = require(Shared.Catalog)
local Economy = require(Shared.Economy)
local Profile = require(Shared.Profile)
local Data = require(script.Parent.DataService)
local Cosmetics = require(script.Parent.Cosmetics)
local World = require(script.Parent.World).build()
local function team(name, color, auto)
	local object = Teams:FindFirstChild(name) or Instance.new("Team")
	object.Name, object.TeamColor, object.AutoAssignable = name, BrickColor.new(color), auto
	object.Parent = Teams
	return object
end
local lobbyTeam = team("Lobby", "Pastel light blue", true)
local arenaTeam = team("Survivors", "Sea green", false)
local existing = ReplicatedStorage:FindFirstChild("ButtonNetwork")
if existing then existing:Destroy() end
local network = Instance.new("Folder")
network.Name = "ButtonNetwork"
local remotes = {}
for _, name in ipairs({ "Press", "Queue", "Shop", "Profile", "State", "Toast", "Countdown", "Leaderboard" }) do
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = network
	remotes[name] = remote
end
local bootstrap = Instance.new("RemoteFunction")
bootstrap.Name = "Bootstrap"
bootstrap.Parent = network
local lastRequests = {}
local leaderboard, leaderboardLabel = {}, "Loading the survival leaderboard..."
local function allow(player, channel, interval)
	local limits = lastRequests[player]
	if not limits then limits = {}; lastRequests[player] = limits end
	if os.clock() < (limits[channel] or 0) then return false end
	limits[channel] = os.clock() + interval
	return true
end
local function refreshCosmetics(player) Cosmetics.apply(player, Data.get(player)) end
local function sound(player)
	local data = player and Data.get(player)
	local item = data and Catalog.ById[data.Equipped.Sound]
	local object = Instance.new("Sound")
	object.SoundId = item and item.Sound or "rbxasset://sounds/action_jump_land.mp3"
	object.PlaybackSpeed = item and item.Pitch or 1.2
	object.Volume = 0.45
	object.RollOffMaxDistance = 155
	object.Parent = World.Button
	object:Play()
	Debris:AddItem(object, 5)
end
local rounds = require(script.Parent.RoundService).new({
	World = World, Data = Data, Remotes = remotes, RefreshCosmetics = refreshCosmetics,
	PlaySound = sound, LobbyTeam = lobbyTeam, ArenaTeam = arenaTeam,
})
Data.init(remotes)
bootstrap.OnServerInvoke = function(player)
	if not allow(player, "bootstrap", 0.5) then return nil end
	local data = Data.get(player)
	return {
		State = table.clone(rounds.State), Profile = data and Profile.copy(data),
		Multiplier = data and Economy.multiplier(data, Catalog) or 1,
		Persistent = not game:GetService("RunService"):IsStudio() or Config.PersistenceInStudio,
		Leaderboard = leaderboard, LeaderboardLabel = leaderboardLabel,
	}
end
local function press(player)
	if Data.Closing or not allow(player, "press", 0.2) then return end
	if not rounds:isAlive(player) then
		remotes.Toast:FireClient(player, "Join the next round to use the arena button.", "info")
		return
	end
	rounds:startEvent(player)
end
local function queue(player)
	if Data.Closing or not allow(player, "queue", 0.7) then return end
	rounds:toggleQueue(player)
end
remotes.Press.OnServerEvent:Connect(press)
remotes.Queue.OnServerEvent:Connect(queue)
World.Prompt.Triggered:Connect(press)
World.Click.MouseClick:Connect(press)
if World.JoinPrompt then
	World.JoinPrompt.Triggered:Connect(function(player)
		if not player:GetAttribute("Queued") then queue(player)
		else remotes.Toast:FireClient(player, "You're already queued. Your island is coming soon!", "good") end
	end)
end
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
	if ok then Data.push(player); refreshCosmetics(player); rounds:publish() end
end)
local function added(player)
	player:SetAttribute("Queued", false)
	rounds:setStatus(player, "Lobby")
	player.CharacterAdded:Connect(function(character) rounds:character(player, character) end)
	if player.Character then task.spawn(function() rounds:character(player, player.Character) end) end
	Data.load(player)
	if not Data.get(player) or player.Parent ~= Players then return end
	rounds:added(player)
	refreshCosmetics(player)
end
Players.PlayerAdded:Connect(added)
Players.PlayerRemoving:Connect(function(player)
	rounds:removed(player)
	lastRequests[player] = nil
	Data.save(player, true)
end)
network.Parent = ReplicatedStorage
for _, player in ipairs(Players:GetPlayers()) do task.spawn(added, player) end
rounds:publish()
task.spawn(function()
	while not Data.Closing do
		task.wait(0.2)
		local ok, err = xpcall(function() rounds:tick() end, debug.traceback)
		if not ok then warn("[Survival] Round update: " .. tostring(err)) end
	end
end)
task.spawn(function()
	while not Data.Closing do
		local entries, label = Data.top()
		if entries then leaderboard = entries end
		leaderboardLabel = label
		local lines = { "HALL OF SURVIVORS", "", label, "" }
		for rank, entry in ipairs(leaderboard) do table.insert(lines, rank .. ". " .. entry.Name .. " — " .. entry.Wins .. " wins") end
		if #leaderboard == 0 then table.insert(lines, "Be the first to survive.") end
		World.LeaderboardLabel.Text = table.concat(lines, "\n")
		remotes.Leaderboard:FireAllClients(leaderboard, label)
		task.wait(Config.LeaderboardSeconds)
	end
end)
game:BindToClose(function()
	Data.Closing = true
	rounds:shutdown()
	local pending = 0
	for player in pairs(Data.Records) do
		pending += 1
		task.spawn(function() Data.save(player, true); pending -= 1 end)
	end
	local deadline = os.clock() + 25
	while pending > 0 and os.clock() < deadline do task.wait(0.1) end
end)
