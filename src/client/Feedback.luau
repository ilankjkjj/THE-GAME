-- Local feedback is deliberately small: it accents nearby action without owning
-- the camera or changing replicated lighting and audio.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local AudioCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("AudioCatalog"))
local Feedback = {}
Feedback.__index = Feedback
local activeController
local profiles = {
	press = { Shake = 0.1, Flash = 0.08, Color = Color3.fromRGB(255, 224, 185) },
	warning = { Shake = 0, Flash = 0.06, Color = Color3.fromRGB(255, 211, 183) },
	impact = { Shake = 0.65, Flash = 0.18, Color = Color3.fromRGB(255, 229, 197) },
	lightning = { Shake = 0.55, Flash = 0.3, Color = Color3.fromRGB(219, 235, 255) },
	explosion = { Shake = 0.8, Flash = 0.28, Color = Color3.fromRGB(255, 208, 178) },
	eruption = { Shake = 0.6, Flash = 0.22, Color = Color3.fromRGB(255, 203, 167) },
	flood = { Shake = 0.06, Flash = 0.08, Color = Color3.fromRGB(218, 237, 255) },
	storm = { Shake = 0.5, Flash = 0.22, Color = Color3.fromRGB(221, 229, 255) },
	scifi = { Shake = 0.22, Flash = 0.16, Color = Color3.fromRGB(201, 227, 255) },
	chase = { Shake = 0.12, Flash = 0.08, Color = Color3.fromRGB(255, 222, 204) },
	relief = { Shake = 0, Flash = 0.08, Color = Color3.fromRGB(214, 255, 225) },
	eventstart = { Shake = 0.08, Flash = 0.08, Color = Color3.fromRGB(255, 238, 206) },
	roundstart = { Shake = 0, Flash = 0.06, Color = Color3.fromRGB(215, 255, 235) },
	roundend = { Shake = 0, Flash = 0.08, Color = Color3.fromRGB(255, 240, 193) },
	reward = { Shake = 0, Flash = 0.06, Color = Color3.fromRGB(255, 241, 201) },
	purchase = { Shake = 0, Flash = 0, Color = Color3.new(1, 1, 1) },
	supply = { Shake = 0, Flash = 0.05, Color = Color3.fromRGB(230, 255, 230) },
	sword = { Shake = 0.04, Flash = 0, Color = Color3.new(1, 1, 1) },
	gunshot = { Shake = 0.09, Flash = 0.04, Color = Color3.fromRGB(255, 238, 220) },
	role = { Shake = 0, Flash = 0.04, Color = Color3.fromRGB(225, 238, 255) },
	knockout = { Shake = 0, Flash = 0.04, Color = Color3.fromRGB(255, 240, 210) },
	checkpoint = { Shake = 0, Flash = 0.04, Color = Color3.fromRGB(225, 245, 255) },
	obby = { Shake = 0, Flash = 0.06, Color = Color3.fromRGB(255, 244, 200) },
	victory = { Shake = 0, Flash = 0.08, Color = Color3.fromRGB(255, 240, 193) },
}
local fallbacks = {
	press = "rbxasset://sounds/action_jump_land.mp3", warning = "rbxasset://sounds/action_get_up.mp3",
	impact = "rbxasset://sounds/impact_explosion_03.mp3", lightning = "rbxasset://sounds/impact_explosion_03.mp3",
	explosion = "rbxasset://sounds/impact_explosion_03.mp3", eruption = "rbxasset://sounds/impact_explosion_03.mp3",
	flood = "rbxasset://sounds/impact_water.mp3",
	storm = "rbxasset://sounds/impact_explosion_03.mp3", scifi = "rbxasset://sounds/action_get_up.mp3",
	chase = "rbxasset://sounds/action_get_up.mp3", relief = "rbxasset://sounds/action_get_up.mp3",
	eventstart = "rbxasset://sounds/action_get_up.mp3", roundstart = "rbxasset://sounds/action_get_up.mp3",
	roundend = "rbxasset://sounds/action_get_up.mp3", reward = "rbxasset://sounds/action_get_up.mp3",
	purchase = "rbxasset://sounds/action_get_up.mp3", supply = "rbxasset://sounds/action_get_up.mp3",
	sword = "rbxasset://sounds/action_jump_land.mp3", gunshot = "rbxasset://sounds/impact_explosion_03.mp3",
	role = "rbxasset://sounds/action_get_up.mp3", knockout = "rbxasset://sounds/action_get_up.mp3",
	checkpoint = "rbxasset://sounds/action_get_up.mp3", obby = "rbxasset://sounds/action_get_up.mp3",
	victory = "rbxasset://sounds/action_get_up.mp3",
}
local localKinds = { purchase = true, checkpoint = true, obby = true, knockout = true, victory = true, reward = true }
local function finite(value, default)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge and value or default
end
local function normalized(kind)
	return type(kind) == "string" and string.lower(kind):gsub("[%s_%-]", "") or "impact"
end
function Feedback.new(network, options)
	if activeController then activeController:destroy() end
	options = options or {}
	local self = setmetatable({
		Subject = options.Subject or function() return Players.LocalPlayer end,
		Clock = options.Clock or os.clock, Muted = false, Shake = 0, Flash = 0,
		Tint = Color3.new(1, 1, 1), Connections = {}, Sounds = {}, LastSounds = {},
		Destroyed = false, WasParticipant = false,
	}, Feedback)
	activeController = self
	self.Folder = Instance.new("Folder")
	self.Folder.Name = "ButtonLocalAudio"
	self.Folder.Parent = SoundService
	self:attachCamera()
	if network then
		table.insert(self.Connections, network:WaitForChild("Cue").OnClientEvent:Connect(function(cue) self:cue(cue) end))
		table.insert(self.Connections, network.State.OnClientEvent:Connect(function(state) self:state(state) end))
	end
	-- Remove exactly our prior transform before Roblox computes the next camera.
	-- Recording the base transform avoids rounding drift and respects external changes.
	RunService:BindToRenderStep("ButtonFeedbackRemove", Enum.RenderPriority.Camera.Value - 1, function() self:removeOffset() end)
	RunService:BindToRenderStep("ButtonFeedbackApply", Enum.RenderPriority.Camera.Value + 1, function(delta) self:step(delta) end)
	return self
end
function Feedback:attachCamera()
	local camera = workspace.CurrentCamera
	if camera and (self.EffectsCamera ~= camera or not self.Bloom or self.Bloom.Parent ~= camera) then
		-- CurrentCamera replacement destroys the old camera's descendants. New
		-- effects must be created; destroyed instances cannot be reparented.
		if self.Bloom then self.Bloom:Destroy() end
		if self.Color then self.Color:Destroy() end
		self.Bloom = Instance.new("BloomEffect")
		self.Bloom.Name = "ButtonLocalBloom"
		self.Bloom.Intensity, self.Bloom.Size, self.Bloom.Threshold = 0, 16, 1.7
		self.Bloom.Enabled = false
		self.Color = Instance.new("ColorCorrectionEffect")
		self.Color.Name = "ButtonLocalAccent"
		self.Color.Brightness, self.Color.Contrast, self.Color.Saturation = 0, 0, 0
		self.Color.Enabled = false
		self.Color.TintColor = Color3.new(1, 1, 1)
		self.Bloom.Parent = camera
		self.Color.Parent = camera
		self.EffectsCamera = camera
	end
	return camera
end
function Feedback:viewer()
	local subject = self.Subject()
	if not subject or subject:GetAttribute("InRound") ~= true then return end
	local character = subject.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root then return root end
end
function Feedback:play(kind, amount)
	if self.Destroyed or self.Muted then return end
	kind = normalized(kind)
	local entry = AudioCatalog[kind]
	if not entry and not fallbacks[kind] then return end
	entry = entry or {}
	local at = self.Clock()
	if at < (self.LastSounds[kind] or -math.huge) + 0.12 then return end
	self.LastSounds[kind] = at
	local count = 0
	for object in pairs(self.Sounds) do if object.Parent then count += 1 else self.Sounds[object] = nil end end
	if count >= 10 then return end
	local sound = Instance.new("Sound")
	sound.Name = "Cue_" .. kind
	sound.SoundId = type(entry.SoundId) == "string" and entry.SoundId ~= "" and entry.SoundId or fallbacks[kind]
	sound.Volume = math.clamp(finite(entry.Volume, 0.28) * math.clamp(amount or 1, 0, 1), 0, 0.5)
	sound.PlaybackSpeed = math.clamp(finite(entry.PlaybackSpeed, 1), 0.5, 2)
	sound.Parent = self.Folder
	self.Sounds[sound] = true
	sound:Play()
	task.delay(math.clamp(finite(entry.Duration, 3), 0.2, 10), function()
		if self.Sounds[sound] then self.Sounds[sound] = nil; sound:Destroy() end
	end)
	return sound
end
function Feedback:cue(cue)
	if self.Destroyed or type(cue) ~= "table" then return end
	local kind = normalized(cue.Kind)
	if cue.Local == true and localKinds[kind] then self:play(kind, math.clamp(finite(cue.Strength, 0.7), 0, 1)); return end
	if not self.State or self.State.Phase ~= "Round" then return end
	local roundId = self.State.RoundId or self.State.RoundNumber
	if type(cue.RoundId) == "number" and type(roundId) == "number" and cue.RoundId ~= roundId then return end
	local root = self:viewer()
	if not root then return end
	local attenuation = 1
	if typeof(cue.Position) == "Vector3" then
		attenuation = math.clamp(1 - (root.Position - cue.Position).Magnitude / 110, 0, 1)
	end
	if attenuation <= 0.03 then return end
	local profile = profiles[kind] or profiles.impact
	local strength = math.clamp(finite(cue.Strength, 1), 0, 1.5) * attenuation
	self.Shake = math.min(1, self.Shake + profile.Shake * strength)
	self.Flash = math.min(0.45, self.Flash + profile.Flash * strength)
	self.Tint = profile.Color
	local played = self:play(kind, math.min(1, strength))
	if played and (kind == "victory" or kind == "roundend") then self.FinishCueRound = roundId end
end
function Feedback:state(state)
	if self.Destroyed or type(state) ~= "table" then return end
	local previous = self.State
	self.State = state
	if state.Phase == "Round" then
		self.WasParticipant = self.WasParticipant or self:viewer() ~= nil
		if previous and previous.Phase ~= "Round" and self.WasParticipant then self:play("roundstart", 0.7) end
	elseif previous and previous.Phase == "Round" then
		self.Shake = 0
		local roundId = state.RoundId or state.RoundNumber
		if self.WasParticipant and self.FinishCueRound ~= roundId then
			local won = state.Results and state.Results.WinnerUserId == Players.LocalPlayer.UserId
			self:play(won and "victory" or "roundend", 0.7)
		end
		self.WasParticipant = false
	end
end
function Feedback:removeOffset()
	local camera = self.LastCamera
	if camera and camera.Parent and self.LastApplied then
		local current = camera.CFrame
		local samePosition = (current.Position - self.LastApplied.Position).Magnitude < 0.0001
		local sameRotation = (current.LookVector - self.LastApplied.LookVector).Magnitude < 0.0001 and (current.UpVector - self.LastApplied.UpVector).Magnitude < 0.0001
		if samePosition and sameRotation then camera.CFrame = self.LastBase end
	end
	self.LastCamera, self.LastApplied, self.LastBase = nil, nil, nil
end
function Feedback:step(delta)
	if self.Destroyed then return end
	self:removeOffset()
	local camera = self:attachCamera()
	delta = math.clamp(finite(delta, 0.016), 0, 0.1)
	self.Shake = math.max(0, self.Shake - delta * 2.6)
	self.Flash = math.max(0, self.Flash - delta * 1.8)
	if not camera then self.Shake, self.Flash = 0, 0; return end
	local viewer = self:viewer()
	if not self.State or self.State.Phase ~= "Round" or not viewer then self.Shake = 0; self.Flash = 0 end
	self.Bloom.Enabled = self.Flash > 0.001
	self.Color.Enabled = self.Flash > 0.001
	self.Bloom.Intensity = math.min(0.12, self.Flash * 0.26)
	self.Color.Brightness = math.min(0.045, self.Flash * 0.1)
	self.Color.Contrast = math.min(0.03, self.Flash * 0.06)
	self.Color.TintColor = Color3.new(1, 1, 1):Lerp(self.Tint, math.min(0.07, self.Flash * 0.15))
	if not camera or self.Shake <= 0 or camera.CameraType == Enum.CameraType.Scriptable then return end
	local at, amplitude = self.Clock(), self.Shake
	local offset = CFrame.new(math.sin(at * 67) * 0.36 * amplitude, math.sin(at * 53 + 1.3) * 0.26 * amplitude, math.sin(at * 41) * 0.08 * amplitude)
		* CFrame.Angles(math.sin(at * 47) * 0.008 * amplitude, math.sin(at * 43) * 0.006 * amplitude, math.sin(at * 59) * 0.006 * amplitude)
	self.LastCamera, self.LastBase = camera, camera.CFrame
	self.LastApplied = camera.CFrame * offset
	camera.CFrame = self.LastApplied
end
function Feedback:toggleMuted()
	self.Muted = not self.Muted
	if self.Muted then
		for sound in pairs(self.Sounds) do sound:Destroy() end
		self.Sounds = {}
	end
	return self.Muted
end
function Feedback:destroy()
	if self.Destroyed then return end
	self.Destroyed = true
	RunService:UnbindFromRenderStep("ButtonFeedbackRemove")
	RunService:UnbindFromRenderStep("ButtonFeedbackApply")
	self:removeOffset()
	for _, connection in ipairs(self.Connections) do connection:Disconnect() end
	self.Connections = {}
	self.Sounds = {}
	self.Folder:Destroy()
	if self.Bloom then self.Bloom:Destroy() end
	if self.Color then self.Color:Destroy() end
	self.EffectsCamera = nil
	if activeController == self then activeController = nil end
end
return Feedback
