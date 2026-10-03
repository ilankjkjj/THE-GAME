-- All tuning lives here. No paid assets, packages, or monetization are required.
return table.freeze({
	SpecialEvery = 99,
	SpecialDuration = 30,
	SpecialCoins = 100,
	SpecialPoints = 25,
	StartingCoins = 30,
	PointsPerPress = 1,
	CoinsPerPress = 2,
	PressCooldown = 0.8,
	PressDistance = 15,
	TaxCost = 5,
	TaxDuration = 45,
	KingDuration = 30,
	AutosaveSeconds = 45,
	SessionLeaseSeconds = 180,
	LeaderboardSeconds = 60,
	LeaderboardSize = 10,
	ProfileStore = "ButtonProfiles_v1",
	LeaderboardStore = "ButtonPresses_v1",
	-- Studio uses disposable progress by default, protecting real player saves.
	PersistenceInStudio = false,
})
