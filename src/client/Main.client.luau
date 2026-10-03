local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(shared.Config)
local Catalog = require(shared.Catalog)
local UI = require(script.Parent.UI)
local network = game:GetService("ReplicatedStorage"):WaitForChild("ButtonNetwork")
local queueRemote = network:WaitForChild("Queue")
local ui
local watchedPlayer
local function humanoidFor(subject)
	local character = subject and subject.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end
local function restoreCamera()
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
	watchedPlayer = subject
	camera.CameraType = Enum.CameraType.Custom
	camera.CameraSubject = humanoid
	local targets = spectators()
	local index = table.find(targets, subject) or 1
	ui:spectating(subject.DisplayName, index == #targets)
end
local function spectate()
	if player:GetAttribute("InRound") == true or not ui.State or ui.State.Phase ~= "Round" then stopSpectating(); return end
	local targets = spectators()
	if #targets == 0 then stopSpectating(); ui:toast("The arena is empty. The next round starts soon.", "info"); return end
	local current = watchedPlayer and table.find(targets, watchedPlayer)
	if current and current >= #targets then stopSpectating()
	else watch(targets[current and current + 1 or 1]) end
end
local function emote()
	local item = ui.Data and ui.Data.Equipped and Catalog.ById[ui.Data.Equipped.Emote]
	if not item then ui:toast("Pick up an emote in the shop to celebrate in style.", "info"); return end
	local character = player.Character
	local humanoid = humanoidFor(player)
	if not humanoid or humanoid.Health <= 0 then return end
	local animate = character:FindFirstChild("Animate")
	local play = animate and animate:FindFirstChild("PlayEmote")
	local success, played = pcall(function()
		if play and play:IsA("BindableFunction") then return play:Invoke(item.Command) end
		return humanoid:PlayEmote(item.Command)
	end)
	if not success or not played then ui:toast("This avatar can't play that emote. Try an R15 avatar.", "info") end
end
ui = UI.new({
	Press = function() if player:GetAttribute("InRound") == true then network.Press:FireServer() end end,
	Shop = function(action, id) network.Shop:FireServer(action, id) end,
	Emote = emote,
	Queue = function() queueRemote:FireServer() end,
	Spectate = spectate,
})
network.Profile.OnClientEvent:Connect(function(...) ui:profile(...) end)
network.State.OnClientEvent:Connect(function(state)
	ui:state(state)
	if state.Phase ~= "Round" or player:GetAttribute("InRound") == true then stopSpectating() end
end)
network.Toast.OnClientEvent:Connect(function(...) ui:toast(...) end)
network.Leaderboard.OnClientEvent:Connect(function(...) ui:leaders(...) end)
network.Countdown.OnClientEvent:Connect(function(seconds)
	ui.Countdown.Visible = seconds >= 0
	ui.Countdown.Text = seconds == 0 and "GO!" or tostring(seconds)
	ui.Countdown.TextSize = seconds == 0 and 54 or 82
end)
player:GetAttributeChangedSignal("InRound"):Connect(function()
	if player:GetAttribute("InRound") == true then stopSpectating() end
end)
player.CharacterAdded:Connect(function(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and not watchedPlayer then restoreCamera() end
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.B then ui:open("Shop")
	elseif input.KeyCode == Enum.KeyCode.L then ui:open("Leaderboard")
	elseif input.KeyCode == Enum.KeyCode.P then ui:open("Roster")
	elseif input.KeyCode == Enum.KeyCode.V then spectate()
	elseif input.KeyCode == Enum.KeyCode.Q and player:GetAttribute("InRound") ~= true and not ui.Panel.Visible then queueRemote:FireServer()
	elseif input.KeyCode == Enum.KeyCode.Escape then ui:close(); stopSpectating() end
end)
require(script.Parent.Pets).start()
task.spawn(function()
	for _ = 1, 20 do
		local ok, result = pcall(function() return network.Bootstrap:InvokeServer() end)
		if ok and result then
			ui:state(result.State)
			ui:leaders(result.Leaderboard, result.LeaderboardLabel)
			if result.Profile then
				ui:profile(result.Profile, result.Multiplier, result.Persistent)
				return
			end
		end
		task.wait(1)
	end
	ui:toast("Your progress is taking longer to load. Rejoin if it doesn't appear.", "info")
end)
local elapsed = 0
local lastSize = Vector2.zero
RunService.RenderStepped:Connect(function(delta)
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
