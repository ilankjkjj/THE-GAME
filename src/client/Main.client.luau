local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(shared.Config)
local UI = require(script.Parent.UI)
local network = game:GetService("ReplicatedStorage"):WaitForChild("ButtonNetwork")
local queueRemote = network:WaitForChild("Queue")
local privateRemote = network:WaitForChild("PrivateState")
local ui
local watchedPlayer
local connections = {}
local destroyed = false
local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end
local function clearPrivateState()
	player:SetAttribute("PrivateRole", nil)
	player:SetAttribute("PrivateHint", nil)
end
local feedback = require(script.Parent.Feedback).new(network, {
	Subject = function() return watchedPlayer or player end,
})
local function humanoidFor(subject)
	local character = subject and subject.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end
local function restoreCamera()
	feedback:removeOffset()
	local camera = workspace.CurrentCamera
	local humanoid = humanoidFor(player)
	if camera and humanoid then
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = humanoid
	end
end
local function stopSpectating()
	watchedPlayer = nil
	if ui then ui:spectating(nil) end
	restoreCamera()
end
local function spectators()
	local targets = {}
	for _, candidate in ipairs(Players:GetPlayers()) do
		local humanoid = humanoidFor(candidate)
		if candidate ~= player and candidate:GetAttribute("InRound") == true and humanoid and humanoid.Health > 0 then
			table.insert(targets, candidate)
		end
	end
	table.sort(targets, function(a, b) return a.UserId < b.UserId end)
	return targets
end
local function watch(subject)
	local camera = workspace.CurrentCamera
	local humanoid = humanoidFor(subject)
	if not camera or not humanoid then return end
	feedback:removeOffset()
	watchedPlayer = subject
	camera.CameraType = Enum.CameraType.Custom
	camera.CameraSubject = humanoid
	local targets = spectators()
	local index = table.find(targets, subject) or 1
	ui:spectating(subject.DisplayName, index, #targets)
end
local function cycleSpectator(direction)
	if player:GetAttribute("InRound") == true or not ui.State or ui.State.Phase ~= "Round" then stopSpectating(); return end
	local targets = spectators()
	if #targets == 0 then stopSpectating(); ui:toast("The arena is empty. The next round starts soon.", "info"); return end
	local current = watchedPlayer and table.find(targets, watchedPlayer)
	watch(targets[current and ((current - 1 + direction) % #targets + 1) or 1])
end
local function spectate()
	if watchedPlayer then stopSpectating() else cycleSpectator(1) end
end
ui = UI.new({
	Press = function() if player:GetAttribute("InRound") == true then network.Press:FireServer() end end,
	Shop = function(action, id) network.Shop:FireServer(action, id) end,
	Queue = function() queueRemote:FireServer() end,
	Spectate = spectate,
	SpectatePrevious = function() cycleSpectator(-1) end,
	SpectateNext = function() cycleSpectator(1) end,
	SpectateStop = stopSpectating,
	Mute = function() return feedback:toggleMuted() end,
})
connect(network.Profile.OnClientEvent, function(...) ui:profile(...) end)
connect(network.State.OnClientEvent, function(state)
	if state.Phase ~= "Round" or (ui.State and ui.State.RoundNumber ~= state.RoundNumber) then clearPrivateState() end
	ui:state(state)
	if state.Phase ~= "Round" or player:GetAttribute("InRound") == true then stopSpectating() end
end)
connect(privateRemote.OnClientEvent, function(data)
	if type(data) ~= "table" then return end
	if data.Clear == true then clearPrivateState(); ui:tick(ui.Nearby); return end
	if not ui.State or ui.State.Phase ~= "Round" or data.RoundId ~= ui.State.RoundNumber or player:GetAttribute("InRound") ~= true then return end
	for field, attribute in pairs({ Role = "PrivateRole", Hint = "PrivateHint" }) do
		local value = data[field]
		if value == false then player:SetAttribute(attribute, nil)
		elseif type(value) == "string" then player:SetAttribute(attribute, value) end
	end
	ui:tick(ui.Nearby)
end)
connect(network.Toast.OnClientEvent, function(...) ui:toast(...) end)
connect(network.Leaderboard.OnClientEvent, function(...) ui:leaders(...) end)
connect(network.Countdown.OnClientEvent, function(seconds)
	ui:countdown(seconds)
end)
connect(player:GetAttributeChangedSignal("InRound"), function()
	if player:GetAttribute("InRound") == true then stopSpectating() else clearPrivateState() end
end)
connect(player.CharacterAdded, function(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not destroyed and humanoid and not watchedPlayer then restoreCamera() end
end)
connect(UserInputService.InputBegan, function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.B then ui:open("Shop")
	elseif input.KeyCode == Enum.KeyCode.L then ui:open("Leaderboard")
	elseif input.KeyCode == Enum.KeyCode.P then ui:open("Roster")
	elseif input.KeyCode == Enum.KeyCode.V then spectate()
	elseif input.KeyCode == Enum.KeyCode.LeftBracket and watchedPlayer then cycleSpectator(-1)
	elseif input.KeyCode == Enum.KeyCode.RightBracket and watchedPlayer then cycleSpectator(1)
	elseif input.KeyCode == Enum.KeyCode.Q and player:GetAttribute("InRound") ~= true and not ui.Panel.Visible then queueRemote:FireServer()
	elseif input.KeyCode == Enum.KeyCode.Escape then ui:close(); stopSpectating() end
end)
task.spawn(function()
	for _ = 1, 20 do
		if destroyed then return end
		local ok, result = pcall(function() return network.Bootstrap:InvokeServer() end)
		if destroyed then return end
		if ok and result then
			ui:state(result.State)
			feedback:state(result.State)
			ui:leaders(result.Leaderboard, result.LeaderboardLabel)
			if result.Profile then
				ui:profile(result.Profile, result.Persistent)
				return
			end
		end
		task.wait(1)
	end
	ui:toast("Your progress is taking longer to load. Rejoin if it doesn't appear.", "info")
end)
script.Destroying:Connect(function()
	destroyed = true
	clearPrivateState()
	stopSpectating()
	for _, connection in ipairs(connections) do connection:Disconnect() end
	connections = {}
	feedback:destroy()
	ui:destroy()
end)
local elapsed = 0
local lastSize = Vector2.zero
connect(RunService.RenderStepped, function(delta)
	elapsed += delta
	if elapsed < 0.1 then return end
	elapsed = 0
	local camera = workspace.CurrentCamera
	if camera and camera.ViewportSize ~= lastSize then lastSize = camera.ViewportSize; ui:resize() end
	if watchedPlayer then
		local humanoid = humanoidFor(watchedPlayer)
		if watchedPlayer.Parent ~= Players or watchedPlayer:GetAttribute("InRound") ~= true or not humanoid or humanoid.Health <= 0 then
			local targets = spectators()
			if #targets > 0 and ui.State and ui.State.Phase == "Round" then watch(targets[1]) else stopSpectating() end
		elseif camera then
			camera.CameraType = Enum.CameraType.Custom
			camera.CameraSubject = humanoid
		end
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local room = workspace:FindFirstChild("ButtonRoom")
	local button = room and room:FindFirstChild("Button", true)
	ui:tick(root ~= nil and button ~= nil and (root.Position - button.Position).Magnitude <= Config.PressDistance)
end)
