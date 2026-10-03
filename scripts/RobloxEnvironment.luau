-- Offline construction checks use Lune's real Roblox property database.
-- Scheduling, input, and physics remain the responsibility of Studio playtests.
local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local modules = {
	Config = require("../src/shared/Config"), Catalog = require("../src/shared/Catalog"),
	Profile = require("../src/shared/Profile"), Economy = require("../src/shared/Economy"),
	Rules = require("../src/shared/Rules"),
}
local Environment = {}
local registered = false
function Environment.new(dataModel)
	local signals = {}
	local function signal(instance, name)
		signals[instance] = signals[instance] or {}
		if not signals[instance][name] then
			local event = { Callbacks = {} }
			function event:Connect(callback)
				table.insert(self.Callbacks, callback)
				return { Disconnect = function() end }
			end
			function event:Fire(...)
				for _, callback in ipairs(self.Callbacks) do callback(...) end
			end
			signals[instance][name] = event
		end
		return signals[instance][name]
	end
	if not registered then
	for class, names in pairs({ Instance = { "Destroying" }, BasePart = { "Touched" }, GuiButton = { "Activated" } }) do
		for _, name in ipairs(names) do
			roblox.implementProperty(class, name, function(instance) return signal(instance, name) end)
		end
	end
	end
	local game = dataModel or roblox.Instance.new("DataModel")
	local workspace = game:GetService("Workspace")
	local playerGui = roblox.Instance.new("PlayerGui")
	local services = {
		Workspace = workspace, Lighting = game:GetService("Lighting"),
		ReplicatedStorage = { Shared = modules, WaitForChild = function() return modules end },
		Players = { LocalPlayer = { WaitForChild = function() return playerGui end }, GetPlayers = function() return {} end },
		Debris = { AddItem = function() end },
		TweenService = { Create = function(_, object, _, targets)
			return { Play = function() for property, value in pairs(targets) do object[property] = value end end }
		end },
	}
	if not registered then
	roblox.implementMethod("Workspace", "GetServerTimeNow", function() return 100 end)
	roblox.implementMethod("Model", "GetPivot", function(model)
		return model.PrimaryPart and model.PrimaryPart.CFrame or roblox.CFrame.new()
	end)
	registered = true
	end
	local camera = roblox.Instance.new("Camera")
	camera.Parent = workspace
	workspace.CurrentCamera = camera
	local viewport = roblox.Vector2.new(1280, 720)
	camera.ViewportSize = viewport
	local delayed = {}
	local env = {
		game = { GetService = function(_, name) assert(services[name], name); return services[name] end },
		workspace = workspace,
		require = function(module) assert(modules[module] or type(module) == "table", tostring(module)); return modules[module] or module end,
		task = { spawn = function() end, wait = function() end, delay = function(_, fn) table.insert(delayed, fn) end },
		TweenInfo = { new = function(...) return { ... } end },
		Random = { new = function()
			return { NextNumber = function(_, low, high) return (low + high) / 2 end, NextInteger = function(_, low) return low end }
		end },
	}
	for _, name in ipairs({ "Instance", "Vector2", "Vector3", "CFrame", "Color3", "UDim", "UDim2", "Enum", "NumberRange", "NumberSequence", "ColorSequence", "Font" }) do env[name] = roblox[name] end
	local result = { Game = game, Workspace = workspace, Services = services, Env = env, PlayerGui = playerGui, Delayed = delayed }
	function result.load(path) return luau.load(fs.readFile(path), { environment = env, debugName = path })() end
	function result.viewport(width, height)
		viewport = roblox.Vector2.new(width, height)
		camera.ViewportSize = viewport
	end
	return result
end
return Environment
