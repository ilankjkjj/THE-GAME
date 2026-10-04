local Rules = {}
function Rules.canPress(now, readyAt, distance, alive, loaded, config, inRound)
	if not loaded then return false, "Your progress is still loading." end
	if not alive then return false, "You are out! Watch the survivors or join the next round." end
	if inRound == false then return false, "Join the next round to use the arena button." end
	if distance > config.PressDistance then return false, "Get close to the arena button." end
	if now < readyAt then return false, "The button is bouncing back. Try again in a moment." end
	return true
end
return Rules
