-- Edge placement and local feedback checks use Roblox's native property database.
-- Touch-control geometry, camera motion comfort and real audio need Studio checks.
local Environment = require("../scripts/RobloxEnvironment")
local roblox = require("@lune/roblox")
local Profile = require("../src/shared/Profile")
local AudioCatalog = require("../src/shared/AudioCatalog")
local passed = 0
local function test(name, callback)
	local ok, err = pcall(callback)
	assert(ok, "FAIL: " .. name .. "\n" .. tostring(err))
	passed += 1
	print("PASS: " .. name)
end
local env = Environment.new()
local input = { TouchEnabled = false }
env.Services.UserInputService = input
local attributes = { InRound = true, Queued = true, Role = "Survivor" }
local player = env.Services.Players.LocalPlayer
player.UserId = 7
player.GetAttribute = function(_, name) return attributes[name] end
player.SetAttribute = function(_, name, value) attributes[name] = value end
local character = roblox.Instance.new("Model")
local humanoid = roblox.Instance.new("Humanoid")
humanoid.Health = 100
humanoid.Parent = character
local root = roblox.Instance.new("Part")
root.Name = "HumanoidRootPart"
root.Position = roblox.Vector3.new(0, 34, 0)
root.Parent = character
player.Character = character
local purchase
local ui = env.load("src/client/UI.luau").new({ Press = function() end, Shop = function(action, id) purchase = { action, id } end, Queue = function() end, Spectate = function() end })
ui:profile(Profile.new(30), false)
local state = { Phase = "Round", RoundNumber = 4, RoundEndsAt = 200, ReadyAt = 0, EventName = "METEOR MAYHEM", EventDescription = "Red rings mark incoming meteors. Keep moving!", EventStage = "Active", EventCategory = "Disaster", EventIntensity = 3, AliveCount = 2, RoundPlayers = 5, Roster = {} }
ui:state(state)
local function rect(object, width, height)
	local size = object.Size
	local w, h = size.X.Scale * width + size.X.Offset, size.Y.Scale * height + size.Y.Offset
	return { X = object.Position.X.Scale * width + object.Position.X.Offset - w * object.AnchorPoint.X,
		Y = object.Position.Y.Scale * height + object.Position.Y.Offset - h * object.AnchorPoint.Y, W = w, H = h }
end
local function overlap(a, b)
	return a.X < b.X + b.W and a.X + a.W > b.X and a.Y < b.Y + b.H and a.Y + a.H > b.Y
end
test("The central 65 percent of the desktop view stays clear of persistent HUD", function()
	env.viewport(1280, 720); ui:resize(); ui:tick(true)
	local center = { X = 1280 * 0.175, Y = 720 * 0.175, W = 1280 * 0.65, H = 720 * 0.65 }
	for _, object in ipairs({ ui.Event, ui.Round, ui.Stats, ui.Health, ui.Navigation, ui.Actions }) do
		assert(not overlap(rect(object, 1280, 720), center), object.Name .. " overlaps central view")
	end
	assert(ui.Event.Size.X.Offset <= 340 and ui.Event.Size.Y.Offset <= 100)
end)
test("Phone, landscape and small desktop retain controls with touch corners reserved", function()
	for _, size in ipairs({ { 390, 844, true }, { 844, 390, true }, { 640, 480, false } }) do
		input.TouchEnabled = size[3]; env.viewport(size[1], size[2]); ui:resize(); ui:tick(true)
		assert(not overlap(rect(ui.Event, size[1], size[2]), rect(ui.Round, size[1], size[2])))
		assert(not overlap(rect(ui.Actions, size[1], size[2]), rect(ui.Navigation, size[1], size[2])))
		if size[3] then assert(ui.Actions.Position.Y.Offset <= -170 and ui.Navigation.Position.Y.Offset <= -170) end
		ui:countdown(5); assert(ui.Countdown.Parent == ui.Event and ui.Countdown.Text == "5s")
		for _, panel in ipairs({ "Shop", "Leaderboard", "Roster" }) do
			ui:open(panel); assert(ui.Panel.Visible and not ui.Actions.Visible)
			ui:close(); assert(not ui.Panel.Visible)
		end
	end
end)
test("Press controls are contextual and inactive hazards never cover the view", function()
	ui:tick(false); assert(not ui.Actions.Visible and not ui.CanPress)
	ui:tick(true); assert(ui.Press.Visible and ui.CanPress)
	state.ReadyAt = 110; ui:state(state); ui:tick(true); assert(ui.Press.Visible and not ui.CanPress)
	state.SuddenDeath = true; ui:state(state); ui:tick(true); assert(not ui.Actions.Visible and ui.Timer.Text == "OT")
	attributes.InRound = false; state.SuddenDeath = false; ui:state(state)
	assert(ui.Queue.Visible and ui.Spectate.Visible and not ui.Press.Visible)
	attributes.InRound = true; state.ReadyAt = 0; ui:state(state)
end)
test("Role instructions and bomb expiry appear once in the edge card", function()
	attributes.EventHint = "Tag someone to pass the bomb!"; attributes.EventTimer = 105
	ui:tick(true)
	assert(ui.EventDescription.Text == attributes.EventHint and ui.Hint.Text == "BOMB  5s")
	attributes.EventHint, attributes.EventTimer = nil, nil
	ui:tick(true); assert(ui.EventDescription.Text == state.EventDescription and not ui.Hint.Visible)
end)
test("Shared phase instructions are not repeated as role hints or event toasts", function()
	attributes.EventHint = state.EventDescription; attributes.Role = "Cop"
	ui:tick(true)
	assert(ui.EventDescription.Text == state.EventDescription and not ui.Hint.Visible)
	ui.Toast.Visible = false
	ui:toast(state.EventDescription, "event"); assert(not ui.Toast.Visible)
	attributes.EventHint = "Catch the red robber after the head start"
	ui:tick(true); assert(ui.EventDescription.Text == attributes.EventHint and ui.Hint.Text == "COP")
	attributes.EventHint, attributes.Role = nil, "Survivor"
	input.TouchEnabled = false; env.viewport(1268, 572); ui:resize()
	assert(ui.EventTitle.TextSize == 15 and ui.EventDescription.TextSize == 13 and ui.NavButtons[1].TextSize == 13)
	assert(ui.Event.Size.X.Offset == 340 and ui.Event.Size.Y.Offset == 96 and ui.EventDescription.Size.Y.Offset == 50)
end)
test("Owner-only instructions override public hints without repeating a shared instruction", function()
	attributes.PrivateRole = "Sheriff"
	attributes.PrivateHint = "Find the murderer before they catch you."
	ui:tick(true)
	assert(ui.EventDescription.Text == attributes.PrivateHint and ui.Hint.Text == "SHERIFF")
	ui.Toast.Visible = false; ui:toast(attributes.PrivateHint, "event"); assert(not ui.Toast.Visible)
	attributes.PrivateHint = state.EventDescription; ui:tick(true)
	assert(ui.EventDescription.Text == state.EventDescription and not ui.Hint.Visible)
	attributes.PrivateRole, attributes.PrivateHint = nil, nil
end)
test("The classic supplies shop uses Tokens and enforces stock and lobby availability", function()
	attributes.InRound = false
	local data = Profile.new(100)
	ui:profile(data, false); ui:open("Shop")
	assert(ui.Tokens.Text == "100 Tokens" and ui.Balance.Text == "YOUR TOKENS: 100" and #ui.NavButtons == 3)
	assert(ui.EventTitle.Font == roblox.Enum.Font.SourceSansBold)
	local function medkitBuy() return ui.List:FindFirstChild("medkit"):FindFirstChild("Buy") end
	assert(medkitBuy().Active and medkitBuy().Text == "BUY  30 TOKENS")
	medkitBuy().Activated:Fire(); assert(purchase[1] == "Buy" and purchase[2] == "medkit")
	purchase = nil; data.Inventory.medkit = 5; ui:profile(data, false)
	assert(not medkitBuy().Active and medkitBuy().Text == "STOCK FULL")
	medkitBuy().Activated:Fire(); assert(purchase == nil)
	data.Inventory.medkit = 0; data.Tokens = 29; ui:profile(data, false)
	assert(not medkitBuy().Active)
	data.Tokens = 100; attributes.InRound = true; ui:state(state)
	assert(not medkitBuy().Active and medkitBuy().Text == "BUY IN LOBBY")
	medkitBuy().Activated:Fire(); assert(purchase == nil)
	ui:close()
end)
test("Results show the winner, ordered placements, rewards and remain dismissed for the round", function()
	attributes.InRound = false
	state.Phase = "Results"
	state.Results = { Outcome = "Winner", WinnerUserId = 7, WinnerName = "Test Player", Rows = {
		{ UserId = 8, Name = "Other Player", Place = 2, Survived = false, Tokens = 5, KOs = 1 },
		{ UserId = 7, Name = "Test Player", Place = 1, Survived = true, Tokens = 66, KOs = 0 },
	} }
	ui:state(state)
	assert(ui.Tab == "Results" and ui.Panel.Visible and ui.ReturnLobby.Visible)
	assert(ui.PanelTitle.Text == "WE HAVE A WINNER!" and ui.PanelSubtitle.Text:find("Test Player wins"))
	assert(ui.List:FindFirstChild("Result_7").LayoutOrder == 1 and ui.List:FindFirstChild("Result_8").LayoutOrder == 2)
	local rewardFound = false
	for _, text in ipairs(ui.List:GetDescendants()) do if text:IsA("TextLabel") and text.Text:find("66 TOKENS") then rewardFound = true end end
	assert(rewardFound)
	ui.ReturnLobby.Activated:Fire(); assert(not ui.Panel.Visible)
	ui:state(state); assert(not ui.Panel.Visible)
	state.RoundNumber += 1; ui:state(state); assert(ui.Panel.Visible)
	state.Phase, state.Results = "Round", nil; attributes.InRound = true; ui:state(state)
	assert(not ui.Panel.Visible)
end)
test("Spectating exposes separate controls and restores the lobby and round HUD", function()
	attributes.InRound = false; ui:state(state)
	assert(ui.Spectate.Visible)
	ui:spectating("Test Player", 1, 2)
	assert(ui.Spectator.Visible and not ui.Spectate.Visible and ui.WatchPrevious.Active and ui.WatchNext.Active)
	ui:spectating("Only Survivor", 1, 1)
	assert(ui.Spectator.Visible and not ui.WatchPrevious.Active and not ui.WatchNext.Active)
	ui:open("Roster"); assert(not ui.Spectator.Visible); ui:close(); assert(ui.Spectator.Visible)
	ui:spectating(nil); assert(not ui.Spectator.Visible and ui.Spectate.Visible)
	attributes.InRound = true; ui:tick(true); assert(not ui.Spectate.Visible and not ui.Spectator.Visible)
end)
local bindings = {}
env.Services.RunService = {
	BindToRenderStep = function(_, name, priority, callback) bindings[name] = { Priority = priority, Callback = callback } end,
	UnbindFromRenderStep = function(_, name) bindings[name] = nil end,
}
env.Services.SoundService = env.Game:GetService("SoundService")
env.Services.ReplicatedStorage.WaitForChild = function() return { WaitForChild = function() return AudioCatalog end } end
-- Lune's userdata don't carry Roblox's typeof result into a custom module environment.
env.Env.typeof = function(value)
	if type(value) == "userdata" then
		local ok, x, y, z = pcall(function() return value.X, value.Y, value.Z end)
		if ok and type(x) == "number" and type(y) == "number" and type(z) == "number" then return "Vector3" end
	end
	return type(value)
end
local clock = 1
local feedback = env.load("src/client/Feedback.luau").new(nil, { Subject = function() return player end, Clock = function() return clock end })
feedback:state({ Phase = "Round", RoundNumber = 4 })
local camera = env.Workspace.CurrentCamera
camera.CameraType = roblox.Enum.CameraType.Custom
local original = roblox.CFrame.new(0, 40, 10)
camera.CFrame = original
test("Shake and local flashes remain bounded and finish without camera drift", function()
	feedback:cue({ Kind = "impact", RoundId = 4, Position = root.Position, Strength = 1 })
	assert(feedback.Shake > 0 and feedback.Flash > 0)
	for _ = 1, 120 do
		feedback:removeOffset(); assert((camera.CFrame.Position - original.Position).Magnitude < 0.0001)
		clock += 0.016; feedback:step(0.016)
		assert((camera.CFrame.Position - original.Position).Magnitude < 0.5)
		assert(feedback.Bloom.Intensity <= 0.12 and feedback.Color.Brightness <= 0.045)
	end
	feedback:removeOffset(); assert((camera.CFrame.Position - original.Position).Magnitude < 0.0001)
end)
test("Stale, distant and lobby cues cannot shake the camera or add sounds", function()
	feedback.Shake, feedback.Flash = 0, 0
	local function soundCount() local count = 0; for _ in pairs(feedback.Sounds) do count += 1 end; return count end
	local before = soundCount()
	feedback:cue({ Kind = "impact", RoundId = 3, Strength = 1 })
	feedback:cue({ Kind = "impact", RoundId = 4, Position = roblox.Vector3.new(220, 14, 0), Strength = 1 })
	attributes.InRound = false; feedback:cue({ Kind = "impact", RoundId = 4, Strength = 1 }); attributes.InRound = true
	assert(feedback.Shake == 0 and feedback.Flash == 0 and soundCount() == before)
end)
test("Press audio uses the catalog and cosmetic overrides no longer affect playback", function()
	clock += 1
	local sound = feedback:play("press", 9, { SoundId = "rbxasset://sounds/action_get_up.mp3", PlaybackSpeed = 20 })
	assert(sound.SoundId == AudioCatalog.press.SoundId and math.abs(sound.PlaybackSpeed - AudioCatalog.press.PlaybackSpeed) < 0.0001 and sound.Volume <= 0.5)
	clock += 1
	local impact = feedback:play("impact", 1, { SoundId = "rbxassetid://123" })
	assert(impact.SoundId == AudioCatalog.impact.SoundId)
end)
test("Lobby rewards and purchases play audio without camera effects or accepting hazard cues", function()
	clock += 1
	attributes.InRound = false; feedback:state({ Phase = "Waiting", RoundNumber = 4 })
	feedback.Shake, feedback.Flash = 0, 0
	for _, kind in ipairs({ "purchase", "checkpoint", "obby" }) do
		feedback:cue({ Kind = kind, Local = true, Strength = 0.8 })
		assert(feedback.LastSounds[kind] == clock)
	end
	feedback:cue({ Kind = "explosion", Local = true, Strength = 1 })
	assert(feedback.Shake == 0 and feedback.Flash == 0)
	attributes.InRound = true; feedback:state({ Phase = "Round", RoundNumber = 4 })
end)
test("Winner fanfare plays once whether the finish cue arrives before results or is missed", function()
	local calls = {}
	local realPlay = feedback.play
	feedback.play = function(_, kind) calls[kind] = (calls[kind] or 0) + 1; return true end
	feedback:state({ Phase = "Results", RoundNumber = 4, Results = { WinnerUserId = 7 } })
	assert(calls.victory == 1)
	feedback:state({ Phase = "Results", RoundNumber = 4, Results = { WinnerUserId = 7 } })
	assert(calls.victory == 1)
	feedback:state({ Phase = "Round", RoundNumber = 5 })
	feedback:cue({ Kind = "victory", RoundId = 5, Strength = 1 })
	feedback:state({ Phase = "Results", RoundNumber = 5, Results = { WinnerUserId = 7 } })
	assert(calls.victory == 2)
	feedback.play = realPlay
	feedback:state({ Phase = "Round", RoundNumber = 4 })
end)
test("Camera replacement recreates destroyed effects and even relief tint stays almost white", function()
	local oldBloom, oldColor = feedback.Bloom, feedback.Color
	camera:Destroy()
	camera = roblox.Instance.new("Camera"); camera.Parent = env.Workspace
	camera.CFrame, camera.CameraType = original, roblox.Enum.CameraType.Custom
	env.Workspace.CurrentCamera = camera
	feedback:cue({ Kind = "relief", RoundId = 4, Position = root.Position, Strength = 100 })
	feedback:step(0.016)
	assert(feedback.Bloom ~= oldBloom and feedback.Color ~= oldColor)
	assert(feedback.Bloom.Parent == camera and feedback.Color.Parent == camera and not oldBloom.Parent and not oldColor.Parent)
	local tint = feedback.Color.TintColor
	assert(tint.R > 0.98 and tint.G > 0.98 and tint.B > 0.98 and feedback.Color.Saturation == 0)
	assert(camera.CameraType == roblox.Enum.CameraType.Custom)
	feedback:removeOffset()
end)
test("Muting stops active SFX, external camera changes survive, and teardown releases resources", function()
	assert(feedback:toggleMuted() and next(feedback.Sounds) == nil)
	clock += 1; assert(feedback:play("press", 1) == nil)
	feedback.Shake = 1; feedback:step(0.016)
	local changed = roblox.CFrame.new(25, 80, 15); camera.CFrame = changed
	feedback:removeOffset(); assert((camera.CFrame.Position - changed.Position).Magnitude < 0.0001)
	feedback:destroy()
	assert(next(bindings) == nil and not feedback.Bloom.Parent and not feedback.Color.Parent and not feedback.Folder.Parent)
end)
test("Main client cycles living spectators, handles respawns and disconnects on teardown", function()
	local function signal()
		local result = { Callbacks = {} }
		function result:Connect(callback)
			table.insert(self.Callbacks, callback)
			return { Disconnect = function()
				local at = table.find(self.Callbacks, callback)
				if at then table.remove(self.Callbacks, at) end
			end }
		end
		function result:Fire(...)
			for _, callback in ipairs(table.clone(self.Callbacks)) do callback(...) end
		end
		return result
	end
	local network = {}
	for _, name in ipairs({ "Press", "Queue", "Shop", "Profile", "State", "Toast", "Leaderboard", "Countdown", "Cue", "PrivateState" }) do
		network[name] = { OnClientEvent = signal(), FireServer = function() end }
	end
	function network:WaitForChild(name) return self[name] end
	input.InputBegan = signal()
	env.Services.RunService.RenderStepped = signal()
	local inRoundChanged = signal()
	player.CharacterAdded = signal()
	player.GetAttributeChangedSignal = function() return inRoundChanged end
	attributes.InRound = false
	local players = env.Services.Players
	local function contender(userId, name)
		local avatar = roblox.Instance.new("Model")
		local body = roblox.Instance.new("Humanoid"); body.Health = 100; body.Parent = avatar
		local pivot = roblox.Instance.new("Part"); pivot.Name = "HumanoidRootPart"; pivot.Parent = avatar
		local subject = { UserId = userId, DisplayName = name, Parent = players, Character = avatar, Alive = true }
		subject.GetAttribute = function(_, attribute) return attribute == "InRound" and subject.Alive end
		return subject, body
	end
	local one, firstHumanoid = contender(8, "First")
	local two, secondHumanoid = contender(9, "Second")
	players.GetPlayers = function() return { player, two, one } end
	local storage = env.Services.ReplicatedStorage
	storage.WaitForChild = function(_, name) return name == "Shared" and storage.Shared or network end
	local mainUI
	local uiModule = env.load("src/client/UI.luau")
	local feedbackModule = env.load("src/client/Feedback.luau")
	local destroying = signal()
	env.Env.script = { Parent = { UI = { new = function(callbacks) mainUI = uiModule.new(callbacks); return mainUI end }, Feedback = feedbackModule }, Destroying = destroying }
	camera.ViewportSize = roblox.Vector2.new(1280, 720)
	env.load("src/client/Main.client.luau")
	network.State.OnClientEvent:Fire({ Phase = "Round", RoundNumber = 9, AliveCount = 2, Roster = {}, EventDescription = "Survive!" })
	mainUI.Spectate.Activated:Fire()
	assert(camera.CameraSubject == firstHumanoid and mainUI.SpectatingName == "First")
	mainUI.WatchNext.Activated:Fire(); assert(camera.CameraSubject == secondHumanoid)
	mainUI.WatchNext.Activated:Fire(); assert(camera.CameraSubject == firstHumanoid)
	mainUI.WatchPrevious.Activated:Fire(); assert(camera.CameraSubject == secondHumanoid)
	two.Alive = false; secondHumanoid.Health = 0
	env.Services.RunService.RenderStepped:Fire(0.2)
	assert(camera.CameraSubject == firstHumanoid and mainUI.SpectatingName == "First")
	local replacement = roblox.Instance.new("Model")
	local replacementHumanoid = roblox.Instance.new("Humanoid"); replacementHumanoid.Health = 100; replacementHumanoid.Parent = replacement
	player.Character = replacement; player.CharacterAdded:Fire(replacement)
	assert(camera.CameraSubject == firstHumanoid)
	attributes.InRound = true; inRoundChanged:Fire()
	assert(camera.CameraSubject == replacementHumanoid and not mainUI.SpectatingName and not mainUI.Spectator.Visible)
	network.PrivateState.OnClientEvent:Fire({ RoundId = 8, Role = "Murderer", Hint = "Stale instructions" })
	assert(not attributes.PrivateRole and not attributes.PrivateHint)
	network.PrivateState.OnClientEvent:Fire({ RoundId = 9, Role = "Sheriff", Hint = "Find the murderer" })
	assert(attributes.PrivateRole == "Sheriff" and attributes.PrivateHint == "Find the murderer")
	network.PrivateState.OnClientEvent:Fire({ RoundId = 9, Hint = "Updated clue" })
	assert(attributes.PrivateRole == "Sheriff" and attributes.PrivateHint == "Updated clue")
	network.PrivateState.OnClientEvent:Fire({ RoundId = 9, Role = false })
	assert(attributes.PrivateRole == nil and attributes.PrivateHint == "Updated clue")
	network.PrivateState.OnClientEvent:Fire({ Clear = true })
	assert(attributes.PrivateRole == nil and attributes.PrivateHint == nil)
	network.PrivateState.OnClientEvent:Fire({ RoundId = 9, Role = "Murderer", Hint = "Secret" })
	attributes.InRound = false; inRoundChanged:Fire()
	assert(attributes.PrivateRole == nil and attributes.PrivateHint == nil)
	network.PrivateState.OnClientEvent:Fire({ RoundId = 9, Role = "Murderer", Hint = "Late clue" })
	assert(attributes.PrivateRole == nil and attributes.PrivateHint == nil)
	attributes.InRound = true
	network.PrivateState.OnClientEvent:Fire({ RoundId = 9, Role = "Sheriff", Hint = "Secret" })
	network.State.OnClientEvent:Fire({ Phase = "Round", RoundNumber = 10, Roster = {} })
	assert(attributes.PrivateRole == nil and attributes.PrivateHint == nil)
	destroying:Fire()
	assert(next(bindings) == nil and #input.InputBegan.Callbacks == 0 and #env.Services.RunService.RenderStepped.Callbacks == 0)
	assert(#network.State.OnClientEvent.Callbacks == 0 and #network.PrivateState.OnClientEvent.Callbacks == 0 and #player.CharacterAdded.Callbacks == 0 and #inRoundChanged.Callbacks == 0)
end)
print("\n" .. passed .. " client checks passed. Actual touch controls, camera comfort and audio remain Studio playtest checks.")
