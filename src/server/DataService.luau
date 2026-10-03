local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Catalog = require(Shared.Catalog)
local Profile = require(Shared.Profile)
local Economy = require(Shared.Economy)

local Data = { Records = {}, Closing = false }
local persistent = not RunService:IsStudio() or Config.PersistenceInStudio
local store = persistent and DataStoreService:GetDataStore(Config.ProfileStore) or nil
local ordered = persistent and DataStoreService:GetOrderedDataStore(Config.LeaderboardStore) or nil
local winStore = persistent and DataStoreService:GetOrderedDataStore(Config.WinsStore) or nil
local sessionId = game.JobId .. ":" .. HttpService:GenerateGUID(false)

function Data.init(remotes)
	Data.Remotes = remotes
	task.spawn(function()
		while not Data.Closing do
			task.wait(Config.AutosaveSeconds)
			for player in pairs(Data.Records) do
				task.spawn(Data.save, player, false)
			end
		end
	end)
end
function Data.get(player)
	local record = Data.Records[player]
	return record and record.Profile
end
function Data.push(player)
	local data = Data.get(player)
	if not data or player.Parent ~= Players then return end
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		stats.Presses.Value = data.Presses
		stats.Wins.Value = data.Wins
		stats.Coins.Value = data.Coins
		stats["Button Points"].Value = data.Points
	end
	player:SetAttribute("Skin", data.Equipped.Skin)
	player:SetAttribute("Title", data.Equipped.Title)
	player:SetAttribute("Pet", data.Equipped.Pet)
	Data.Remotes.Profile:FireClient(player, Profile.copy(data), Economy.multiplier(data, Catalog), persistent)
end
function Data.load(player)
	if Data.Closing then return end
	local profile
	if persistent then
		for attempt = 1, 3 do
			local ok, result = pcall(function()
				return store:UpdateAsync("u_" .. player.UserId, function(old)
					if old ~= nil and type(old) ~= "table" then error("Invalid stored profile") end
					old = old or {}
					local lock = old.Session
					if lock and lock.Id ~= sessionId and os.time() - (lock.UpdatedAt or 0) < Config.SessionLeaseSeconds then
						return nil
					end
					return {
						Profile = Profile.normalize(old.Profile, Catalog, Config.StartingCoins),
						Session = { Id = sessionId, UpdatedAt = os.time() },
					}
				end)
			end)
			if ok and result and result.Session and result.Session.Id == sessionId then
				profile = result.Profile
				break
			end
			if attempt < 3 then task.wait(attempt * 2) end
		end
		if not profile then
			if player.Parent == Players then
				player:Kick("Your save is busy or unavailable. Please rejoin in a moment; your progress is safe.")
			end
			return
		end
	else
		profile = Profile.new(Config.StartingCoins)
	end
	Data.Records[player] = { Profile = profile, LastSaved = os.time(), Saving = false }
	if player.Parent ~= Players or Data.Closing then
		Data.save(player, true)
		return
	end
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	for _, name in ipairs({ "Wins", "Presses", "Coins", "Button Points" }) do
		local value = Instance.new("IntValue")
		value.Name = name
		value.Parent = stats
	end
	stats.Parent = player
	local status = Instance.new("StringValue")
	status.Name = "Status"
	status.Value = "Lobby"
	status.Parent = stats
	Data.push(player)
end
function Data.award(player, coins, points)
	local data = Data.get(player)
	if not data then return end
	local earned = Economy.awardCoins(data, coins or 0, Catalog)
	data.Points += points or 0
	Data.push(player)
	return earned
end
function Data.awardAll(coins, points)
	for player in pairs(Data.Records) do Data.award(player, coins, points) end
end
function Data.finishRound(player, won, survived)
	local data = Data.get(player)
	if not data then return end
	data.Rounds += 1
	if won then data.Wins += 1 end
	if survived then
		Data.award(player, won and Config.WinnerCoins or 40, won and Config.WinnerPoints or 8)
	else
		Data.push(player)
	end
end
function Data.save(player, release)
	local record = Data.Records[player]
	if not record then return end
	if record.Saving then
		if not release then return end
		while record.Saving do task.wait(0.1) end
		if Data.Records[player] ~= record then return end
	end
	record.Saving = true
	if persistent then
		local snapshot = Profile.copy(record.Profile)
		local saved = false
		for attempt = 1, 3 do
			local ok, result = pcall(function()
				return store:UpdateAsync("u_" .. player.UserId, function(old)
					if not old or not old.Session or old.Session.Id ~= sessionId then return nil end
					return { Profile = snapshot, Session = not release and { Id = sessionId, UpdatedAt = os.time() } or nil }
				end)
			end)
			if ok and result then saved = true; break end
			if ok then
				-- A different server owns this save. Stop all further mutations immediately.
				Data.Records[player] = nil
				if player.Parent == Players then player:Kick("Your save session moved. Please rejoin.") end
				break
			end
			if attempt < 3 then task.wait(attempt) end
		end
		if saved then
			record.LastSaved = os.time()
			local ok, err = pcall(function()
				ordered:UpdateAsync(tostring(player.UserId), function(previous)
					return math.max(previous or 0, snapshot.Presses)
				end)
				winStore:UpdateAsync(tostring(player.UserId), function(previous)
					return math.max(previous or 0, snapshot.Wins)
				end)
			end)
			if not ok then warn("[Button] Leaderboard write failed: " .. tostring(err)) end
		else
			warn("[Button] Could not save progress for " .. player.UserId)
			if os.time() - record.LastSaved > Config.SessionLeaseSeconds - 30 then
				Data.Records[player] = nil
				if player.Parent == Players then player:Kick("Saving is temporarily unavailable. Please rejoin shortly.") end
			end
		end
	end
	record.Saving = false
	if release then Data.Records[player] = nil end
end
function Data.top()
	if not persistent then
		local entries = {}
		for player, record in pairs(Data.Records) do
			table.insert(entries, { UserId = player.UserId, Name = player.DisplayName, Presses = record.Profile.Presses, Wins = record.Profile.Wins })
		end
		table.sort(entries, function(a, b) if a.Wins == b.Wins then return a.Presses > b.Presses end; return a.Wins > b.Wins end)
		while #entries > Config.LeaderboardSize do table.remove(entries) end
		return entries, "STUDIO SESSION"
	end
	local ok, pages = pcall(function() return winStore:GetSortedAsync(false, Config.LeaderboardSize) end)
	if not ok then return nil, "Leaderboard temporarily unavailable" end
	local entries = {}
	for _, entry in ipairs(pages:GetCurrentPage()) do
		local userId = tonumber(entry.key)
		if userId then
			local name = Data.NameCache and Data.NameCache[userId]
			if not name then
				local success, result = pcall(Players.GetNameFromUserIdAsync, Players, userId)
				name = success and result or ("Player " .. userId)
				if success then Data.NameCache = Data.NameCache or {}; Data.NameCache[userId] = name end
			end
			table.insert(entries, { UserId = userId, Name = name, Wins = entry.value, Presses = 0 })
		end
	end
	return entries, "GLOBAL • MOST SURVIVAL WINS"
end
return Data
