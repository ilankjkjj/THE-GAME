local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(shared.Config)
local Catalog = require(shared.Catalog)
local UI = require(script.Parent.UI)
local network = game:GetService("ReplicatedStorage"):WaitForChild("ButtonNetwork")
local ui
local function emote()
	local item = ui.Data and Catalog.ById[ui.Data.Equipped.Emote]
	if not item then ui:toast("Buy and equip an emote in the shop first.", "info"); return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
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
	Press = function() network.Press:FireServer() end,
	Shop = function(action, id) network.Shop:FireServer(action, id) end,
	Emote = emote,
})
network.Profile.OnClientEvent:Connect(function(...) ui:profile(...) end)
network.State.OnClientEvent:Connect(function(state) ui:state(state) end)
network.Toast.OnClientEvent:Connect(function(...) ui:toast(...) end)
network.Leaderboard.OnClientEvent:Connect(function(...) ui:leaders(...) end)
network.Countdown.OnClientEvent:Connect(function(seconds)
	ui.Countdown.Visible = seconds >= 0
	ui.Countdown.Text = seconds == 0 and "SURPRISE!" or tostring(seconds)
	ui.Countdown.TextSize = seconds == 0 and 38 or 82
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.B then ui:open("Shop") end
	if input.KeyCode == Enum.KeyCode.L then ui:open("Leaderboard") end
	if input.KeyCode == Enum.KeyCode.Escape then ui:close() end
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
	ui:toast("Progress is taking longer to load. Please rejoin if it doesn't appear.", "info")
end)
local elapsed = 0
local lastSize = Vector2.zero
RunService.RenderStepped:Connect(function(delta)
	elapsed += delta
	if elapsed < 0.1 then return end
	elapsed = 0
	local camera = workspace.CurrentCamera
	if camera and camera.ViewportSize ~= lastSize then lastSize = camera.ViewportSize; ui:resize() end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local room = workspace:FindFirstChild("ButtonRoom")
	local button = room and room:FindFirstChild("Button")
	ui:tick(root ~= nil and button ~= nil and (root.Position - button.Position).Magnitude <= Config.PressDistance)
end)
