-- Pure round decisions also run in the offline checks.
local RoundRules = {}
function RoundRules.canStart(queuedCount, config)
	return queuedCount >= config.MinimumPlayers
end
function RoundRules.outcome(aliveCount, startingCount, timeExpired)
	if aliveCount == 0 then return "Draw" end
	if startingCount > 1 and aliveCount == 1 then return "Winner" end
	if startingCount == 1 and timeExpired then return "SoloSurvived" end
	if startingCount > 1 and timeExpired then return "SuddenDeath" end
	return "Continue"
end
function RoundRules.threat(elapsed, config)
	return math.clamp(1 + math.floor(elapsed / (config.RoundSeconds / 4)), 1, 5)
end
function RoundRules.status(inRound, queued, eliminated)
	if inRound then return "Playing" end
	if eliminated then return "Eliminated" end
	return queued and "Queued" or "Lobby"
end
return RoundRules
