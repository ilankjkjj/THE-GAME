-- These bundled Roblox sounds work immediately without uploading assets.
-- Replace SoundId with your own uploaded assets to use assets/audio/*.wav.
local boom = "rbxasset://sounds/impact_explosion_03.mp3"
local jump = "rbxasset://sounds/action_jump_land.mp3"
local chime = "rbxasset://sounds/action_get_up.mp3"
local pop = "rbxasset://sounds/volume_slider.ogg"
local swoosh = "rbxasset://sounds/action_jump.mp3"
local splash = "rbxasset://sounds/impact_water.mp3"
return table.freeze({
	press = { SoundId = jump, Volume = 0.4, PlaybackSpeed = 1.15, Duration = 2 },
	warning = { SoundId = chime, Volume = 0.32, PlaybackSpeed = 0.85, Duration = 2 },
	impact = { SoundId = boom, Volume = 0.38, PlaybackSpeed = 0.9, Duration = 3 },
	explosion = { SoundId = boom, Volume = 0.5, PlaybackSpeed = 0.75, Duration = 4 },
	lightning = { SoundId = boom, Volume = 0.38, PlaybackSpeed = 1.3, Duration = 3 },
	eruption = { SoundId = boom, Volume = 0.5, PlaybackSpeed = 0.55, Duration = 4 },
	storm = { SoundId = boom, Volume = 0.3, PlaybackSpeed = 0.65, Duration = 4 },
	scifi = { SoundId = chime, Volume = 0.32, PlaybackSpeed = 0.6, Duration = 3 },
	chase = { SoundId = jump, Volume = 0.36, PlaybackSpeed = 0.75, Duration = 2 },
	relief = { SoundId = chime, Volume = 0.34, PlaybackSpeed = 1.2, Duration = 2 },
	eventstart = { SoundId = chime, Volume = 0.3, PlaybackSpeed = 0.85, Duration = 2 },
	roundstart = { SoundId = chime, Volume = 0.4, PlaybackSpeed = 1.05, Duration = 2 },
	roundend = { SoundId = chime, Volume = 0.4, PlaybackSpeed = 1.3, Duration = 2 },
	reward = { SoundId = chime, Volume = 0.26, PlaybackSpeed = 1.6, Duration = 2 },
	gunshot = { SoundId = boom, Volume = 0.36, PlaybackSpeed = 1.8, Duration = 1 },
	sword = { SoundId = swoosh, Volume = 0.35, PlaybackSpeed = 1.2, Duration = 1 },
	role = { SoundId = pop, Volume = 0.35, PlaybackSpeed = 0.7, Duration = 2 },
	supply = { SoundId = pop, Volume = 0.32, PlaybackSpeed = 1.1, Duration = 2 },
	checkpoint = { SoundId = pop, Volume = 0.2, PlaybackSpeed = 1.5, Duration = 1 },
	obby = { SoundId = chime, Volume = 0.4, PlaybackSpeed = 1.4, Duration = 2 },
	purchase = { SoundId = pop, Volume = 0.32, PlaybackSpeed = 1.3, Duration = 1 },
	knockout = { SoundId = jump, Volume = 0.4, PlaybackSpeed = 0.8, Duration = 2 },
	victory = { SoundId = chime, Volume = 0.5, PlaybackSpeed = 1.3, Duration = 3 },
	flood = { SoundId = splash, Volume = 0.4, PlaybackSpeed = 0.8, Duration = 3 },
})
