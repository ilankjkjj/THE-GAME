local items = {
	{ Id = "skin_classic", Category = "Skin", Name = "Classic red", Price = 0, Color = { 255, 68, 83 }, Description = "The original temptation." },
	{ Id = "skin_mint", Category = "Skin", Name = "Mint condition", Price = 20, Color = { 78, 255, 191 }, Description = "Suspiciously refreshing." },
	{ Id = "skin_gold", Category = "Skin", Name = "Solid gold", Price = 100, Color = { 255, 199, 65 }, Description = "Excellent financial decisions." },
	{ Id = "skin_cosmic", Category = "Skin", Name = "Cosmic violet", Price = 200, Color = { 167, 111, 255 }, Description = "A button from another dimension." },
	{ Id = "trail_mint", Category = "Trail", Name = "Mint streak", Price = 35, Color = { 78, 255, 191 }, Description = "Leave a little chaos behind." },
	{ Id = "trail_fire", Category = "Trail", Name = "Hot footsteps", Price = 80, Color = { 255, 121, 53 }, Description = "For extremely important running." },
	{ Id = "title_curious", Category = "Title", Name = "CURIOUS", Price = 15, Description = "You had to find out." },
	{ Id = "title_menace", Category = "Title", Name = "CERTIFIED MENACE", Price = 125, Description = "This is absolutely your fault." },
	{ Id = "sound_squeak", Category = "Sound", Name = "Tiny squeak", Price = 25, Sound = "rbxasset://sounds/action_get_up.mp3", Pitch = 1.8, Description = "Small sound. Big consequences." },
	{ Id = "sound_boom", Category = "Sound", Name = "Dramatic boom", Price = 60, Sound = "rbxasset://sounds/impact_explosion_03.mp3", Pitch = 0.65, Description = "Make an entrance." },
	{ Id = "emote_dance", Category = "Emote", Name = "Victory dance", Price = 40, Command = "dance", Description = "Celebrate with the EMOTE button." },
	{ Id = "emote_cheer", Category = "Emote", Name = "Big cheer", Price = 30, Command = "cheer", Description = "A perfectly reasonable reaction." },
	{ Id = "pet_orb", Category = "Pet", Name = "Little trouble", Price = 75, Color = { 78, 255, 191 }, Description = "Your own floating accomplice." },
	{ Id = "pet_chicken", Category = "Pet", Name = "Pocket chicken", Price = 180, Color = { 255, 226, 152 }, Description = "Cluck around and find out." },
	{ Id = "boost_2", Category = "Multiplier", Name = "2x coin rewards", Price = 150, Multiplier = 2, Description = "Double every earned coin reward." },
	{ Id = "boost_3", Category = "Multiplier", Name = "3x coin rewards", Price = 400, Multiplier = 3, Description = "Triple every earned coin reward." },
}
local byId = {}
for _, item in ipairs(items) do
	byId[item.Id] = item
end
return { Items = items, ById = byId, Categories = { "Skin", "Trail", "Title", "Sound", "Emote", "Pet", "Multiplier" } }
