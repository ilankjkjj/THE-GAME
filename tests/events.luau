-- Deterministic event gameplay checks. Roblox's native property database checks
-- construction; a virtual clock exercises jobs and cancellation without physics.
-- Real player movement, networking and balance still require Studio playtests.
local Environment = require('../scripts/RobloxEnvironment')
local roblox = require('@lune/roblox')
local env = Environment.new()
env.Env.PhysicalProperties = roblox.PhysicalProperties
local t, jobs, errors = 0, {}, {}
local canceled = {}
env.Env.os = table.clone(os)
env.Env.os.clock = function() return t end
local function resume(job)
 if canceled[job.Thread] or coroutine.status(job.Thread) == 'dead' then return end
 local ok, delay = coroutine.resume(job.Thread)
 if not ok then table.insert(errors, tostring(delay)); canceled[job.Thread] = true; return end
 job.Due = t + (type(delay) == 'number' and delay or 0.15)
end
env.Env.task = {
 spawn = function(callback)
  local job = {Thread=coroutine.create(callback), Due=t}
  table.insert(jobs, job); resume(job); return job.Thread
 end,
 wait = function(delay) return coroutine.yield(delay or 0.15) end,
 cancel = function(thread) canceled[thread] = true end,
}
local function advance(seconds)
 local untilTime = t + seconds
 local resumes = 0
 while true do
  local selected
  for _, job in ipairs(jobs) do
   if not canceled[job.Thread] and coroutine.status(job.Thread) ~= 'dead' and job.Due <= untilTime and (not selected or job.Due < selected.Due) then selected=job end
  end
  if not selected then break end
  t=selected.Due; resume(selected); resumes+=1
  assert(resumes<20000, 'unbounded scheduling')
 end
 t=untilTime
end
local world = env.load('src/server/World.luau').build()
local events = env.load('src/server/Events.luau')
assert(#events.Definitions == 29)
local eventIds = {}
for _, event in ipairs(events.Definitions) do
 assert(not eventIds[event.Id], 'duplicate event ID'); eventIds[event.Id]=true
 assert(event.Duration>=12 and event.Duration<=20, 'event duration')
 local chosen=events.choose(1,event.Id,10)
 assert(chosen and chosen.MinPlayers<=1 and chosen.Id~=event.Id,'player/repeat filtering')
end
assert(events.choose(0)==nil,'empty arena must not select an event')
print('PASS event registration, durations, participant filtering and no repeats')
local originalGravity=env.Workspace.Gravity
local originals={}
for _, folder in ipairs({world.Arena,world.Lobby}) do
 for _, part in ipairs(folder:GetDescendants()) do
  if part:IsA('BasePart') then
   originals[part]={CFrame=part.CFrame,Size=part.Size,CanCollide=part.CanCollide,Transparency=part.Transparency,Color=part.Color,Material=part.Material,CustomPhysicalProperties=part.CustomPhysicalProperties}
  end
 end
end
local players, alive, awards, damages, roles = {}, {}, {}, {}, {}
local function makePlayer(index, position)
 local player = roblox.Instance.new('Player')
 player.Name = 'Player'..index; player.DisplayName=player.Name; player.UserId=index; player.Parent=env.Game:GetService('Players')
 local character = roblox.Instance.new('Model'); character.Name=player.Name; character.Parent=env.Workspace
 local humanoid = roblox.Instance.new('Humanoid'); humanoid.Health=100; humanoid.FloorMaterial=roblox.Enum.Material.Grass; humanoid.WalkSpeed=16; humanoid.JumpPower=50; humanoid.JumpHeight=7.2; humanoid.Parent=character
 local root=roblox.Instance.new('Part'); root.Name='HumanoidRootPart'; root.AssemblyMass=10; root.AssemblyLinearVelocity=roblox.Vector3.zero; root.Position=position; root.Parent=character
 player.Character=character
 return player
end
for index=1,3 do table.insert(players, makePlayer(index, world.ArenaSpawns[index])) end
local lobbyPlayer=makePlayer(99, world.LobbySpawn)
local roundActive=true
local context={
 World=world, State={}, Remotes={}, Active=function() return roundActive end,
 Players=function()
  local result={}; for _, player in ipairs(players) do if alive[player] and player.Character.Humanoid.Health>0 then table.insert(result,player) end end; return result
 end,
 IsAlive=function(player) return player and alive[player] == true and player.Character.Humanoid.Health>0 end,
 Award=function(player,coins,points) assert(player~=lobbyPlayer,'lobby reward'); awards[player]=(awards[player] or 0)+coins end,
 Damage=function(player,amount) assert(player~=lobbyPlayer,'lobby damage'); damages[player]=(damages[player] or 0)+amount; player.Character.Humanoid.Health=math.max(0,player.Character.Humanoid.Health-amount) end,
 Eliminate=function(player) assert(player~=lobbyPlayer,'lobby elimination'); alive[player]=false; player.Character.Humanoid.Health=0 end,
 SetRole=function(player,role) assert(player~=lobbyPlayer,'lobby role'); roles[player]=role end,
}
local function reset()
 t,jobs,errors,canceled=0,{},{},{}
 roundActive=true; alive,awards,damages,roles={},{},{},{}
 for index,player in ipairs(players) do
  alive[player]=true; player.Character.Humanoid.Health=100; player.Character.Humanoid.WalkSpeed=16; player.Character.Humanoid.JumpPower=50; player.Character.Humanoid.JumpHeight=7.2
  player.Character.HumanoidRootPart.Position=world.ArenaSpawns[index]
 end
end
for _,definition in ipairs(events.Definitions) do
 reset()
 local cleanup=definition.Run(context,players[1])
 advance(definition.Duration-0.2)
 assert(#errors==0,definition.Id..': '..table.concat(errors,'; '))
 roundActive=false; cleanup(); cleanup()
 assert(#world.Effects:GetChildren()==0,definition.Id..' effects leak')
 for _, player in ipairs(players) do
  assert(player.Character.Humanoid.WalkSpeed==16,definition.Id..' WalkSpeed leak')
  assert(player.Character.Humanoid.JumpPower==50,definition.Id..' JumpPower leak')
  assert(math.abs(player.Character.Humanoid.JumpHeight-7.2)<0.001,definition.Id..' JumpHeight leak')
  assert(not player.Character.HumanoidRootPart:FindFirstChild('EventMoonGravity'),definition.Id..' moon gravity leak')
  assert(player:GetAttribute('EventHint')==nil,definition.Id..' hint leak')
  assert(player:GetAttribute('EventTimer')==nil,definition.Id..' timer leak')
 end
 assert(env.Workspace.Gravity==originalGravity,definition.Id..' global gravity change')
 for part, properties in pairs(originals) do
  for property,value in pairs(properties) do assert(part[property]==value,definition.Id..' changed '..part.Name..'.'..property) end
  assert(part.CustomPhysicalProperties==properties.CustomPhysicalProperties,definition.Id..' physical properties leak')
 end
 advance(30)
 assert(#errors==0,definition.Id..' late task error: '..table.concat(errors,'; '))
 print('PASS runtime',definition.Id)
end
assert(lobbyPlayer.Character.Humanoid.Health==100)
print('All 29 scheduled events cancel, restore, and exclude lobby participants.')



local function definition(id)
 for _, event in ipairs(events.Definitions) do if event.Id==id then return event end end
 error(id)
end
reset()
players[1].Character.HumanoidRootPart.Position=roblox.Vector3.new(0,34,0)
players[2].Character.HumanoidRootPart.Position=roblox.Vector3.new(2,34,0)
local cleanup=definition('cops_robbers').Run(context,players[1])
advance(3.9); assert(alive[players[2]],'cop ignored head start')
advance(0.4); assert(not alive[players[2]],'cop failed capture'); assert(awards[players[1]]==30,'cop capture reward')
cleanup(); print('PASS cop head start and authoritative capture')
reset()
cleanup=definition('cops_robbers').Run(context,players[1]); advance(19.3)
assert(awards[players[2]]==35,'robber escape reward'); cleanup(); print('PASS robber survival reward')
reset()
players[1].Character.HumanoidRootPart.Position=roblox.Vector3.new(0,34,0)
players[2].Character.HumanoidRootPart.Position=roblox.Vector3.new(2,34,0)
cleanup=definition('hot_potato').Run(context,players[1]); advance(1.4)
assert(roles[players[2]]=='Hot Potato','potato failed proximity transfer')
assert(players[2]:GetAttribute('EventTimer')==108,'timer must be absolute server time')
assert(players[1]:GetAttribute('EventTimer')==nil,'previous potato timer stale')
advance(7); local eliminated=0; for _, player in ipairs(players) do if not alive[player] then eliminated+=1 end end
assert(eliminated==1,'potato expiry eliminated wrong count'); cleanup(); print('PASS potato transfer, absolute timer, and expiry')
reset()
players[1].Character.HumanoidRootPart.Position=roblox.Vector3.new(0,34,0)
players[2].Character.HumanoidRootPart.Position=roblox.Vector3.new(2,34,0)
cleanup=definition('freeze_tag').Run(context,players[1]); advance(3.2)
assert(players[2].Character.Humanoid.WalkSpeed==0,'freeze failed')
advance(2.3); assert(players[2].Character.Humanoid.WalkSpeed==16,'thaw failed')
assert(math.abs(players[2].Character.Humanoid.JumpHeight-7.2)<0.001,'thaw JumpHeight'); cleanup(); print('PASS freeze tag and timed thaw')
reset()
cleanup=definition('moon_gravity').Run(context,players[1])
assert(players[1].Character.HumanoidRootPart:FindFirstChild('EventMoonGravity'),'missing moon force')
alive[players[1]]=false; advance(0.2)
assert(not players[1].Character.HumanoidRootPart:FindFirstChild('EventMoonGravity'),'moon force followed eliminated player')
assert(not lobbyPlayer.Character.HumanoidRootPart:FindFirstChild('EventMoonGravity'),'moon force in lobby')
cleanup(); print('PASS moon force removal on leaving round')
reset()
cleanup=definition('meteor_shower').Run(context,players[1]); advance(1)
cleanup(); local awardBefore=table.clone(awards); local damageBefore=table.clone(damages); advance(30)
assert(#world.Effects:GetChildren()==0,'canceled meteor late effect')
for _, player in ipairs(players) do assert(awards[player]==awardBefore[player] and damages[player]==damageBefore[player],'canceled event late effect') end
assert(#errors==0,table.concat(errors,'; ')); print('PASS early cleanup cancels pending hazards')

reset()
cleanup=definition('meteor_shower').Run(context,players[1])
advance(1)
players[1].Character.HumanoidRootPart.Position=roblox.Vector3.new(0,34,0)
advance(1.4)
assert(players[1].Character.Humanoid.Health==100,'dodging meteor failed')
assert(players[2].Character.Humanoid.Health<100,'meteor failed to damage impact target')
cleanup(); print('PASS meteor warning lets survivors dodge server damage')
reset()
cleanup=definition('falling_bombs').Run(context,players[1])
advance(1)
players[1].Character.HumanoidRootPart.Position=roblox.Vector3.new(0,34,0)
advance(1.4)
assert(players[1].Character.Humanoid.Health==100,'dodging bomb failed')
assert(players[2].Character.Humanoid.Health<100,'bomb missed stationary target')
cleanup(); print('PASS bombs warn before impacting old positions')
reset()
cleanup=definition('vanishing_islands').Run(context,players[1]); advance(4.2)
local vanished=0
for _, platform in ipairs(world.Platforms) do
 if not platform.CanCollide then
  vanished+=1
  for _, part in ipairs(platform.Parent:GetDescendants()) do
   if part:IsA('BasePart') then assert(not part.CanCollide,'vanished island retained cottage collision') end
  end
 end
end
assert(vanished==4,'wrong vanished island count'); cleanup()
for part, properties in pairs(originals) do assert(part.CanCollide==properties.CanCollide,'vanishing did not restore collision') end
print('PASS whole island vanishing restores every cottage and bridge')
reset()
local originalDamage=context.Damage
local activeCleanup
context.Damage=function(player,amount)
 originalDamage(player,amount)
 roundActive=false
 activeCleanup()
end
activeCleanup=definition('meteor_shower').Run(context,players[1]); advance(3)
assert(#world.Effects:GetChildren()==0,'synchronous round end interrupted cleanup')
assert(#errors==0,'synchronous cleanup error: '..table.concat(errors,'; '))
advance(30); assert(#errors==0,'late synchronous cleanup job')
context.Damage=originalDamage
print('PASS round ending inside hazard callback finishes cleanup and cancels jobs')
print('40 event checks passed. Movement, physics, input and multiplayer need Studio playtests.')
