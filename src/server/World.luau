local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local World = {}

local colors = {
	Grass = Color3.fromRGB(110, 204, 149), Cream = Color3.fromRGB(255, 250, 234),
	Wood = Color3.fromRGB(223, 173, 126), DarkWood = Color3.fromRGB(114, 101, 128),
	Ink = Color3.fromRGB(51, 66, 93), Teal = Color3.fromRGB(66, 196, 193), Gold = Color3.fromRGB(255, 210, 99),
}
local roofs = {
	Color3.fromRGB(255, 126, 123), Color3.fromRGB(113, 177, 244), Color3.fromRGB(255, 215, 118),
	Color3.fromRGB(177, 145, 236), Color3.fromRGB(81, 205, 188), Color3.fromRGB(244, 151, 202),
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
	label.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
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
	part.Color, part.Material = color, material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function lantern(parent, position, scale)
	local dark = Color3.fromRGB(74, 93, 99)
	World.part(parent, "LanternPost", Vector3.new(0.34, 5.6, 0.34) * scale, position + Vector3.new(0, 2.8, 0) * scale, dark, Enum.Material.SmoothPlastic)
	decorative(World.part(parent, "LanternBase", Vector3.new(1.05, 0.2, 1.05) * scale, position + Vector3.new(0, 5.3, 0) * scale, dark, Enum.Material.SmoothPlastic))
	local glow = decorative(World.part(parent, "LanternGlass", Vector3.new(0.75, 1.05, 0.75) * scale, position + Vector3.new(0, 5.9, 0) * scale, Color3.fromRGB(245, 205, 48), Enum.Material.SmoothPlastic))
	decorative(World.part(parent, "LanternCap", Vector3.new(1.2, 0.27, 1.2) * scale, position + Vector3.new(0, 6.5, 0) * scale, dark, Enum.Material.SmoothPlastic))
	local light = Instance.new("PointLight")
	light.Color, light.Brightness, light.Range = glow.Color, 0.55, 12 * scale
	light.Shadows = false
	light.Parent = glow
end

local function planter(parent, position, width, depth, tint)
	World.part(parent, "GardenPlanter", Vector3.new(width, 1, depth), position + Vector3.new(0, 0.5, 0), colors.Wood, Enum.Material.SmoothPlastic)
	decorative(World.part(parent, "PlanterSoil", Vector3.new(width - 0.3, 0.12, depth - 0.3), position + Vector3.new(0, 1.04, 0), colors.DarkWood, Enum.Material.SmoothPlastic))
	for index = 1, 5 do
		local x = position.X - width / 2 + 0.6 + (index - 1) * (width - 1.2) / 4
		local stem = decorative(World.part(parent, "FlowerStem", Vector3.new(0.13, 0.85, 0.13), Vector3.new(x, position.Y + 1.5, position.Z), Color3.fromRGB(66, 144, 95)))
		decorative(World.part(parent, "Flower", Vector3.new(0.65, 0.35, 0.65), stem.Position + Vector3.new(0, 0.5, 0), tint, Enum.Material.SmoothPlastic, Enum.PartType.Ball))
	end
end

local function tree(parent, position, scale)
	decorative(World.part(parent, "TreeTrunk", Vector3.new(1.1, 5.4, 1.1) * scale, position + Vector3.new(0, 2.7, 0) * scale, colors.DarkWood))
	for level = 1, 2 do
		local width, height = (level == 1 and 6.2 or 4.7) * scale, 4.5 * scale
		local y = (level == 1 and 6.2 or 8.7) * scale
		for direction = 0, 3 do
			local angle = direction * math.pi / 2
			local offset = Vector3.new(math.sin(angle) * width / 4, y, math.cos(angle) * width / 4)
			decorative(wedge(parent, "TreeCanopyFacet", Vector3.new(width, height, width / 2), CFrame.new(position + offset) * CFrame.Angles(0, angle + math.pi, 0),
				direction % 2 == 0 and Color3.fromRGB(90, 184, 149) or Color3.fromRGB(118, 205, 160)))
		end
	end
end

local function floatingBase(parent, position, width, depth)
	local cliff = folder(parent, "FloatingCliff")
	local height = math.min(24, width * 0.65)
	decorative(World.part(cliff, "EarthLayer", Vector3.new(width * 0.98, 2.7, depth * 0.98), position - Vector3.new(0, 2.5, 0), Color3.fromRGB(152, 118, 81), Enum.Material.SmoothPlastic))
	decorative(World.part(cliff, "CliffCore", Vector3.new(width * 0.79, height * 0.6, depth * 0.79), position - Vector3.new(0, height * 0.46 + 2.5, 0), Color3.fromRGB(130, 145, 147), Enum.Material.SmoothPlastic))
	for index = 1, 8 do
		local angle = index * math.pi / 4
		local offset = Vector3.new(math.cos(angle) * width * 0.35, -height * 0.42 - 2.6, math.sin(angle) * depth * 0.35)
		local stone = decorative(wedge(cliff, "CliffFacet", Vector3.new(width * 0.32, height * 0.87, depth * 0.31), CFrame.new(position + offset) * CFrame.Angles(math.pi, angle, 0),
			index % 2 == 0 and Color3.fromRGB(151, 165, 163) or Color3.fromRGB(117, 134, 138)))
		stone.CastShadow = true
		if index % 2 == 0 then
			local ledge = decorative(World.part(cliff, "GrassLip", Vector3.new(width * 0.3, 0.55, depth * 0.12), position + Vector3.new(math.cos(angle) * width * 0.43, -0.9, math.sin(angle) * depth * 0.43), Color3.fromRGB(84, 165, 99), Enum.Material.SmoothPlastic))
			ledge.CFrame = CFrame.new(ledge.Position) * CFrame.Angles(0, -angle, 0)
		end
	end
	for index = 1, 3 do
		local angle = index * math.pi * 2 / 3
		decorative(wedge(cliff, "HangingRockSpire", Vector3.new(width * 0.28, height * 0.88, depth * 0.27), CFrame.new(position + Vector3.new(math.cos(angle) * width * 0.12, -height * 0.92 - 2, math.sin(angle) * depth * 0.13)) * CFrame.Angles(math.pi, angle + 0.6, 0), Color3.fromRGB(104, 123, 132), Enum.Material.SmoothPlastic))
	end
	for index = 1, 4 do
		local angle = index * math.pi / 2
		local vine = decorative(World.part(cliff, "CliffVine", Vector3.new(0.35, 3 + index, 0.4), position + Vector3.new(math.cos(angle) * width * 0.47, -3.5 - index / 2, math.sin(angle) * depth * 0.47), Color3.fromRGB(67, 135, 98), Enum.Material.SmoothPlastic))
		vine.Orientation = Vector3.new(0, angle * 180 / math.pi, index % 2 == 0 and 12 or -12)
	end
end

local function cottage(parent, frame, tint, number)
	local home = Instance.new("Model")
	home.Name, home.Parent = "Cottage" .. number, parent
	local wall = colors.Cream
	local floor = localPart(home, frame, "HouseFloor", Vector3.new(14, 0.4, 14), Vector3.new(0, 0.2, 3.5), Color3.fromRGB(163, 162, 165), Enum.Material.SmoothPlastic)
	home.PrimaryPart = floor
	-- A normal avatar can walk through a 5.6-wide, 8-high doorway.
	-- The interior is 13.4 by 13.4 with 9.8 studs of headroom.
	for _, x in ipairs({ -7, 7 }) do
		localPart(home, frame, "SideWall", Vector3.new(0.6, 9.8, 14), Vector3.new(x, 5.3, 3.5), wall, Enum.Material.SmoothPlastic)
	end
	localPart(home, frame, "BackWall", Vector3.new(14.6, 9.8, 0.6), Vector3.new(0, 5.3, 10.5), wall, Enum.Material.SmoothPlastic)
	for _, x in ipairs({ -5.05, 5.05 }) do
		localPart(home, frame, "FrontWall", Vector3.new(4.5, 9.8, 0.6), Vector3.new(x, 5.3, -3.5), wall, Enum.Material.SmoothPlastic)
	end
	localPart(home, frame, "DoorLintel", Vector3.new(5.6, 1.8, 0.6), Vector3.new(0, 9.3, -3.5), wall, Enum.Material.SmoothPlastic)
	for _, x in ipairs({ -3, 3 }) do
		decorative(localPart(home, frame, "DoorFrame", Vector3.new(0.28, 8, 0.28), Vector3.new(x, 4.5, -3.86), tint, Enum.Material.SmoothPlastic))
	end
	decorative(localPart(home, frame, "DoorFrameTop", Vector3.new(6.4, 0.28, 0.28), Vector3.new(0, 8.55, -3.86), tint, Enum.Material.SmoothPlastic))
	for _, x in ipairs({ -7.35, 7.35 }) do
		decorative(localPart(home, frame, "WindowGlass", Vector3.new(0.12, 3.5, 4.4), Vector3.new(x, 5.5, 3.2), Color3.fromRGB(117, 183, 229), Enum.Material.SmoothPlastic))
		for _, z in ipairs({ 0.9, 5.5 }) do decorative(localPart(home, frame, "WindowFrame", Vector3.new(0.22, 3.9, 0.22), Vector3.new(x, 5.5, z), tint, Enum.Material.SmoothPlastic)) end
		for _, y in ipairs({ 3.65, 7.35 }) do decorative(localPart(home, frame, "WindowFrame", Vector3.new(0.22, 0.22, 4.8), Vector3.new(x, y, 3.2), tint, Enum.Material.SmoothPlastic)) end
		decorative(localPart(home, frame, "WindowCrossbar", Vector3.new(0.24, 3.7, 0.18), Vector3.new(x, 5.5, 3.2), wall, Enum.Material.SmoothPlastic))
		decorative(localPart(home, frame, "WindowCrossbar", Vector3.new(0.24, 0.18, 4.6), Vector3.new(x, 5.5, 3.2), wall, Enum.Material.SmoothPlastic))
	end
	-- The clear doorway and empty middle leave room for chases and weapons.
	localPart(home, frame, "InteriorTable", Vector3.new(3, 2, 2.4), Vector3.new(-4.6, 1.4, 8), colors.Wood, Enum.Material.SmoothPlastic)
	local chair = localPart(home, frame, "InteriorBench", Vector3.new(3, 1.4, 1.3), Vector3.new(4.6, 1.1, 8), tint, Enum.Material.SmoothPlastic)
	localPart(home, frame, "InteriorBenchBack", Vector3.new(3, 2.5, 0.3), Vector3.new(4.6, 2.3, 8.6), tint, Enum.Material.SmoothPlastic)
	for _, direction in ipairs({ -1, 1 }) do
		local roof = localPart(home, frame, "Roof", Vector3.new(8.5, 0.8, 16), Vector3.new(direction * 3.65, 11.9, 3.5), tint, Enum.Material.SmoothPlastic)
		roof.CFrame = roof.CFrame * CFrame.Angles(0, 0, math.rad(-direction * 28))
	end
	localPart(home, frame, "RoofRidge", Vector3.new(0.65, 0.65, 16.2), Vector3.new(0, 13.7, 3.5), tint, Enum.Material.SmoothPlastic)
	decorative(localPart(home, frame, "FrontRoofTrim", Vector3.new(14.8, 0.4, 0.5), Vector3.new(0, 10.05, -3.8), colors.DarkWood, Enum.Material.SmoothPlastic))
	localPart(home, frame, "Chimney", Vector3.new(1.5, 3, 1.5), Vector3.new(-4, 13.2, 7), Color3.fromRGB(170, 85, 0), Enum.Material.SmoothPlastic)
	local plaque = decorative(localPart(home, frame, "HouseNumber", Vector3.new(2.5, 1.1, 0.15), Vector3.new(0, 9.1, -3.88), wall, Enum.Material.SmoothPlastic))
	World.sign(plaque, Enum.NormalId.Front, string.format("%02d", number), tint, 35)
	home:SetAttribute("DoorWidth", 5.6)
	home:SetAttribute("DoorHeight", 8)
	home:SetAttribute("InteriorWidth", 13.4)
	home:SetAttribute("InteriorHeight", 9.8)
	local ramp = wedge(home, "EntranceRamp", Vector3.new(5.6, 0.4, 5), frame * CFrame.new(0, 0.2, -6), colors.Wood, Enum.Material.SmoothPlastic)
	return home, ramp
end

local function board(parent, name, position, width, height, text, color)
	World.part(parent, name .. "Frame", Vector3.new(width + 0.6, height + 0.6, 0.7), position, colors.DarkWood, Enum.Material.SmoothPlastic)
	local panel = World.part(parent, name, Vector3.new(width, height, 0.12), position + Vector3.new(0, 0, 0.42), colors.Cream)
	for _, x in ipairs({ -width / 2 + 1.5, width / 2 - 1.5 }) do
		World.part(parent, name .. "Post", Vector3.new(0.65, 4, 0.65), Vector3.new(position.X + x, position.Y - height / 2 - 1.7, position.Z), colors.DarkWood, Enum.Material.SmoothPlastic)
	end
	return World.sign(panel, Enum.NormalId.Back, text, color or colors.Ink, 24)
end

local function lighting()
	Lighting.Brightness = 2.6
	Lighting.ClockTime = 13.8
	Lighting.Ambient = Color3.fromRGB(146, 152, 173)
	Lighting.OutdoorAmbient = Color3.fromRGB(181, 188, 210)
	Lighting.ColorShift_Top = Color3.new(0, 0, 0)
	Lighting.ColorShift_Bottom = Color3.new(0, 0, 0)
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 0.35
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
	atmosphere.Density = 0.14
	atmosphere.Offset = 0.25
	atmosphere.Color = Color3.fromRGB(213, 232, 255)
	atmosphere.Decay = Color3.fromRGB(231, 207, 243)
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
	World.Houses = {}
	World.PressGeneration = (World.PressGeneration or 0) + 1
	World.PressTweens = {}
	World.Walls = {}
	World.Originals = {}
	World.Floor = World.part(World.Arena, "CentralHub", Vector3.new(2, 28, 28), Vector3.new(0, 29, 0), colors.Grass, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	World.Floor.Orientation = Vector3.new(0, 0, 90)
	floatingBase(World.Arena, Vector3.new(0, 29, 0), 25, 25)
	local hubTrim = decorative(World.part(World.Arena, "HubTrim", Vector3.new(0.5, 29, 29), Vector3.new(0, 28.3, 0), colors.Wood, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder))
	hubTrim.Orientation = Vector3.new(0, 0, 90)
	for index = 1, 12 do
		local angle = math.rad((index - 1) * 30)
		local direction = Vector3.new(math.sin(angle), 0, math.cos(angle))
		local center = direction * 62 + Vector3.new(0, 29, 0)
		local island = folder(World.Arena, "Island" .. index)
		local ground = World.part(island, "HomePlatform", Vector3.new(26, 2, 26), center, colors.Grass, Enum.Material.SmoothPlastic)
		local frame = CFrame.lookAt(center + Vector3.new(0, 1, 0), Vector3.new(0, 30, 0))
		ground.CFrame = frame * CFrame.new(0, -1, 0)
		ground.TopSurface = Enum.SurfaceType.Smooth
		ground:SetAttribute("IslandIndex", index)
		table.insert(World.Platforms, ground)
		table.insert(World.ArenaSpawns, frame:PointToWorldSpace(Vector3.new(0, 4, -8)))
		floatingBase(island, center, 26, 26)
		local home, ramp = cottage(island, frame, roofs[(index - 1) % #roofs + 1], index)
		World.Houses[index] = { Model = home, Platform = ground, OriginCFrame = frame, Origin = frame, Index = index, EntranceRamp = ramp, State = { Lift = 0, Offset = 0, Scale = 1, Tilt = 0, Paint = 0 } }
		tree(island, frame:PointToWorldSpace(Vector3.new(-10.5, 0, 8.7)), 0.65)
		local bridge = World.part(World.Arena, "Bridge" .. index, Vector3.new(6, 1, 41), direction * 31.5 + Vector3.new(0, 29.5, 0), colors.Wood, Enum.Material.SmoothPlastic)
		bridge.CFrame = CFrame.lookAt(bridge.Position, Vector3.new(0, 29.5, 0))
		table.insert(World.Bridges, bridge)
		for plank = 1, 10 do
			decorative(localPart(bridge, bridge.CFrame, "BridgePlank", Vector3.new(6.05, 0.09, 3.65), Vector3.new(0, 0.55, -18.2 + (plank - 1) * 4),
				plank % 2 == 0 and colors.Wood or Color3.fromRGB(180, 130, 83), Enum.Material.SmoothPlastic))
		end
		for _, x in ipairs({ -2.1, 2.1 }) do decorative(localPart(bridge, bridge.CFrame, "BridgeUnderbeam", Vector3.new(0.35, 1.1, 41), Vector3.new(x, -0.9, 0), colors.DarkWood, Enum.Material.SmoothPlastic)) end
		for _, distance in ipairs({ 15, 49 }) do
			local stripe = decorative(World.part(bridge, "BridgeMarker", Vector3.new(6.02, 0.05, 1.4), direction * distance + Vector3.new(0, 30.09, 0), roofs[(index - 1) % #roofs + 1]))
			stripe.CFrame = CFrame.lookAt(stripe.Position, Vector3.new(0, stripe.Position.Y, 0))
		end
	end

	local base = World.part(World.Arena, "ButtonPedestal", Vector3.new(1.5, 11, 11), Vector3.new(0, 30.75, 0), colors.Cream, nil, Enum.PartType.Cylinder)
	base.Orientation = Vector3.new(0, 0, 90)
	for index = 1, 12 do
		local angle = index * math.pi / 6
		local tile = decorative(World.part(World.Arena, "HubCompassTile", Vector3.new(2.4, 0.1, 1.5), Vector3.new(math.cos(angle) * 10, 30.06, math.sin(angle) * 10), colors.Cream, Enum.Material.SmoothPlastic))
		tile.CFrame = CFrame.new(tile.Position) * CFrame.Angles(0, -angle, 0)
	end
	local ring = World.part(World.Arena, "ButtonRing", Vector3.new(0.45, 9, 9), Vector3.new(0, 31.65, 0), colors.Gold, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	ring.Orientation = base.Orientation
	table.insert(World.Accents, ring)
	World.Button = World.part(World.Arena, "Button", Vector3.new(1.65, 8.8, 8.8), Vector3.new(0, 32.65, 0), Color3.fromRGB(255, 91, 108), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	World.Button.Orientation = base.Orientation
	World.ButtonRest = World.Button.Position
	World.ButtonRestSize = World.Button.Size
	World.PulseRings, World.OrbitTiles, World.PressRest = {}, {}, {}
	for index = 1, 2 do
		local pulse = decorative(World.part(World.Arena, "ButtonPulseRing" .. index, Vector3.new(0.12, 11.8 + index * 2, 11.8 + index * 2), Vector3.new(0, 30.25 - index * 0.06, 0), index == 1 and colors.Teal or colors.Cream, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder))
		pulse.Orientation = base.Orientation
		table.insert(World.PulseRings, pulse); table.insert(World.Accents, pulse)
		World.PressRest[pulse] = { CFrame = pulse.CFrame, Size = pulse.Size, Transparency = pulse.Transparency }
	end
	for index = 1, 6 do
		local angle = index * math.pi / 3
		local tile = decorative(World.part(World.Arena, "ButtonOrbitTile", Vector3.new(1.8, 0.14, 1), Vector3.new(math.cos(angle) * 10.8, 30.23, math.sin(angle) * 10.8), index % 2 == 0 and colors.Gold or roofs[1]))
		tile.CFrame = CFrame.new(tile.Position) * CFrame.Angles(0, -angle, 0)
		table.insert(World.OrbitTiles, tile)
		World.PressRest[tile] = { CFrame = tile.CFrame, Size = tile.Size, Transparency = tile.Transparency }
	end
	for _, x in ipairs({ -6.8, 6.8 }) do World.part(World.Arena, "ButtonBannerPost", Vector3.new(0.5, 6, 0.5), Vector3.new(x, 33, -10.8), colors.Teal) end
	local banner = decorative(World.part(World.Arena, "ButtonBanner", Vector3.new(16, 3.4, 0.5), Vector3.new(0, 37, -10.8), colors.Cream))
	World.sign(banner, Enum.NormalId.Back, "DON'T PRESS\nTHE BUTTON", Color3.fromRGB(235, 85, 112), 40)
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

	-- Linked floating terraces form a vertical social space, away from hazards.
	local function terrace(name, position, width, depth, tint)
		local model = folder(World.Lobby, name)
		local top = World.part(model, "TerraceTop", Vector3.new(2, width, depth), position - Vector3.new(0, 1, 0), tint, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		top.Orientation = Vector3.new(0, 0, 90)
		local rim = decorative(World.part(model, "TerraceRim", Vector3.new(0.7, width + 1.1, depth + 1.1), position - Vector3.new(0, 1.5, 0), colors.Cream, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder))
		rim.Orientation = top.Orientation
		floatingBase(model, position - Vector3.new(0, 1, 0), width, depth)
		return model, top
	end
	local function walkway(name, a, b, width, tint)
		local center = (a + b) / 2 - Vector3.new(0, 0.35, 0)
		local frame = CFrame.lookAt(center, b - Vector3.new(0, 0.35, 0))
		local path = World.part(World.Lobby, name, Vector3.new(width, 0.7, (b - a).Magnitude), center, tint, Enum.Material.SmoothPlastic)
		path.CFrame = frame
		for _, side in ipairs({ -1, 1 }) do
			localPart(World.Lobby, frame, name .. "Rail", Vector3.new(0.3, 2.1, (b - a).Magnitude), Vector3.new(side * (width / 2 + 0.05), 1.4, 0), colors.Cream)
		end
		return path
	end
	World.LobbyTerraces = {}
	local arrival, arrivalTop = terrace("ArrivalGarden", Vector3.new(220, 10, 23), 48, 43, colors.Grass)
	local hall, hallTop = terrace("SurvivorHall", Vector3.new(206, 18, -24), 51, 34, Color3.fromRGB(143, 190, 243))
	local overlook, overlookTop = terrace("ArenaOverlook", Vector3.new(177, 24, 12), 28, 30, Color3.fromRGB(185, 160, 239))
	local market, marketTop = terrace("SupplyGarden", Vector3.new(252, 14, -1), 35, 31, Color3.fromRGB(249, 191, 154))
	local peak, peakTop = terrace("ObbySummit", Vector3.new(250, 35.5, -39), 17, 15, colors.Teal)
	World.LobbyTerraces = { arrivalTop, hallTop, overlookTop, marketTop, peakTop }
	World.LobbySpawn = Vector3.new(220, 14, 25)
	walkway("HallRamp", Vector3.new(214, 10, 5), Vector3.new(211, 18, -11), 10, colors.Cream)
	walkway("OverlookRamp", Vector3.new(205, 10, 23), Vector3.new(185, 24, 17), 8, Color3.fromRGB(219, 208, 252))
	walkway("MarketBridge", Vector3.new(238, 10, 23), Vector3.new(248, 14, 12), 8, colors.Cream)
	walkway("HallToMarket", Vector3.new(225, 18, -19), Vector3.new(239, 14, -10), 7, Color3.fromRGB(216, 230, 250))
	walkway("SummitReturn", Vector3.new(250, 35.5, -39), Vector3.new(225, 18, -30), 6, Color3.fromRGB(208, 235, 230))
	-- Short decorative arc rails leave the connecting ramps open.
	for _, spec in ipairs({ { arrival, Vector3.new(220, 10, 23), 24, 21.5, -30, 210 }, { overlook, Vector3.new(177, 24, 12), 14, 15, 60, 300 }, { hall, Vector3.new(206, 18, -24), 25.5, 17, 30, 150 } }) do
		for degrees = spec[5], spec[6], 24 do
			local angle = math.rad(degrees)
			local position = spec[2] + Vector3.new(math.cos(angle) * (spec[3] - 1), 1.7, math.sin(angle) * (spec[4] - 1))
			World.part(spec[1], "TerraceRailPost", Vector3.new(0.35, 2.7, 0.35), position - Vector3.new(0, 0.35, 0), colors.DarkWood)
			local bar = World.part(spec[1], "TerraceArcRail", Vector3.new(6.8, 0.3, 0.3), position + Vector3.new(0, 0.85, 0), colors.Cream)
			bar.CFrame = CFrame.new(bar.Position) * CFrame.Angles(0, -angle - math.pi / 2, 0)
		end
	end
	for index, offset in ipairs({ Vector3.new(-6, 0, 3), Vector3.new(6, 0, 3), Vector3.new(-6, 0, 11), Vector3.new(6, 0, 11) }) do
		local spawn = Instance.new("SpawnLocation")
		spawn.Name, spawn.Anchored, spawn.Neutral, spawn.Duration = "LobbySpawn" .. index, true, true, 0
		spawn.Size, spawn.Position = Vector3.new(6, 0.2, 6), Vector3.new(220, 9.8, 23) + offset
		spawn.Material, spawn.Transparency = Enum.Material.SmoothPlastic, 1
		spawn.TopSurface, spawn.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		spawn.CanCollide, spawn.CanTouch, spawn.CanQuery = false, false, false
		spawn.Parent = arrival
		for _, child in ipairs(spawn:GetChildren()) do if child:IsA("Decal") or child:IsA("Texture") then child:Destroy() end end
	end
	local welcome = World.part(arrival, "WelcomeArch", Vector3.new(32, 4.2, 0.9), Vector3.new(220, 23, 38), colors.Cream)
	World.sign(welcome, Enum.NormalId.Front, "DON'T PRESS THE BUTTON", Color3.fromRGB(244, 109, 118), 35)
	for _, x in ipairs({ 205, 235 }) do World.part(arrival, "WelcomePillar", Vector3.new(1.3, 12, 1.3), Vector3.new(x, 16, 38), colors.Teal) end
	decorative(World.part(arrival, "WelcomeCord", Vector3.new(28, 0.1, 0.1), Vector3.new(220, 19, 37.4), colors.DarkWood))
	for index = 1, 9 do decorative(wedge(arrival, "PartyFlag", Vector3.new(2, 1.7, 0.12), CFrame.new(206 + index * 2.8, 18.2, 37.4) * CFrame.Angles(0, math.pi / 2, math.pi), roofs[(index - 1) % #roofs + 1])) end
	World.LeaderboardLabel = board(hall, "LeaderboardBoard", Vector3.new(208, 25.7, -35), 23, 12, "HALL OF SURVIVORS\n\nLoading leaderboard...", colors.Ink)
	World.RoundLabel = board(hall, "RoundBoard", Vector3.new(187, 24.5, -28), 16, 10, "NEXT ROUND\n\nWaiting for players", colors.Teal)
	World.CounterLabel = World.RoundLabel
	board(market, "HowToPlay", Vector3.new(244, 20, -8), 13, 7, "LAST ONE STANDING\n\nPress for disasters, gifts & PvP.\nUse your house for cover.\nWin tokens. Stock up. Climb the obby!", colors.Ink)
	local portalCenter = Vector3.new(173, 24, 12)
	for _, x in ipairs({ -4.7, 4.7 }) do World.part(overlook, "PortalPost", Vector3.new(1.1, 10, 1.4), portalCenter + Vector3.new(x, 5, 0), colors.Gold) end
	World.part(overlook, "PortalTop", Vector3.new(10.5, 1.1, 1.4), portalCenter + Vector3.new(0, 10, 0), colors.Gold)
	local portal = decorative(World.part(overlook, "RoundPortal", Vector3.new(8.2, 8.5, 0.2), portalCenter + Vector3.new(0, 4.8, 0), colors.Cream))
	World.sign(portal, Enum.NormalId.Back, "SURVIVAL ARENA\n\nPRESS E TO JOIN\nOR USE THE PLAY MENU", colors.Ink, 34)
	World.JoinPrompt = Instance.new("ProximityPrompt")
	World.JoinPrompt.ActionText, World.JoinPrompt.ObjectText = "Join next round", "SURVIVAL ARENA"
	World.JoinPrompt.KeyboardKeyCode, World.JoinPrompt.GamepadKeyCode = Enum.KeyCode.E, Enum.KeyCode.ButtonX
	World.JoinPrompt.MaxActivationDistance, World.JoinPrompt.RequiresLineOfSight, World.JoinPrompt.Parent = 12, false, portal
	local lookoutSign = decorative(World.part(overlook, "LookoutSign", Vector3.new(13, 2.2, 0.3), Vector3.new(173, 27, 1), colors.Cream))
	World.sign(lookoutSign, Enum.NormalId.Back, "WATCH THE CHAOS • JOIN THE NEXT ROUND", colors.Ink, 28)
	for _, spec in ipairs({ { arrival, Vector3.new(205, 10, 28), 1.1 }, { arrival, Vector3.new(232, 10, 32), 0.9 }, { hall, Vector3.new(191, 18, -18), 0.9 }, { market, Vector3.new(242, 14, -1), 0.9 }, { overlook, Vector3.new(172, 24, 21), 0.9 } }) do tree(spec[1], spec[2], spec[3]) end
	for _, spec in ipairs({ { arrival, Vector3.new(212, 10, 14) }, { arrival, Vector3.new(231, 10, 15) }, { hall, Vector3.new(215, 18, -15) }, { market, Vector3.new(241, 14, 0) } }) do lantern(spec[1], spec[2], 1) end
	planter(arrival, Vector3.new(211, 10, 34), 5, 2, roofs[1])
	planter(hall, Vector3.new(204, 18, -15), 5, 2, roofs[4])
	for _, spec in ipairs({ { arrival, Vector3.new(220, 11.4, 16) }, { hall, Vector3.new(205, 19.4, -20) } }) do
		World.part(spec[1], "GardenBenchSeat", Vector3.new(7, 0.5, 2.4), spec[2], colors.Wood)
		World.part(spec[1], "GardenBenchBack", Vector3.new(7, 2, 0.4), spec[2] + Vector3.new(0, 1, 1), colors.Teal)
		for _, side in ipairs({ -2.5, 2.5 }) do World.part(spec[1], "GardenBenchLeg", Vector3.new(0.5, 1.4, 1.8), spec[2] + Vector3.new(side, -0.9, 0), colors.DarkWood) end
	end
	-- An ascending route of small floating islands rewards deliberate jumps.
	local obby = folder(World.Lobby, "LobbyObby")
	World.ObbyCheckpoints = {}
	local courseSpecs = {
		{ Vector3.new(249, 15, 10), Vector3.new(6, 1.2, 6) },
		{ Vector3.new(258, 17, 10), Vector3.new(4.8, 1, 4.8) },
		{ Vector3.new(266, 19, 4), Vector3.new(5, 1, 5) },
		{ Vector3.new(263, 21, -5), Vector3.new(3.5, 1, 7) },
		{ Vector3.new(255, 23, -11), Vector3.new(5, 1, 5) },
		{ Vector3.new(255, 25, -21), Vector3.new(5, 1, 5) },
		{ Vector3.new(264, 27, -25), Vector3.new(5, 1, 5) },
		{ Vector3.new(270, 29, -33), Vector3.new(6, 1, 5) },
		{ Vector3.new(266, 31, -42), Vector3.new(5, 1, 5) },
		{ Vector3.new(257, 33, -45), Vector3.new(5, 1, 5) },
	}
	for index, spec in ipairs(courseSpecs) do
		local tint = index == 1 and colors.Teal or roofs[(index - 1) % #roofs + 1]
		local checkpoint = World.part(obby, "ObbyCheckpoint" .. index, spec[2], spec[1], tint)
		checkpoint:SetAttribute("ObbyOrder", index); checkpoint:SetAttribute("Order", index)
		World.sign(checkpoint, Enum.NormalId.Top, tostring(index), colors.Cream, 25)
		table.insert(World.ObbyCheckpoints, checkpoint)
		decorative(wedge(obby, "ObbyIslandFacet", Vector3.new(spec[2].X * 0.85, 3, spec[2].Z * 0.85), CFrame.new(spec[1] - Vector3.new(0, 2, 0)) * CFrame.Angles(math.pi, index, 0), tint:Lerp(colors.Ink, 0.22)))
	end
	World.ObbyStart = courseSpecs[1][1] + Vector3.new(0, 4, 0)
	World.ObbyFinish = World.part(obby, "ObbyFinish", Vector3.new(7, 1, 7), Vector3.new(250, 35.8, -39), colors.Teal)
	World.ObbyFinish:SetAttribute("ObbyOrder", #courseSpecs + 1); World.ObbyFinish:SetAttribute("Order", #courseSpecs + 1)
	World.sign(World.ObbyFinish, Enum.NormalId.Top, "FINISH", colors.Cream, 35)
	local courseSign = decorative(World.part(market, "ObbyRules", Vector3.new(9, 3.5, 0.3), Vector3.new(240, 18, 11), colors.Cream))
	World.sign(courseSign, Enum.NormalId.Front, "SKY CLIMB\nSTART AT 1 → REACH THE SUMMIT", colors.Ink, 30)
	for _, x in ipairs({ 246.8, 253.2 }) do World.part(peak, "FinishFlagPole", Vector3.new(0.3, 4, 0.3), Vector3.new(x, 37.5, -39), colors.Ink) end
	decorative(World.part(peak, "FinishFlag", Vector3.new(6, 1.2, 0.2), Vector3.new(250, 38.7, -39), colors.Gold))

	local scenery = folder(World.Root, "CloudScenery")
	World.Clouds, World.CloudColors = {}, {}
	for index = 1, 6 do
		local angle = math.rad(index * 26)
		local radius = 240
		local center = Vector3.new(math.sin(angle) * radius + 65, -32, math.cos(angle) * radius)
		for _, offset in ipairs({ Vector3.new(-10, 0, 0), Vector3.new(0, 2, 0), Vector3.new(11, -1, 0) }) do
			local cloud = decorative(World.part(scenery, "Cloud", Vector3.new(29, 8, 19), center + offset, Color3.fromRGB(250, 253, 255), Enum.Material.SmoothPlastic, Enum.PartType.Ball))
			cloud.CastShadow = false
			table.insert(World.Clouds, cloud)
			World.CloudColors[cloud] = cloud.Color
		end
	end
	for index = 1, 4 do
		local angle = index * math.pi / 4
		local cloud = decorative(World.part(scenery, "HorizonCloud", Vector3.new(52, 8, 25), Vector3.new(math.cos(angle) * 360 + 80, 38 + (index % 3) * 10, math.sin(angle) * 360), Color3.fromRGB(242, 249, 255), Enum.Material.SmoothPlastic, Enum.PartType.Ball))
		cloud.CastShadow = false
		table.insert(World.Clouds, cloud)
		World.CloudColors[cloud] = cloud.Color
	end
	local background = folder(World.Root, "DistantSkyIslands")
	for index = 1, 6 do
		local angle = index * math.pi / 3 + 0.3
		local position = Vector3.new(math.cos(angle) * 290 + 90, 2 + (index % 3) * 14, math.sin(angle) * 300)
		decorative(World.part(background, "DistantMeadow", Vector3.new(31, 2, 23), position, Color3.fromRGB(131, 187, 151), Enum.Material.SmoothPlastic))
		for facet = 1, 3 do
			decorative(wedge(background, "DistantCliff", Vector3.new(24, 30, 22), CFrame.new(position - Vector3.new(facet * 3 - 6, 17, facet * 2 - 4)) * CFrame.Angles(math.pi, facet * 1.8, 0), Color3.fromRGB(136, 166, 177), Enum.Material.SmoothPlastic))
		end
		tree(background, position + Vector3.new(-7, 1, 3), 1.1)
	end
	for _, part in ipairs(World.Arena:GetDescendants()) do
		if part:IsA("BasePart") then
			World.Originals[part] = { Size = part.Size, CFrame = part.CFrame, Color = part.Color, Material = part.Material, Transparency = part.Transparency, CanCollide = part.CanCollide, CustomPhysicalProperties = part.CustomPhysicalProperties }
		end
	end
	World.RoundOriginals = {}
	for part, original in pairs(World.Originals) do World.RoundOriginals[part] = table.clone(original) end
	lighting()
	return World
end

local function rememberMutation(part)
	-- Only geometry and paint are lasting. A concurrent hazard may have hidden
	-- the house or changed collision, and that state must stay temporary.
	local baseline = table.clone(World.RoundOriginals[part] or World.Originals[part])
	baseline.Size, baseline.CFrame, baseline.Color = part.Size, part.CFrame, part.Color
	World.RoundOriginals[part] = baseline
end

local function restore(snapshot)
	for part, properties in pairs(snapshot or {}) do
		if part.Parent then
			for property, value in pairs(properties) do part[property] = value end
			-- Nil physical properties do not survive pairs(), but are meaningful.
			part.CustomPhysicalProperties = properties.CustomPhysicalProperties
		end
	end
end

function World.restoreTransientArena()
	restore(World.RoundOriginals or World.Originals)
	World.theme("Normal")
end

function World.resetArena()
	World.RoundOriginals = {}
	for part, original in pairs(World.Originals or {}) do World.RoundOriginals[part] = table.clone(original) end
	for _, house in ipairs(World.Houses or {}) do
		house.State = { Lift = 0, Offset = 0, Scale = 1, Tilt = 0, Paint = 0 }
		house.Model:SetAttribute("MutationCount", 0)
		house.Model:SetAttribute("DoorWidth", 5.6); house.Model:SetAttribute("DoorHeight", 8)
		house.Model:SetAttribute("InteriorWidth", 13.4); house.Model:SetAttribute("InteriorHeight", 9.8)
	end
	World.restoreTransientArena()
end

function World.resolveHouse(subject)
	if typeof(subject) == "number" then return World.Houses[subject] end
	local position = typeof(subject) == "Vector3" and subject or nil
	if typeof(subject) == "Instance" then
		local assigned = subject:GetAttribute("HouseIndex")
		if typeof(assigned) == "number" and World.Houses[assigned] then return World.Houses[assigned] end
		local character = subject:IsA("Player") and subject.Character or subject
		local root = character and character:FindFirstChild("HumanoidRootPart")
		position = root and root.Position
	end
	if not position then return end
	local closest, distance
	for _, house in ipairs(World.Houses or {}) do
		local difference = house.Platform.Position - position
		local flat = Vector3.new(difference.X, 0, difference.Z).Magnitude
		if flat <= 21 and (not distance or flat < distance) then closest, distance = house, flat end
	end
	return closest
end

function World.mutateHouse(index, kind)
	if typeof(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > #(World.Houses or {}) then return false end
	local house = World.Houses[index]
	if not house or not house.Model.Parent then return false end
	local state = house.State
	if kind == "lift" then state.Lift = math.min(7.2, state.Lift + 2.4)
	elseif kind == "relocate" then state.Offset = state.Offset >= 0 and -4.5 or 4.5
	elseif kind == "shrink" then state.Scale = math.max(0.82, state.Scale - 0.06)
	elseif kind == "tilt" then state.Tilt = state.Tilt >= 0 and -math.rad(8) or math.rad(8)
	elseif kind == "paint" then state.Paint += 1
	else return false end
	local frame = house.OriginCFrame * CFrame.new(state.Offset, state.Lift, 0) * CFrame.Angles(0, 0, state.Tilt)
	local tint = roofs[(house.Index + state.Paint - 1) % #roofs + 1]
	for _, part in ipairs(house.Model:GetDescendants()) do
		if part:IsA("BasePart") and part ~= house.EntranceRamp then
			local original = World.Originals[part]
			local relative = house.OriginCFrame:ToObjectSpace(original.CFrame)
			part.Size = original.Size * state.Scale
			part.CFrame = frame * CFrame.new(relative.Position * state.Scale) * (relative - relative.Position)
			part.Color = state.Paint > 0 and original.Color:Lerp(tint, part.Name:match("Wall") and 0.4 or 0.8) or original.Color
			rememberMutation(part)
		end
	end
	-- The entrance remains connected to the unchanged island after a lift.
	local ramp = house.EntranceRamp
	local height = 0.4 * state.Scale + state.Lift
	ramp.Size = Vector3.new(5.6 * state.Scale, math.max(0.35, height), 9)
	ramp.CFrame = house.OriginCFrame * CFrame.new(state.Offset, height / 2, -3.5 * state.Scale - 4.5)
	ramp.Color = state.Paint > 0 and colors.Wood:Lerp(tint, 0.5) or colors.Wood
	rememberMutation(ramp)
	house.Model:SetAttribute("MutationCount", (house.Model:GetAttribute("MutationCount") or 0) + 1)
	house.Model:SetAttribute("DoorWidth", 5.6 * state.Scale); house.Model:SetAttribute("DoorHeight", 8 * state.Scale)
	house.Model:SetAttribute("InteriorWidth", 13.4 * state.Scale); house.Model:SetAttribute("InteriorHeight", 9.8 * state.Scale)
	return true
end

function World.theme(name)
	local palette = palettes[name] or palettes.Normal
	local normal = name == "Normal" or not palettes[name]
	local baseline = World.RoundOriginals or World.Originals
	World.Floor.Color = normal and baseline[World.Floor].Color or palette[1]
	for _, part in ipairs(World.Platforms) do part.Color = normal and baseline[part].Color or palette[1] end
	for _, part in ipairs(World.Accents) do part.Color = normal and baseline[part].Color or palette[2] end
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
	World.PressGeneration += 1
	local generation, button = World.PressGeneration, World.Button
	for _, tween in ipairs(World.PressTweens) do if tween.Cancel then tween:Cancel() end end
	World.PressTweens = {}
	for part, rest in pairs(World.PressRest) do
		part.CFrame, part.Size, part.Transparency = rest.CFrame, rest.Size, rest.Transparency
	end
	button.Position, button.Size = World.ButtonRest, World.ButtonRestSize
	button.Color, World.ButtonLight.Color = color, color
	local function animate(part, seconds, properties, style)
		local tween = TweenService:Create(part, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), properties)
		table.insert(World.PressTweens, tween); tween:Play()
	end
	animate(button, 0.1, { Position = World.ButtonRest - Vector3.new(0, 0.43, 0), Size = Vector3.new(0.95, 9.6, 9.6) })
	for index, pulse in ipairs(World.PulseRings) do
		animate(pulse, 0.42, { Size = Vector3.new(0.12, 22 + index * 2, 22 + index * 2), Transparency = 0.92 })
	end
	for _, tile in ipairs(World.OrbitTiles) do
		local rest = World.PressRest[tile]
		animate(tile, 0.32, { CFrame = CFrame.Angles(0, math.rad(30), 0) * rest.CFrame, Size = rest.Size * 1.18 })
	end
	task.delay(0.12, function()
		if generation ~= World.PressGeneration or button ~= World.Button or not button.Parent then return end
		animate(button, 0.28, { Position = World.ButtonRest, Size = World.ButtonRestSize }, Enum.EasingStyle.Back)
	end)
	task.delay(0.43, function()
		if generation ~= World.PressGeneration or button ~= World.Button or not button.Parent then return end
		for part, rest in pairs(World.PressRest) do animate(part, 0.22, { CFrame = rest.CFrame, Size = rest.Size, Transparency = rest.Transparency }) end
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
