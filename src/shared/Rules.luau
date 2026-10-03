local Rules = {}
function Rules.canPress(now, readyAt, distance, alive, loaded, config)
	if not loaded then return false, "Your progress is still loading." end
	if not alive then return false, "Respawn to press again." end
	if distance > config.PressDistance then return false, "Walk up to the big red button." end
	if now < readyAt then return false, "Wait for the current event to finish." end
	return true
end
function Rules.advance(remaining, config)
	local nextValue = remaining - 1
	return nextValue, nextValue == 0, nextValue == 0 and config.SpecialDuration or config.PressCooldown
end
return Rules
