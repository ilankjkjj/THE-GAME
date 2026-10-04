-- Keeps the event bank varied while shifting toward major disasters late in a round.
local Director = {}
function Director.weight(event, threat, lastCategory)
	local intensity = math.clamp(event.Intensity or 1, 1, 3)
	local weight = event.Weight or 1
	local danger = math.clamp(threat or 1, 1, 5)
	if event.Category == "PvP" then
		weight *= 1.65 + (danger - 1) * 0.16
	elseif event.Category == "Disaster" then
		weight *= 1.15 + (danger - 1) * 0.18 * intensity
		if lastCategory == "Relief" or lastCategory == "Challenge" then weight *= 1.35 end
	elseif event.Category == "Relief" then
		weight *= math.max(0.28, 0.8 - (danger - 1) * 0.12)
		if lastCategory == "Relief" then weight *= 0.12 end
	elseif lastCategory == "Disaster" then
		weight *= 1.25
	end
	return math.max(0.001, weight)
end
function Director.select(definitions, aliveCount, threat, history, random)
	if aliveCount <= 0 then return nil end
	history = history or {}
	local recent = {}
	for _, played in ipairs(history) do recent[played.Id] = true end
	local last = history[#history]
	local function candidates(avoidRecent, openingDisaster)
		local choices, total = {}, 0
		for _, event in ipairs(definitions) do
			if aliveCount >= (event.MinPlayers or 1) and (not avoidRecent or not recent[event.Id])
				and (not last or event.Id ~= last.Id) and (not openingDisaster or event.Category == "Disaster" or event.Category == "PvP") then
				local weight = Director.weight(event, threat, last and last.Category)
				table.insert(choices, { Event = event, Weight = weight }); total += weight
			end
		end
		return choices, total
	end
	local choices, total = candidates(true, #history == 0)
	if #choices == 0 then choices, total = candidates(true, false) end
	if #choices == 0 then choices, total = candidates(false, false) end
	if #choices == 0 then return nil end
	local roll = random:NextNumber(0, total)
	for _, choice in ipairs(choices) do roll -= choice.Weight; if roll <= 0 then return choice.Event end end
	return choices[#choices].Event
end
function Director.remember(history, event)
	table.insert(history, { Id = event.Id, Category = event.Category })
	while #history > 4 do table.remove(history, 1) end
end
return table.freeze(Director)
