local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local World = {}

local colors = {
	Grass = Color3.fromRGB(75, 151, 75), Cream = Color3.fromRGB(255, 247, 223),
	Wood = Color3.fromRGB(194, 145, 91), DarkWood = Color3.fromRGB(112, 80, 55),
	Ink = Color3.fromRGB(41, 69, 87), Teal = Color3.fromRGB(43, 190, 179), Gold = Color3.fromRGB(255, 203, 81),
}
local roofs = {
	Color3.fromRGB(196, 40, 28), Color3.fromRGB(13, 105, 172), Color3.fromRGB(245, 205, 48),
	Color3.fromRGB(123, 47, 123), Color3.fromRGB(0, 143, 156), Color3.fromRGB(255, 152, 220),
}
local palettes = {
	Normal = { colors.Grass, colors.Teal, 13.8 },
	Cosmic = { Color3.fromRGB(112, 134, 218), Color3.fromRGB(196, 159, 255), 20 },
	Candy = { Color3.fromRGB(244, 182, 210), Color3.fromRGB(248, 117, 157), 14 },
	Gold = { Color3.fromRGB(225, 196, 117), colors.Gold, 16 },
	Storm = { Color3.fromRGB(106, 164, 133), Color3.fromRGB(136, 213, 255), 17.8 },
	Eruption = { Color3.fromRGB(151, 154, 99), Color3.fromRGB(255, 148, 68), 17.1 },
	Blizzard = { Color3.fromRGB(219, 241, 244), Color3.fromRGB(139, 218, 255), 12.2 },
	Alien = { Color3.fromRGB(143, 183, 175), Color3.fromRGB(179, 125, 255), 20 },
	Inferno = { Color3.fromRGB(167, 147, 84), Color3.fromRGB(255, 97, 56), 17.5 },
}
local disasterLighting = {
	Storm = { Brightness = 1.4, Ambient = Color3.fromRGB(115, 137, 156), OutdoorAmbient = Color3.fromRGB(145, 160, 174), FogColor = Color3.fromRGB(117, 144, 167), FogEnd = 620, ExposureCompensation = -0.1, ColorShift_Top = Color3.fromRGB(175, 199, 225) },
	Eruption = { Brightness = 1.8, Ambient = Color3.fromRGB(151, 122, 111), OutdoorAmbient = Color3.fromRGB(179, 142, 126), FogColor = Color3.fromRGB(187, 139, 103), FogEnd = 780, ColorShift_Top = Color3.fromRGB(255, 182, 126) },
	Blizzard = { Brightness = 2.2, Ambient = Color3.fromRGB(168, 184, 199), OutdoorAmbient = Color3.fromRGB(204, 218, 231), FogColor = Color3.fromRGB(228, 241, 248), FogEnd = 450, ColorShift_Top = Color3.fromRGB(221, 239, 255) },
	Alien = { Brightness = 1.7, Ambient = Color3.fromRGB(108, 115, 165), OutdoorAmbient = Color3.fromRGB(136, 141, 191), FogColor = Color3.fromRGB(137, 121, 198), FogEnd = 880, ColorShift_Top = Color3.fromRGB(208, 179, 255) },
	Inferno = { Brightness = 1.8, Ambient = Color3.fromRGB(156, 106, 97), OutdoorAmbient = Color3.fromRGB(192, 130, 108), FogColor = Color3.fromRGB(214, 129, 91), FogEnd = 700, ColorShift_Top = Color3.fromRGB(255, 161, 110) },
}

function World.part(parent, name, size, position, color, material, shape)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Anchored = true
	part.Color = color
	part.Material = material or Enum.Material.Plastic
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
	label.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold)
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

local function wedge(parent, name, size, frame, color, material)
	local part = Instance.new("WedgePart")
	part.Name, part.Size, part.CFrame = name, size, frame
	part.Color, part.Material = color, material or Enum.Material.Rock
	part.Anchored = true
	part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function lantern(parent, position, scale)
	local dark = Color3.fromRGB(74, 93, 99)
	World.part(parent, "LanternPost", Vector3.new(0.34, 5.6, 0.34) * scale, position + Vector3.new(0, 2.8, 0) * scale, dark, Enum.Material.Metal)
	decorative(World.part(parent, "LanternBase", Vector3.new(1.05, 0.2, 1.05) * scale, position + Vector3.new(0, 5.3, 0) * scale, dark, Enum.Material.Metal))
	local glow = decorative(World.part(parent, "LanternGlass", Vector3.new(0.75, 1.05, 0.75) * scale, position + Vector3.new(0, 5.9, 0) * scale, Color3.fromRGB(245, 205, 48), Enum.Material.Plastic))
	decorative(World.part(parent, "LanternCap", Vector3.new(1.2, 0.27, 1.2) * scale, position + Vector3.new(0, 6.5, 0) * scale, dark, Enum.Material.Metal))
	local light = Instance.new("PointLight")
	light.Color, light.Brightness, light.Range = glow.Color, 0.55, 12 * scale
	light.Shadows = false
	light.Parent = glow
end

local function planter(parent, position, width, depth, tint)
	World.part(parent, "GardenPlanter", Vector3.new(width, 1, depth), position + Vector3.new(0, 0.5, 0), colors.Wood, Enum.Material.WoodPlanks)
	decorative(World.part(parent, "PlanterSoil", Vector3.new(width - 0.3, 0.12, depth - 0.3), position + Vector3.new(0, 1.04, 0), colors.DarkWood, Enum.Material.Ground))
	for index = 1, 5 do
		local x = position.X - width / 2 + 0.6 + (index - 1) * (width - 1.2) / 4
		local stem = decorative(World.part(parent, "FlowerStem", Vector3.new(0.13, 0.85, 0.13), Vector3.new(x, position.Y + 1.5, position.Z), Color3.fromRGB(66, 144, 95)))
		decorative(World.part(parent, "Flower", Vector3.new(0.65, 0.35, 0.65), stem.Position + Vector3.new(0, 0.5, 0), tint, Enum.Material.SmoothPlastic, Enum.PartType.Ball))
	end
end

local function tree(parent, position, scale)
	local trunk = World.part(parent, "TreeTrunk", Vector3.new(1.4, 6, 1.4) * scale, position + Vector3.new(0, 3, 0) * scale, colors.DarkWood, Enum.Material.Wood)
	trunk.CanCollide = false
	for index, offset in ipairs({ Vector3.new(0, 7.8, 0), Vector3.new(-1.6, 6.6, 0.4), Vector3.new(1.5, 6.7, -0.4) }) do
		decorative(World.part(parent, "TreeCrown", Vector3.new(6.2, 5.6, 6.2) * scale, position + offset * scale,
			index == 1 and Color3.fromRGB(75, 151, 75) or Color3.fromRGB(91, 154, 76), Enum.Material.Plastic, Enum.PartType.Ball))
	end
end

local function floatingBase(parent, position, width, depth)
	local cliff = folder(parent, "FloatingCliff")
	local height = math.min(24, width * 0.65)
	decorative(World.part(cliff, "EarthLayer", Vector3.new(width * 0.98, 2.7, depth * 0.98), position - Vector3.new(0, 2.5, 0), Color3.fromRGB(152, 118, 81), Enum.Material.Ground))
	decorative(World.part(cliff, "CliffCore", Vector3.new(width * 0.79, height * 0.6, depth * 0.79), position - Vector3.new(0, height * 0.46 + 2.5, 0), Color3.fromRGB(130, 145, 147), Enum.Material.Slate))
	for index = 1, 8 do
		local angle = index * math.pi / 4
		local offset = Vector3.new(math.cos(angle) * width * 0.35, -height * 0.42 - 2.6, math.sin(angle) * depth * 0.35)
		local stone = decorative(wedge(cliff, "CliffFacet", Vector3.new(width * 0.32, height * 0.87, depth * 0.31), CFrame.new(position + offset) * CFrame.Angles(math.pi, angle, 0),
			index % 2 == 0 and Color3.fromRGB(151, 165, 163) or Color3.fromRGB(117, 134, 138)))
		stone.CastShadow = true
		if index % 2 == 0 then
			local ledge = decorative(World.part(cliff, "GrassLip", Vector3.new(width * 0.3, 0.55, depth * 0.12), position + Vector3.new(math.cos(angle) * width * 0.43, -0.9, math.sin(angle) * depth * 0.43), Color3.fromRGB(84, 165, 99), Enum.Material.Grass))
			ledge.CFrame = CFrame.new(ledge.Position) * CFrame.Angles(0, -angle, 0)
		end
	end
	for index = 1, 3 do
		local angle = index * math.pi * 2 / 3
		decorative(wedge(cliff, "HangingRockSpire", Vector3.new(width * 0.28, height * 0.88, depth * 0.27), CFrame.new(position + Vector3.new(math.cos(angle) * width * 0.12, -height * 0.92 - 2, math.sin(angle) * depth * 0.13)) * CFrame.Angles(math.pi, angle + 0.6, 0), Color3.fromRGB(104, 123, 132), Enum.Material.Slate))
	end
	for index = 1, 4 do
		local angle = index * math.pi / 2
		local vine = decorative(World.part(cliff, "CliffVine", Vector3.new(0.35, 3 + index, 0.4), position + Vector3.new(math.cos(angle) * width * 0.47, -3.5 - index / 2, math.sin(angle) * depth * 0.47), Color3.fromRGB(67, 135, 98), Enum.Material.Grass))
		vine.Orientation = Vector3.new(0, angle * 180 / math.pi, index % 2 == 0 and 12 or -12)
	end
end

local function cottage(parent, frame, tint, number)
	local home = folder(parent, "Cottage" .. number)
	local wall = Color3.fromRGB(242, 243, 243)
	local floor = localPart(home, frame, "HouseFloor", Vector3.new(14, 0.4, 14), Vector3.new(0, 0.2, 3.5), Color3.fromRGB(163, 162, 165), Enum.Material.Plastic)
	floor.TopSurface = Enum.SurfaceType.Studs
	-- A normal avatar can walk through a 5.6-wide, 8-high doorway.
	-- The interior is 13.4 by 13.4 with 9.8 studs of headroom.
	for _, x in ipairs({ -7, 7 }) do
		localPart(home, frame, "SideWall", Vector3.new(0.6, 9.8, 14), Vector3.new(x, 5.3, 3.5), wall, Enum.Material.Plastic)
	end
	localPart(home, frame, "BackWall", Vector3.new(14.6, 9.8, 0.6), Vector3.new(0, 5.3, 10.5), wall, Enum.Material.Plastic)
	for _, x in ipairs({ -5.05, 5.05 }) do
		localPart(home, frame, "FrontWall", Vector3.new(4.5, 9.8, 0.6), Vector3.new(x, 5.3, -3.5), wall, Enum.Material.Plastic)
	end
	localPart(home, frame, "DoorLintel", Vector3.new(5.6, 1.8, 0.6), Vector3.new(0, 9.3, -3.5), wall, Enum.Material.Plastic)
	for _, x in ipairs({ -3, 3 }) do
		decorative(localPart(home, frame, "DoorFrame", Vector3.new(0.28, 8, 0.28), Vector3.new(x, 4.5, -3.86), tint, Enum.Material.Plastic))
	end
	decorative(localPart(home, frame, "DoorFrameTop", Vector3.new(6.4, 0.28, 0.28), Vector3.new(0, 8.55, -3.86), tint, Enum.Material.Plastic))
	for _, x in ipairs({ -7.35, 7.35 }) do
		decorative(localPart(home, frame, "WindowGlass", Vector3.new(0.12, 3.5, 4.4), Vector3.new(x, 5.5, 3.2), Color3.fromRGB(117, 183, 229), Enum.Material.Plastic))
		for _, z in ipairs({ 0.9, 5.5 }) do decorative(localPart(home, frame, "WindowFrame", Vector3.new(0.22, 3.9, 0.22), Vector3.new(x, 5.5, z), tint, Enum.Material.Plastic)) end
		for _, y in ipairs({ 3.65, 7.35 }) do decorative(localPart(home, frame, "WindowFrame", Vector3.new(0.22, 0.22, 4.8), Vector3.new(x, y, 3.2), tint, Enum.Material.Plastic)) end
		decorative(localPart(home, frame, "WindowCrossbar", Vector3.new(0.24, 3.7, 0.18), Vector3.new(x, 5.5, 3.2), wall, Enum.Material.Plastic))
		decorative(localPart(home, frame, "WindowCrossbar", Vector3.new(0.24, 0.18, 4.6), Vector3.new(x, 5.5, 3.2), wall, Enum.Material.Plastic))
	end
	-- The clear doorway and empty middle leave room for chases and weapons.
	localPart(home, frame, "InteriorTable", Vector3.new(3, 2, 2.4), Vector3.new(-4.6, 1.4, 8), colors.Wood, Enum.Material.Wood)
	local chair = localPart(home, frame, "InteriorBench", Vector3.new(3, 1.4, 1.3), Vector3.new(4.6, 1.1, 8), tint, Enum.Material.Plastic)
	chair.TopSurface = Enum.SurfaceType.Studs
	localPart(home, frame, "InteriorBenchBack", Vector3.new(3, 2.5, 0.3), Vector3.new(4.6, 2.3, 8.6), tint, Enum.Material.Plastic)
	for _, direction in ipairs({ -1, 1 }) do
		local roof = localPart(home, frame, "Roof", Vector3.new(8.5, 0.8, 16), Vector3.new(direction * 3.65, 11.9, 3.5), tint, Enum.Material.Plastic)
		roof.CFrame = roof.CFrame * CFrame.Angles(0, 0, math.rad(-direction * 28))
	end
	localPart(home, frame, "RoofRidge", Vector3.new(0.65, 0.65, 16.2), Vector3.new(0, 13.7, 3.5), tint, Enum.Material.Plastic)
	decorative(localPart(home, frame, "FrontRoofTrim", Vector3.new(14.8, 0.4, 0.5), Vector3.new(0, 10.05, -3.8), colors.DarkWood, Enum.Material.Wood))
	localPart(home, frame, "Chimney", Vector3.new(1.5, 3, 1.5), Vector3.new(-4, 13.2, 7), Color3.fromRGB(170, 85, 0), Enum.Material.Brick)
	local plaque = decorative(localPart(home, frame, "HouseNumber", Vector3.new(2.5, 1.1, 0.15), Vector3.new(0, 9.1, -3.88), wall, Enum.Material.Plastic))
	World.sign(plaque, Enum.NormalId.Front, string.format("%02d", number), tint, 35)
	home:SetAttribute("DoorWidth", 5.6)
	home:SetAttribute("DoorHeight", 8)
	home:SetAttribute("InteriorWidth", 13.4)
	home:SetAttribute("InteriorHeight", 9.8)
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
	Lighting.Brightness = 2
	Lighting.ClockTime = 13.8
	Lighting.Ambient = Color3.fromRGB(128, 128, 128)
	Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
	Lighting.ColorShift_Top = Color3.new(0, 0, 0)
	Lighting.ColorShift_Bottom = Color3.new(0, 0, 0)
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 0
	Lighting.EnvironmentSpecularScale = 0
	Lighting.ExposureCompensation = 0
	Lighting.FogColor = Color3.fromRGB(194, 226, 247)
	Lighting.FogStart = 1000
	Lighting.FogEnd = 10000
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
	atmosphere.Density = 0.03
	atmosphere.Offset = 0.25
	atmosphere.Color = Color3.fromRGB(213, 233, 250)
	atmosphere.Decay = Color3.fromRGB(238, 217, 175)
	atmosphere.Glare = 0
	atmosphere.Haze = 0
	atmosphere.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "ButtonBloom"
	bloom.Intensity = 0
	bloom.Enabled = false
	bloom.Size = 20
	bloom.Threshold = 1.8
	bloom.Parent = Lighting
	local correction = Instance.new("ColorCorrectionEffect")
	correction.Name = "ButtonColor"
	correction.Saturation = 0
	correction.Contrast = 0
	correction.TintColor = Color3.new(1, 1, 1)
	correction.Enabled = false
	correction.Parent = Lighting
	local sun = Instance.new("SunRaysEffect")
	sun.Name = "ButtonSun"
	sun.Intensity = 0
	sun.Enabled = false
	sun.Spread = 0.6
	sun.Parent = Lighting
	World.Atmosphere, World.ColorCorrection, World.SunRays = atmosphere, correction, sun
	World.NormalLighting = {}
	for _, property in ipairs({ "Brightness", "ClockTime", "Ambient", "OutdoorAmbient", "ColorShift_Top", "ColorShift_Bottom", "ExposureCompensation", "FogColor", "FogStart", "FogEnd" }) do World.NormalLighting[property] = Lighting[property] end
	World.NormalAtmosphere = {}
	for _, property in ipairs({ "Density", "Offset", "Color", "Decay", "Glare", "Haze" }) do World.NormalAtmosphere[property] = atmosphere[property] end
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
	World.Floor = World.part(World.Arena, "CentralHub", Vector3.new(2, 28, 28), Vector3.new(0, 29, 0), colors.Grass, Enum.Material.Plastic, Enum.PartType.Cylinder)
	World.Floor.Orientation = Vector3.new(0, 0, 90)
	floatingBase(World.Arena, Vector3.new(0, 29, 0), 25, 25)
	local hubTrim = decorative(World.part(World.Arena, "HubTrim", Vector3.new(0.5, 29, 29), Vector3.new(0, 28.3, 0), colors.Wood, Enum.Material.Wood, Enum.PartType.Cylinder))
	hubTrim.Orientation = Vector3.new(0, 0, 90)
	for index = 1, 12 do
		local angle = math.rad((index - 1) * 30)
		local direction = Vector3.new(math.sin(angle), 0, math.cos(angle))
		local center = direction * 62 + Vector3.new(0, 29, 0)
		local island = folder(World.Arena, "Island" .. index)
		local ground = World.part(island, "HomePlatform", Vector3.new(26, 2, 26), center, colors.Grass, Enum.Material.Plastic)
		local frame = CFrame.lookAt(center + Vector3.new(0, 1, 0), Vector3.new(0, 30, 0))
		ground.CFrame = frame * CFrame.new(0, -1, 0)
		ground.TopSurface = Enum.SurfaceType.Studs
		ground:SetAttribute("IslandIndex", index)
		table.insert(World.Platforms, ground)
		table.insert(World.ArenaSpawns, frame:PointToWorldSpace(Vector3.new(0, 4, -8)))
		floatingBase(island, center, 26, 26)
		cottage(island, frame, roofs[(index - 1) % #roofs + 1], index)
		tree(island, frame:PointToWorldSpace(Vector3.new(-10.5, 0, 8.7)), 0.65)
		local bridge = World.part(World.Arena, "Bridge" .. index, Vector3.new(6, 1, 41), direction * 31.5 + Vector3.new(0, 29.5, 0), colors.Wood, Enum.Material.WoodPlanks)
		bridge.CFrame = CFrame.lookAt(bridge.Position, Vector3.new(0, 29.5, 0))
		table.insert(World.Bridges, bridge)
		for plank = 1, 10 do
			decorative(localPart(bridge, bridge.CFrame, "BridgePlank", Vector3.new(6.05, 0.09, 3.65), Vector3.new(0, 0.55, -18.2 + (plank - 1) * 4),
				plank % 2 == 0 and colors.Wood or Color3.fromRGB(180, 130, 83), Enum.Material.WoodPlanks))
		end
		for _, x in ipairs({ -2.1, 2.1 }) do decorative(localPart(bridge, bridge.CFrame, "BridgeUnderbeam", Vector3.new(0.35, 1.1, 41), Vector3.new(x, -0.9, 0), colors.DarkWood, Enum.Material.Wood)) end
		for _, distance in ipairs({ 15, 49 }) do
			local stripe = decorative(World.part(bridge, "BridgeMarker", Vector3.new(6.02, 0.05, 1.4), direction * distance + Vector3.new(0, 30.09, 0), roofs[(index - 1) % #roofs + 1]))
			stripe.CFrame = CFrame.lookAt(stripe.Position, Vector3.new(0, stripe.Position.Y, 0))
		end
	end

	local base = World.part(World.Arena, "ButtonPedestal", Vector3.new(1.5, 11, 11), Vector3.new(0, 30.75, 0), colors.Cream, nil, Enum.PartType.Cylinder)
	base.Orientation = Vector3.new(0, 0, 90)
	for index = 1, 12 do
		local angle = index * math.pi / 6
		local tile = decorative(World.part(World.Arena, "HubCompassTile", Vector3.new(2.4, 0.1, 1.5), Vector3.new(math.cos(angle) * 10, 30.06, math.sin(angle) * 10), colors.Cream, Enum.Material.Sandstone))
		tile.CFrame = CFrame.new(tile.Position) * CFrame.Angles(0, -angle, 0)
	end
	local ring = World.part(World.Arena, "ButtonRing", Vector3.new(0.45, 9, 9), Vector3.new(0, 31.65, 0), colors.Gold, Enum.Material.Plastic, Enum.PartType.Cylinder)
	ring.Orientation = base.Orientation
	table.insert(World.Accents, ring)
	World.Button = World.part(World.Arena, "Button", Vector3.new(1.65, 7.9, 7.9), Vector3.new(0, 32.65, 0), Color3.fromRGB(196, 40, 28), Enum.Material.Plastic, Enum.PartType.Cylinder)
	World.Button.Orientation = base.Orientation
	World.ButtonRest = World.Button.Position
	for index = 1, 4 do
		World.part(World.Arena, "ButtonStep", Vector3.new(4.8, 0.3 * index, 1.2), Vector3.new(0, 30 + 0.15 * index, 7.2 - index * 0.75), colors.Cream)
	end
	World.ButtonLight = Instance.new("PointLight")
	World.ButtonLight.Color = World.Button.Color
	World.ButtonLight.Brightness = 0
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
	local lobbyGround = World.part(World.Lobby, "LobbyGround", Vector3.new(100, 4, 80), Vector3.new(220, 8, 0), colors.Grass, Enum.Material.Plastic)
	lobbyGround.TopSurface = Enum.SurfaceType.Studs
	floatingBase(World.Lobby, Vector3.new(220, 9, 0), 100, 80)
	World.part(World.Lobby, "Plaza", Vector3.new(67, 0.16, 52), Vector3.new(220, 10.08, 0), Color3.fromRGB(199, 193, 183), Enum.Material.Concrete)
	World.part(World.Lobby, "WelcomePath", Vector3.new(14, 0.18, 74), Vector3.new(220, 10.1, 0), Color3.fromRGB(242, 243, 243), Enum.Material.Concrete)
	for _, x in ipairs({ 212.8, 227.2 }) do decorative(World.part(World.Lobby, "PathBorder", Vector3.new(0.45, 0.2, 74), Vector3.new(x, 10.12, 0), Color3.fromRGB(215, 198, 163), Enum.Material.Sandstone)) end
	for z = -32, 32, 8 do decorative(World.part(World.Lobby, "PathJoin", Vector3.new(13.7, 0.025, 0.12), Vector3.new(220, 10.204, z), Color3.fromRGB(224, 210, 181), Enum.Material.Sandstone)) end
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
		spawn.Position = Vector3.new(220, 9.8, 0) + offset
		spawn.Color = colors.Teal
		spawn.Material = Enum.Material.SmoothPlastic
		spawn.Transparency = 1
		spawn.CanCollide = false
		spawn.CanTouch = false
		spawn.CanQuery = false
		spawn.Parent = World.Lobby
		for _, child in ipairs(spawn:GetChildren()) do if child:IsA("Decal") or child:IsA("Texture") then child:Destroy() end end
	end
	local welcome = World.part(World.Lobby, "WelcomeArch", Vector3.new(44, 5, 1.1), Vector3.new(220, 24, 34), colors.Cream)
	World.sign(welcome, Enum.NormalId.Front, "DON'T PRESS THE BUTTON", Color3.fromRGB(237, 103, 95), 30)
	for _, x in ipairs({ 199, 241 }) do World.part(World.Lobby, "WelcomePillar", Vector3.new(1.4, 14, 1.4), Vector3.new(x, 17, 34), colors.Teal) end
	decorative(World.part(World.Lobby, "BuntingCord", Vector3.new(40, 0.12, 0.12), Vector3.new(220, 20.1, 33.4), colors.DarkWood))
	for index = 1, 12 do
		local flag = decorative(wedge(World.Lobby, "WelcomeBunting", Vector3.new(2.2, 1.6, 0.12), CFrame.new(200 + index * 3, 19.3, 33.4) * CFrame.Angles(0, math.pi / 2, math.pi), roofs[(index - 1) % #roofs + 1], Enum.Material.Fabric))
		flag.CastShadow = false
	end
	World.LeaderboardLabel = board(World.Lobby, "LeaderboardBoard", Vector3.new(220, 18, -30), 24, 13, "HALL OF SURVIVORS\n\nLoading leaderboard...", colors.Ink)
	World.RoundLabel = board(World.Lobby, "RoundBoard", Vector3.new(192, 17, -30), 22, 11, "NEXT ROUND\n\nWaiting for players", colors.Teal)
	World.CounterLabel = World.RoundLabel
	board(World.Lobby, "HowToPlay", Vector3.new(248, 17, -30), 22, 11, "LAST ONE STANDING\n\nPress the button for disasters or PvP.\nUse houses for cover. Outlast everyone.\nWin tokens. Buy supplies. Try the obby!", colors.Ink)
	local portalCenter = Vector3.new(189, 10, 5)
	for _, x in ipairs({ -5.7, 5.7 }) do World.part(World.Lobby, "PortalPost", Vector3.new(1.2, 11, 1.4), portalCenter + Vector3.new(x, 5.5, 0), colors.Teal) end
	World.part(World.Lobby, "PortalTop", Vector3.new(12.8, 1.2, 1.4), portalCenter + Vector3.new(0, 11, 0), colors.Teal)
	local portal = decorative(World.part(World.Lobby, "RoundPortal", Vector3.new(10, 9.6, 0.15), portalCenter + Vector3.new(0, 5.2, 0), Color3.fromRGB(242, 243, 243), Enum.Material.Plastic))
	portal.Transparency = 0
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
	for _, position in ipairs({ Vector3.new(206, 10, 29), Vector3.new(234, 10, 29), Vector3.new(205, 10, -20), Vector3.new(235, 10, -20) }) do lantern(World.Lobby, position, 1.2) end
	for _, spec in ipairs({ { Vector3.new(206, 10, 21), roofs[1] }, { Vector3.new(234, 10, 21), roofs[4] }, { Vector3.new(204, 10, -24), roofs[3] }, { Vector3.new(236, 10, -24), roofs[5] } }) do planter(World.Lobby, spec[1], 6.5, 2.2, spec[2]) end
	for _, x in ipairs({ 201, 239 }) do
		local bench = World.part(World.Lobby, "BenchSeat", Vector3.new(9, 0.6, 3), Vector3.new(x, 11.7, -10), colors.Wood, Enum.Material.WoodPlanks)
		World.part(World.Lobby, "BenchBack", Vector3.new(9, 2.4, 0.5), Vector3.new(x, 13, -11.4), colors.Teal)
		for _, side in ipairs({ -3, 3 }) do World.part(World.Lobby, "BenchLeg", Vector3.new(0.6, 1.6, 2.8), bench.Position + Vector3.new(side, -1.1, 0), colors.DarkWood, Enum.Material.Wood) end
	end
	-- An ordered classic obby offers progress and a real finish in the safe lobby.
	local obby = folder(World.Lobby, "LobbyObby")
	World.ObbyCheckpoints = {}
	local courseSpecs = {
		{ Vector3.new(243, 10.7, 25), Vector3.new(6, 1.2, 6), "START" },
		{ Vector3.new(252, 12, 24), Vector3.new(4, 1, 4), "JUMP" },
		{ Vector3.new(262, 13.3, 20), Vector3.new(5, 1, 5), "TURN" },
		{ Vector3.new(262, 14.2, 10), Vector3.new(3.2, 1, 10), "BALANCE" },
		{ Vector3.new(253, 15.4, 4), Vector3.new(4, 1, 4), "JUMP" },
		{ Vector3.new(243, 16.5, -2), Vector3.new(4, 1, 4), "KEEP GOING" },
		{ Vector3.new(248, 17.7, -12), Vector3.new(4, 1, 4), "JUMP" },
		{ Vector3.new(259, 18.5, -15), Vector3.new(7, 1, 5), "HALFWAY? ALMOST!" },
		{ Vector3.new(263, 19.6, -5), Vector3.new(4, 1, 4), "ONE MORE" },
		{ Vector3.new(256, 20.7, 3), Vector3.new(4, 1, 4), "FINISH NEXT" },
	}
	for index, spec in ipairs(courseSpecs) do
		local checkpoint = World.part(obby, "ObbyCheckpoint" .. index, spec[2], spec[1], index == 1 and Color3.fromRGB(0, 143, 156) or roofs[(index - 1) % #roofs + 1], Enum.Material.Plastic)
		checkpoint.TopSurface = Enum.SurfaceType.Studs
		checkpoint:SetAttribute("ObbyOrder", index)
		checkpoint:SetAttribute("Order", index)
		World.sign(checkpoint, Enum.NormalId.Top, tostring(index), colors.Cream, 25)
		table.insert(World.ObbyCheckpoints, checkpoint)
		if index % 2 == 0 then
			decorative(World.part(obby, "ObbySupport", Vector3.new(1, math.max(1, spec[1].Y - 10.5), 1), Vector3.new(spec[1].X, (spec[1].Y + 10.5) / 2, spec[1].Z), Color3.fromRGB(163, 162, 165), Enum.Material.Brick))
		end
	end
	World.ObbyStart = courseSpecs[1][1] + Vector3.new(0, 4, 0)
	World.ObbyFinish = World.part(obby, "ObbyFinish", Vector3.new(7, 1, 7), Vector3.new(246, 21.5, 10), Color3.fromRGB(0, 143, 156), Enum.Material.Plastic)
	World.ObbyFinish.TopSurface = Enum.SurfaceType.Studs
	World.ObbyFinish:SetAttribute("ObbyOrder", #courseSpecs + 1)
	World.ObbyFinish:SetAttribute("Order", #courseSpecs + 1)
	World.sign(World.ObbyFinish, Enum.NormalId.Top, "FINISH", colors.Cream, 35)
	local courseSign = decorative(World.part(obby, "ObbyRules", Vector3.new(12, 3.5, 0.3), Vector3.new(247, 15, 30), colors.Cream))
	World.sign(courseSign, Enum.NormalId.Front, "LOBBY OBBY\nSTART AT 1 → REACH THE FINISH", colors.Ink, 30)
	for _, x in ipairs({ 242.8, 249.2 }) do World.part(obby, "FinishFlagPole", Vector3.new(0.3, 4, 0.3), Vector3.new(x, 24, 10), Color3.fromRGB(163, 162, 165), Enum.Material.Metal) end
	decorative(World.part(obby, "FinishFlag", Vector3.new(6, 1.2, 0.2), Vector3.new(246, 25.2, 10), colors.Gold, Enum.Material.Plastic))

	local scenery = folder(World.Root, "CloudScenery")
	World.Clouds, World.CloudColors = {}, {}
	for index = 1, 6 do
		local angle = math.rad(index * 26)
		local radius = 240
		local center = Vector3.new(math.sin(angle) * radius + 65, -32, math.cos(angle) * radius)
		for _, offset in ipairs({ Vector3.new(-10, 0, 0), Vector3.new(0, 2, 0), Vector3.new(11, -1, 0) }) do
			local cloud = decorative(World.part(scenery, "Cloud", Vector3.new(29, 8, 19), center + offset, Color3.fromRGB(250, 253, 255), Enum.Material.Plastic, Enum.PartType.Ball))
			cloud.CastShadow = false
			table.insert(World.Clouds, cloud)
			World.CloudColors[cloud] = cloud.Color
		end
	end
	for index = 1, 4 do
		local angle = index * math.pi / 4
		local cloud = decorative(World.part(scenery, "HorizonCloud", Vector3.new(52, 8, 25), Vector3.new(math.cos(angle) * 360 + 80, 38 + (index % 3) * 10, math.sin(angle) * 360), Color3.fromRGB(242, 249, 255), Enum.Material.Plastic, Enum.PartType.Ball))
		cloud.CastShadow = false
		table.insert(World.Clouds, cloud)
		World.CloudColors[cloud] = cloud.Color
	end
	local background = folder(World.Root, "DistantSkyIslands")
	for index = 1, 6 do
		local angle = index * math.pi / 3 + 0.3
		local position = Vector3.new(math.cos(angle) * 290 + 90, 2 + (index % 3) * 14, math.sin(angle) * 300)
		decorative(World.part(background, "DistantMeadow", Vector3.new(31, 2, 23), position, Color3.fromRGB(131, 187, 151), Enum.Material.Grass))
		for facet = 1, 3 do
			decorative(wedge(background, "DistantCliff", Vector3.new(24, 30, 22), CFrame.new(position - Vector3.new(facet * 3 - 6, 17, facet * 2 - 4)) * CFrame.Angles(math.pi, facet * 1.8, 0), Color3.fromRGB(136, 166, 177), Enum.Material.Slate))
		end
		tree(background, position + Vector3.new(-7, 1, 3), 1.1)
	end
	for _, part in ipairs(World.Arena:GetDescendants()) do
		if part:IsA("BasePart") then
			World.Originals[part] = { Size = part.Size, CFrame = part.CFrame, Color = part.Color, Material = part.Material, Transparency = part.Transparency, CanCollide = part.CanCollide, CustomPhysicalProperties = part.CustomPhysicalProperties }
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
			part.Material = original.Material
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
	for _, part in ipairs(World.Accents) do part.Color = (name == "Normal" or not palettes[name]) and World.Originals[part].Color or palette[2] end
	for property, value in pairs(World.NormalLighting or {}) do Lighting[property] = value end
	for property, value in pairs(World.NormalAtmosphere or {}) do World.Atmosphere[property] = value end
	Lighting.ClockTime = palette[3]
	local disaster = disasterLighting[name]
	if disaster then
		for property, value in pairs(disaster) do Lighting[property] = value end
		World.Atmosphere.Color = disaster.FogColor
		World.Atmosphere.Decay = disaster.ColorShift_Top
		World.Atmosphere.Density = name == "Blizzard" and 0.36 or 0.3
		World.Atmosphere.Haze = name == "Blizzard" and 2.3 or 1.8
		World.Atmosphere.Glare = name == "Storm" and 0 or 0.06
	elseif name == "Cosmic" then Lighting.Brightness = 2 end
	World.ColorCorrection.TintColor = Color3.new(1, 1, 1)
	World.ColorCorrection.Saturation = 0
	World.SunRays.Intensity = 0
	for _, cloud in ipairs(World.Clouds or {}) do cloud.Color = disaster and disaster.FogColor:Lerp(Color3.new(1, 1, 1), 0.24) or World.CloudColors[cloud] end
	World.Theme = name or "Normal"
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
