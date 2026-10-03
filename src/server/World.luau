local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local World = {}

local colors = {
	Grass = Color3.fromRGB(119, 202, 111), Cream = Color3.fromRGB(255, 247, 223),
	Wood = Color3.fromRGB(194, 145, 91), DarkWood = Color3.fromRGB(112, 80, 55),
	Ink = Color3.fromRGB(41, 69, 87), Teal = Color3.fromRGB(43, 190, 179), Gold = Color3.fromRGB(255, 203, 81),
}
local roofs = {
	Color3.fromRGB(248, 120, 111), Color3.fromRGB(95, 186, 223), Color3.fromRGB(255, 190, 85),
	Color3.fromRGB(183, 148, 230), Color3.fromRGB(67, 185, 157), Color3.fromRGB(244, 152, 188),
}
local palettes = {
	Normal = { colors.Grass, colors.Teal, 13.8 },
	Cosmic = { Color3.fromRGB(112, 134, 218), Color3.fromRGB(196, 159, 255), 20 },
	Candy = { Color3.fromRGB(244, 182, 210), Color3.fromRGB(248, 117, 157), 14 },
	Gold = { Color3.fromRGB(225, 196, 117), colors.Gold, 16 },
}

function World.part(parent, name, size, position, color, material, shape)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Anchored = true
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if shape then part.Shape = shape end
	part.Parent = parent
	return part
end

function World.sign(part, face, text, color, pixels)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Sign"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixels or 35
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold)
	label.Text = text
	label.TextScaled = true
	label.TextWrapped = true
	label.TextColor3 = color or colors.Ink
	label.Parent = gui
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.09, 0)
	padding.PaddingBottom = UDim.new(0.09, 0)
	padding.PaddingLeft = UDim.new(0.07, 0)
	padding.PaddingRight = UDim.new(0.07, 0)
	padding.Parent = label
	return label
end

local function folder(parent, name)
	local result = Instance.new("Folder")
	result.Name = name
	result.Parent = parent
	return result
end

local function decorative(part)
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	return part
end

local function localPart(parent, frame, name, size, offset, color, material)
	local part = World.part(parent, name, size, frame:PointToWorldSpace(offset), color, material)
	part.CFrame = frame * CFrame.new(offset)
	return part
end

local function tree(parent, position, scale)
	local trunk = World.part(parent, "TreeTrunk", Vector3.new(1.4, 6, 1.4) * scale, position + Vector3.new(0, 3, 0) * scale, colors.DarkWood, Enum.Material.Wood)
	trunk.CanCollide = false
	for index, offset in ipairs({ Vector3.new(0, 7.8, 0), Vector3.new(-1.6, 6.6, 0.4), Vector3.new(1.5, 6.7, -0.4) }) do
		decorative(World.part(parent, "TreeCrown", Vector3.new(6.2, 5.6, 6.2) * scale, position + offset * scale,
			index == 1 and Color3.fromRGB(73, 168, 107) or Color3.fromRGB(103, 193, 112), Enum.Material.Grass, Enum.PartType.Ball))
	end
end

local function floatingBase(parent, position, width, depth)
	decorative(World.part(parent, "EarthLayer", Vector3.new(width * 0.97, 3, depth * 0.97), position - Vector3.new(0, 2.5, 0), Color3.fromRGB(146, 108, 72), Enum.Material.Ground))
	decorative(World.part(parent, "RockLayer", Vector3.new(width * 0.84, 5, depth * 0.84), position - Vector3.new(0, 7.2, 0), Color3.fromRGB(160, 175, 177), Enum.Material.Rock))
	local tip = decorative(World.part(parent, "FloatingRock", Vector3.new(width * 0.61, 10, depth * 0.61), position - Vector3.new(0, 12.5, 0), Color3.fromRGB(132, 149, 155), Enum.Material.Rock))
	tip.Orientation = Vector3.new(0, 18, 18)
end

local function cottage(parent, frame, tint, number)
	local home = folder(parent, "Cottage" .. number)
	local wall = Color3.fromRGB(255, 242, 211)
	localPart(home, frame, "Porch", Vector3.new(10, 0.4, 11), Vector3.new(0, 0.22, 2.8), colors.Wood, Enum.Material.WoodPlanks)
	localPart(home, frame, "LeftWall", Vector3.new(0.55, 6, 9), Vector3.new(-4.5, 3.3, 3.3), wall)
	localPart(home, frame, "RightWall", Vector3.new(0.55, 6, 9), Vector3.new(4.5, 3.3, 3.3), wall)
	localPart(home, frame, "BackWall", Vector3.new(9, 6, 0.55), Vector3.new(0, 3.3, 7.8), wall)
	for _, x in ipairs({ -3, 3 }) do
		localPart(home, frame, "FrontWall", Vector3.new(3, 6, 0.55), Vector3.new(x, 3.3, -1.2), wall)
		localPart(home, frame, "PorchPost", Vector3.new(0.35, 5.7, 0.35), Vector3.new(x * 1.45, 3, -2.2), colors.DarkWood, Enum.Material.Wood)
	end
	localPart(home, frame, "DoorLintel", Vector3.new(3, 1, 0.6), Vector3.new(0, 5.8, -1.2), tint)
	for _, x in ipairs({ -4.83, 4.83 }) do
		local window = localPart(home, frame, "Window", Vector3.new(0.06, 2.4, 3), Vector3.new(x, 3.5, 3.2), Color3.fromRGB(146, 220, 239), Enum.Material.Glass)
		window.Transparency = 0.2
		window.CanCollide = false
		localPart(home, frame, "WindowSill", Vector3.new(0.35, 0.3, 3.4), Vector3.new(x, 2.1, 3.2), tint)
	end
	for _, direction in ipairs({ -1, 1 }) do
		local roof = localPart(home, frame, "Roof", Vector3.new(5.9, 0.7, 11), Vector3.new(direction * 2.35, 7, 3.3), tint)
		roof.CFrame = roof.CFrame * CFrame.Angles(0, 0, math.rad(-direction * 25))
	end
	localPart(home, frame, "RoofRidge", Vector3.new(0.65, 0.65, 11.4), Vector3.new(0, 8.23, 3.3), tint)
	local plaque = localPart(home, frame, "HouseNumber", Vector3.new(2, 0.8, 0.13), Vector3.new(0, 5.1, -1.54), colors.Cream)
	World.sign(plaque, Enum.NormalId.Front, string.format("%02d", number), tint, 45)
	localPart(home, frame, "PorchStep", Vector3.new(5, 0.24, 1.5), Vector3.new(0, 0.12, -3.2), colors.Wood, Enum.Material.WoodPlanks)
end

local function board(parent, name, position, width, height, text, color)
	World.part(parent, name .. "Frame", Vector3.new(width + 0.6, height + 0.6, 0.7), position, colors.DarkWood, Enum.Material.Wood)
	local panel = World.part(parent, name, Vector3.new(width, height, 0.12), position + Vector3.new(0, 0, 0.42), colors.Cream)
	for _, x in ipairs({ -width / 2 + 1.5, width / 2 - 1.5 }) do
		World.part(parent, name .. "Post", Vector3.new(0.65, 4, 0.65), Vector3.new(position.X + x, position.Y - height / 2 - 1.7, position.Z), colors.DarkWood, Enum.Material.Wood)
	end
	return World.sign(panel, Enum.NormalId.Back, text, color or colors.Ink, 24)
end

local function lighting()
	Lighting.Brightness = 2.8
	Lighting.ClockTime = 13.8
	Lighting.Ambient = Color3.fromRGB(145, 164, 174)
	Lighting.OutdoorAmbient = Color3.fromRGB(175, 190, 190)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 229, 192)
	Lighting.ColorShift_Bottom = Color3.fromRGB(217, 237, 255)
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 0.7
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.ExposureCompensation = 0.08
	Lighting.FogColor = Color3.fromRGB(194, 226, 247)
	Lighting.FogStart = 400
	Lighting.FogEnd = 1800
	for _, name in ipairs({ "ButtonAtmosphere", "ButtonBloom", "ButtonColor", "ButtonSun", "ButtonSky" }) do
		local old = Lighting:FindFirstChild(name)
		if old then old:Destroy() end
	end
	local legacyBloom = Lighting:FindFirstChild("Bloom")
	if legacyBloom and legacyBloom:IsA("BloomEffect") then legacyBloom:Destroy() end
	local sky = Instance.new("Sky")
	sky.Name = "ButtonSky"
	sky.SkyboxBk = "rbxasset://textures/sky/sky512_bk.tex"
	sky.SkyboxDn = "rbxasset://textures/sky/sky512_dn.tex"
	sky.SkyboxFt = "rbxasset://textures/sky/sky512_ft.tex"
	sky.SkyboxLf = "rbxasset://textures/sky/sky512_lf.tex"
	sky.SkyboxRt = "rbxasset://textures/sky/sky512_rt.tex"
	sky.SkyboxUp = "rbxasset://textures/sky/sky512_up.tex"
	sky.SunAngularSize = 10
	sky.Parent = Lighting
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "ButtonAtmosphere"
	atmosphere.Density = 0.22
	atmosphere.Offset = 0.25
	atmosphere.Color = Color3.fromRGB(213, 233, 250)
	atmosphere.Decay = Color3.fromRGB(238, 217, 175)
	atmosphere.Glare = 0.15
	atmosphere.Haze = 1.1
	atmosphere.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "ButtonBloom"
	bloom.Intensity = 0.12
	bloom.Size = 20
	bloom.Threshold = 1.8
	bloom.Parent = Lighting
	local correction = Instance.new("ColorCorrectionEffect")
	correction.Name = "ButtonColor"
	correction.Saturation = 0.08
	correction.Contrast = 0.03
	correction.TintColor = Color3.fromRGB(255, 248, 236)
	correction.Parent = Lighting
	local sun = Instance.new("SunRaysEffect")
	sun.Name = "ButtonSun"
	sun.Intensity = 0.045
	sun.Spread = 0.6
	sun.Parent = Lighting
end

function World.build()
	for _, name in ipairs({ "EditorFloor", "EditorSpawn", "ButtonRoom" }) do
		local old = workspace:FindFirstChild(name)
		if old then old:Destroy() end
	end
	World.Root = folder(workspace, "ButtonRoom")
	World.Arena = folder(World.Root, "Arena")
	World.Lobby = folder(World.Root, "Lobby")
	World.Effects = folder(World.Root, "EventEffects")
	World.Platforms, World.Bridges, World.ArenaSpawns, World.Accents = {}, {}, {}, {}
	World.Walls = {}
	World.Originals = {}
	World.Floor = World.part(World.Arena, "CentralHub", Vector3.new(2, 28, 28), Vector3.new(0, 29, 0), colors.Grass, Enum.Material.Grass, Enum.PartType.Cylinder)
	World.Floor.Orientation = Vector3.new(0, 0, 90)
	floatingBase(World.Arena, Vector3.new(0, 29, 0), 25, 25)
	local hubTrim = decorative(World.part(World.Arena, "HubTrim", Vector3.new(0.5, 29, 29), Vector3.new(0, 28.3, 0), colors.Wood, Enum.Material.Wood, Enum.PartType.Cylinder))
	hubTrim.Orientation = Vector3.new(0, 0, 90)
	for index = 1, 12 do
		local angle = math.rad((index - 1) * 30)
		local direction = Vector3.new(math.sin(angle), 0, math.cos(angle))
		local center = direction * 62 + Vector3.new(0, 29, 0)
		local island = folder(World.Arena, "Island" .. index)
		local ground = World.part(island, "HomePlatform", Vector3.new(18, 2, 18), center, colors.Grass, Enum.Material.Grass)
		local frame = CFrame.lookAt(center + Vector3.new(0, 1, 0), Vector3.new(0, 30, 0))
		ground.CFrame = frame * CFrame.new(0, -1, 0)
		ground:SetAttribute("IslandIndex", index)
		table.insert(World.Platforms, ground)
		table.insert(World.ArenaSpawns, frame:PointToWorldSpace(Vector3.new(0, 4, -4.8)))
		floatingBase(island, center, 18, 18)
		cottage(island, frame, roofs[(index - 1) % #roofs + 1], index)
		tree(island, frame:PointToWorldSpace(Vector3.new(-6.6, 0, 5.8)), 0.7)
		local bridge = World.part(World.Arena, "Bridge" .. index, Vector3.new(5, 1, 44), direction * 33 + Vector3.new(0, 29.5, 0), colors.Wood, Enum.Material.WoodPlanks)
		bridge.CFrame = CFrame.lookAt(bridge.Position, Vector3.new(0, 29.5, 0))
		table.insert(World.Bridges, bridge)
		for _, distance in ipairs({ 15, 51 }) do
			local stripe = decorative(World.part(World.Arena, "BridgeMarker", Vector3.new(5.02, 0.05, 1.4), direction * distance + Vector3.new(0, 30.03, 0), roofs[(index - 1) % #roofs + 1]))
			stripe.CFrame = CFrame.lookAt(stripe.Position, Vector3.new(0, stripe.Position.Y, 0))
		end
	end

	local base = World.part(World.Arena, "ButtonPedestal", Vector3.new(1.5, 11, 11), Vector3.new(0, 30.75, 0), colors.Cream, nil, Enum.PartType.Cylinder)
	base.Orientation = Vector3.new(0, 0, 90)
	local ring = World.part(World.Arena, "ButtonRing", Vector3.new(0.45, 9, 9), Vector3.new(0, 31.65, 0), colors.Gold, Enum.Material.Neon, Enum.PartType.Cylinder)
	ring.Orientation = base.Orientation
	table.insert(World.Accents, ring)
	World.Button = World.part(World.Arena, "Button", Vector3.new(1.65, 7.9, 7.9), Vector3.new(0, 32.65, 0), Color3.fromRGB(251, 83, 86), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	World.Button.Orientation = base.Orientation
	World.ButtonRest = World.Button.Position
	for index = 1, 4 do
		World.part(World.Arena, "ButtonStep", Vector3.new(4.8, 0.3 * index, 1.2), Vector3.new(0, 30 + 0.15 * index, 7.2 - index * 0.75), colors.Cream)
	end
	World.ButtonLight = Instance.new("PointLight")
	World.ButtonLight.Color = World.Button.Color
	World.ButtonLight.Brightness = 0.5
	World.ButtonLight.Range = 16
	World.ButtonLight.Parent = World.Button
	World.Prompt = Instance.new("ProximityPrompt")
	World.Prompt.ActionText = "Press for chaos"
	World.Prompt.ObjectText = "DON'T PRESS THE BUTTON"
	World.Prompt.KeyboardKeyCode = Enum.KeyCode.E
	World.Prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	World.Prompt.MaxActivationDistance = 15
	World.Prompt.RequiresLineOfSight = false
	World.Prompt.Enabled = false
	World.Prompt.Parent = World.Button
	World.Click = Instance.new("ClickDetector")
	World.Click.MaxActivationDistance = 15
	World.Click.Parent = World.Button
	local warning = decorative(World.part(World.Arena, "ButtonWarning", Vector3.new(15, 0.06, 2.2), Vector3.new(0, 30.07, -8.6), colors.Grass))
	World.sign(warning, Enum.NormalId.Top, "PRESS AT YOUR OWN RISK", colors.Ink, 42)

	-- A separate safe island keeps spectators out of the survival arena.
	World.LobbySpawn = Vector3.new(220, 14, 12)
	World.part(World.Lobby, "LobbyGround", Vector3.new(100, 4, 80), Vector3.new(220, 8, 0), colors.Grass, Enum.Material.Grass)
	floatingBase(World.Lobby, Vector3.new(220, 9, 0), 100, 80)
	World.part(World.Lobby, "Plaza", Vector3.new(67, 0.16, 52), Vector3.new(220, 10.08, 0), Color3.fromRGB(245, 228, 195), Enum.Material.Sandstone)
	World.part(World.Lobby, "WelcomePath", Vector3.new(14, 0.18, 74), Vector3.new(220, 10.1, 0), colors.Cream, Enum.Material.Sandstone)
	for _, spec in ipairs({
		{ Vector3.new(100, 0.6, 0.6), Vector3.new(220, 12.8, -39) },
		{ Vector3.new(100, 0.6, 0.6), Vector3.new(220, 12.8, 39) },
		{ Vector3.new(0.6, 0.6, 78), Vector3.new(171, 12.8, 0) },
		{ Vector3.new(0.6, 0.6, 78), Vector3.new(269, 12.8, 0) },
	}) do World.part(World.Lobby, "SafetyRail", spec[1], spec[2], colors.Cream, Enum.Material.Wood) end
	for _, x in ipairs({ 172, 188, 204, 220, 236, 252, 268 }) do
		for _, z in ipairs({ -39, 39 }) do World.part(World.Lobby, "RailPost", Vector3.new(0.7, 3, 0.7), Vector3.new(x, 11.5, z), colors.DarkWood, Enum.Material.Wood) end
	end
	for _, z in ipairs({ -23, -7, 9, 25 }) do
		for _, x in ipairs({ 171, 269 }) do World.part(World.Lobby, "RailPost", Vector3.new(0.7, 3, 0.7), Vector3.new(x, 11.5, z), colors.DarkWood, Enum.Material.Wood) end
	end
	for index, offset in ipairs({ Vector3.new(-8, 0, 15), Vector3.new(8, 0, 15), Vector3.new(-8, 0, 25), Vector3.new(8, 0, 25) }) do
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "LobbySpawn" .. index
		spawn.Anchored = true
		spawn.Neutral = true
		spawn.Duration = 0
		spawn.Size = Vector3.new(6, 0.2, 6)
		spawn.Position = Vector3.new(220, 10.2, 0) + offset
		spawn.Color = colors.Teal
		spawn.Material = Enum.Material.SmoothPlastic
		spawn.Transparency = 0.15
		spawn.Parent = World.Lobby
	end
	local welcome = World.part(World.Lobby, "WelcomeArch", Vector3.new(44, 5, 1.1), Vector3.new(220, 24, 34), colors.Cream)
	World.sign(welcome, Enum.NormalId.Front, "DON'T PRESS THE BUTTON", Color3.fromRGB(237, 103, 95), 30)
	for _, x in ipairs({ 199, 241 }) do World.part(World.Lobby, "WelcomePillar", Vector3.new(1.4, 14, 1.4), Vector3.new(x, 17, 34), colors.Teal) end
	World.LeaderboardLabel = board(World.Lobby, "LeaderboardBoard", Vector3.new(220, 18, -30), 24, 13, "MOST BUTTON PRESSES\n\nLoading leaderboard...", colors.Ink)
	World.RoundLabel = board(World.Lobby, "RoundBoard", Vector3.new(192, 17, -30), 22, 11, "NEXT ROUND\n\nWaiting for players", colors.Teal)
	World.CounterLabel = World.RoundLabel
	board(World.Lobby, "HowToPlay", Vector3.new(248, 17, -30), 22, 11, "LAST ONE STANDING\n\nPress the button for a random event.\nDodge danger. Outlast everyone.\nWin coins. Dress up. Go again!", colors.Ink)
	local portalCenter = Vector3.new(189, 10, 5)
	for _, x in ipairs({ -5.7, 5.7 }) do World.part(World.Lobby, "PortalPost", Vector3.new(1.2, 11, 1.4), portalCenter + Vector3.new(x, 5.5, 0), colors.Teal) end
	World.part(World.Lobby, "PortalTop", Vector3.new(12.8, 1.2, 1.4), portalCenter + Vector3.new(0, 11, 0), colors.Teal)
	local portal = decorative(World.part(World.Lobby, "RoundPortal", Vector3.new(10, 9.6, 0.15), portalCenter + Vector3.new(0, 5.2, 0), Color3.fromRGB(148, 232, 232), Enum.Material.Neon))
	portal.Transparency = 0.65
	World.sign(portal, Enum.NormalId.Back, "SURVIVAL ARENA\n\nPRESS E TO JOIN\nOR USE THE PLAY MENU", colors.Ink, 34)
	World.JoinPrompt = Instance.new("ProximityPrompt")
	World.JoinPrompt.ActionText = "Join next round"
	World.JoinPrompt.ObjectText = "SURVIVAL ARENA"
	World.JoinPrompt.KeyboardKeyCode = Enum.KeyCode.E
	World.JoinPrompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	World.JoinPrompt.MaxActivationDistance = 12
	World.JoinPrompt.RequiresLineOfSight = false
	World.JoinPrompt.Parent = portal
	for _, position in ipairs({ Vector3.new(179, 10, -35), Vector3.new(260, 10, -35), Vector3.new(180, 10, 29), Vector3.new(260, 10, 29) }) do tree(World.Lobby, position, 1.4) end
	for _, x in ipairs({ 201, 239 }) do
		local bench = World.part(World.Lobby, "BenchSeat", Vector3.new(9, 0.6, 3), Vector3.new(x, 11.7, -10), colors.Wood, Enum.Material.WoodPlanks)
		World.part(World.Lobby, "BenchBack", Vector3.new(9, 2.4, 0.5), Vector3.new(x, 13, -11.4), colors.Teal)
		for _, side in ipairs({ -3, 3 }) do World.part(World.Lobby, "BenchLeg", Vector3.new(0.6, 1.6, 2.8), bench.Position + Vector3.new(side, -1.1, 0), colors.DarkWood, Enum.Material.Wood) end
	end
	-- A low, safe hopping course gives the waiting lobby something to do.
	local obby = folder(World.Lobby, "LobbyHoppingCourse")
	for index = 1, 7 do
		local y = 10.5 + (index % 3) * 1.3
		local pad = World.part(obby, "Hop" .. index, Vector3.new(3.2, 0.8, 3.2), Vector3.new(245 + math.sin(index * 0.8) * 5, y, 21 - index * 4), roofs[(index - 1) % #roofs + 1])
		World.sign(pad, Enum.NormalId.Top, tostring(index), colors.Cream, 28)
	end
	local course = decorative(World.part(obby, "CourseSign", Vector3.new(11, 2, 0.3), Vector3.new(250, 14, 24), colors.Cream))
	World.sign(course, Enum.NormalId.Back, "LOBBY HOP • JUST FOR FUN", colors.Teal, 35)

	local scenery = folder(World.Root, "CloudScenery")
	for index = 1, 14 do
		local angle = math.rad(index * 26)
		local radius = index % 2 == 0 and 115 or 155
		local center = Vector3.new(math.sin(angle) * radius + 65, -2 + (index % 3) * 7, math.cos(angle) * radius)
		for _, offset in ipairs({ Vector3.new(-10, 0, 0), Vector3.new(0, 2, 0), Vector3.new(11, -1, 0) }) do
			local cloud = decorative(World.part(scenery, "Cloud", Vector3.new(27, 10, 18), center + offset, Color3.fromRGB(250, 253, 255), Enum.Material.SmoothPlastic, Enum.PartType.Ball))
			cloud.CastShadow = false
		end
	end
	for _, part in ipairs(World.Arena:GetDescendants()) do
		if part:IsA("BasePart") then
			World.Originals[part] = { Size = part.Size, CFrame = part.CFrame, Color = part.Color, Transparency = part.Transparency, CanCollide = part.CanCollide, CustomPhysicalProperties = part.CustomPhysicalProperties }
		end
	end
	lighting()
	return World
end

function World.resetArena()
	for part, original in pairs(World.Originals or {}) do
		if part.Parent then
			part.Size = original.Size
			part.CFrame = original.CFrame
			part.Color = original.Color
			part.Transparency = original.Transparency
			part.CanCollide = original.CanCollide
			part.CustomPhysicalProperties = original.CustomPhysicalProperties
		end
	end
	World.theme("Normal")
end

function World.theme(name)
	local palette = palettes[name] or palettes.Normal
	World.Floor.Color = palette[1]
	for _, part in ipairs(World.Platforms) do part.Color = palette[1] end
	for _, part in ipairs(World.Accents) do part.Color = palette[2] end
	Lighting.ClockTime = palette[3]
	Lighting.Brightness = name == "Cosmic" and 2 or 2.8
end

function World.press(color)
	World.Button.Color = color
	World.ButtonLight.Color = color
	TweenService:Create(World.Button, TweenInfo.new(0.12), { Position = World.ButtonRest - Vector3.new(0, 0.5, 0) }):Play()
	task.delay(0.14, function()
		if World.Button.Parent then TweenService:Create(World.Button, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Position = World.ButtonRest }):Play() end
	end)
end

function World.counter(state)
	local phase = state.Phase or "Lobby"
	local alive = state.AliveCount or 0
	local lobby = state.LobbyCount or 0
	World.RoundLabel.Text = string.upper(phase) .. "\n\n" .. alive .. " in the arena  •  " .. lobby .. " in the lobby\nLAST ONE STANDING WINS"
	World.Prompt.Enabled = phase == "Round" and not state.SuddenDeath and workspace:GetServerTimeNow() >= (state.ReadyAt or 0)
	World.Prompt.ActionText = "Press for chaos"
end

return World
