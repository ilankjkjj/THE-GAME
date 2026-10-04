-- Deterministic event gameplay checks. Roblox's native property database checks
-- construction; a virtual clock exercises jobs and cancellation without physics.
-- Real player movement, networking and balance still require Studio playtests.
local Environment = require('../scripts/RobloxEnvironment')
local roblox = require('@lune/roblox')
local env = Environment.new()
local forcedRandomInteger
local originalRandom = env.Env.Random.new
env.Env.Random.new = function()
 local generator = originalRandom()
 local nextInteger = generator.NextInteger
 generator.NextInteger = function(self,low,high)
  if forcedRandomInteger then
   local selected=forcedRandomInteger; forcedRandomInteger=nil
   assert(selected>=low and selected<=high,'invalid deterministic random choice')
   return selected
  end
  return nextInteger(self,low,high)
 end
 return generator
end
env.Env.PhysicalProperties = roblox.PhysicalProperties
env.Env.NumberSequenceKeypoint = roblox.NumberSequenceKeypoint
env.Env.RaycastParams = env.Env.RaycastParams or { new = function() return {} end }
local obstruction
roblox.implementMethod('Workspace','Raycast',function(_,origin,direction)
 if obstruction then return {Instance=obstruction,Position=origin+direction*0.4} end
 return nil
end)
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
local world
local peakParts, cues, stages = 0, {}, {}
local function observe()
 if not world then return end
 local count=0
 for _, instance in ipairs(world.Effects:GetDescendants()) do
  if instance:IsA('BasePart') then
   count+=1
   assert(instance.Name~='EscapeStair' and instance.Name~='EmergencyStair','events must never regenerate stairs')
   if instance.Name=='EscapeCrate' then
    assert(instance.CanCollide and math.abs(instance.Size.Y-3)<0.001,'escape crates must be separated jump platforms')
   end
  end
  if instance:IsA('BillboardGui') then
   assert(instance.MaxDistance>0 and instance.MaxDistance<=65,'event labels visible across arena/lobby')
   assert(instance.Size.X.Scale>0 and instance.Size.Y.Scale>0 and instance.Size.X.Offset==0 and instance.Size.Y.Offset==0,'event label must recede in world space')
   assert(instance.Adornee and (instance.Adornee.Position-world.LobbySpawn).Magnitude>instance.MaxDistance,'event label remains visible from lobby spawn')
  end
 end
 peakParts=math.max(peakParts,count)
 assert(count<=250,'mobile visual part budget exceeded: '..count)
end
local function advance(seconds)
 local untilTime = t + seconds
 local resumes = 0
 while true do
  local selected
  for _, job in ipairs(jobs) do
   if not canceled[job.Thread] and coroutine.status(job.Thread) ~= 'dead' and job.Due <= untilTime and (not selected or job.Due < selected.Due) then selected=job end
  end
  if not selected then break end
  t=selected.Due; resume(selected); observe(); resumes+=1
  assert(resumes<20000, 'unbounded scheduling')
 end
 t=untilTime
end
world = env.load('src/server/World.luau').build()
local events = env.load('src/server/Events.luau')
assert(#events.Definitions == 52)
local eventIds = {}
for _, event in ipairs(events.Definitions) do
 assert(not eventIds[event.Id], 'duplicate event ID'); eventIds[event.Id]=true
 assert(event.Duration>=12 and event.Duration<=30, 'event duration')
 assert(table.find({'Disaster','Challenge','Relief','PvP'},event.Category),'category metadata')
 assert(event.Intensity>=1 and event.Intensity<=3,'intensity metadata')
 assert(table.find({'ArenaHazard','PvP','Relief','Targeted','MapMutation'},event.Channel),'stack channel metadata')
 assert(type(event.ConflictKeys)=='table' and event.VisualBudget>=0 and event.VisualBudget<=220,'stack budget metadata')
 assert(table.find({'eruption','storm','impact','sciFi','warning','chase','relief','gunshot','sword','role','supply'},event.Cue),'cue metadata')
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
 local backpack=roblox.Instance.new('Backpack'); backpack.Parent=player
 player.Character=character
 return player
end
for index=1,3 do table.insert(players, makePlayer(index, world.ArenaSpawns[index])) end
local lobbyPlayer=makePlayer(99, world.LobbySpawn)
local roundActive=true
local attackers={}
local personalHints={}
local context={
 World=world, State={}, Remotes={}, Active=function() return roundActive end,
 Players=function()
  local result={}; for _, player in ipairs(players) do if alive[player] and player.Character.Humanoid.Health>0 then table.insert(result,player) end end; return result
 end,
 IsAlive=function(player) return player and alive[player] == true and player.Character.Humanoid.Health>0 end,
 Award=function(player,coins,points) assert(player~=lobbyPlayer,'lobby reward'); awards[player]=(awards[player] or 0)+coins end,
 Damage=function(player,amount,attacker) assert(player~=lobbyPlayer,'lobby damage'); attackers[player]=attacker; damages[player]=(damages[player] or 0)+amount; player.Character.Humanoid.Health=math.max(0,player.Character.Humanoid.Health-amount) end,
 Eliminate=function(player) assert(player~=lobbyPlayer,'lobby elimination'); alive[player]=false; player.Character.Humanoid.Health=0 end,
 SetRole=function(player,role) assert(player~=lobbyPlayer,'lobby role'); roles[player]=role end,
 PersonalHint=function(player,hint,duration)
  assert(player~=lobbyPlayer and type(hint)=='string' and #hint>0,'personal hint must be private to a survivor')
  assert(duration>0 and duration<=8,'personal duration must stay short')
  personalHints[player]={Hint=hint,Duration=duration}
 end,
 Cue=function(kind,position,strength)
  assert(position.X<180,'cue should never originate inside lobby')
  assert(type(kind)=='string' and strength>0 and strength<=3,'cue payload')
  table.insert(cues,{Time=t,Kind=kind})
 end,
 SetStage=function(stage,hint)
  assert(table.find({'Warning','Active','Finale'},stage),'invalid phase stage')
  assert(type(hint)=='string' and #hint>0,'missing stage instructions')
  table.insert(stages,stage)
 end,
}
local function reset()
 world.resetArena()
 t,jobs,errors,canceled=0,{},{},{}
 roundActive=true; alive,awards,damages,roles={},{},{},{}
 peakParts,cues,stages=0,{},{}
 obstruction=nil; attackers={}; personalHints={}; forcedRandomInteger=nil
 for index,player in ipairs(players) do
  alive[player]=true; player.Character.Humanoid.MaxHealth=100; player.Character.Humanoid.Health=100; player.Character.Humanoid.WalkSpeed=16; player.Character.Humanoid.JumpPower=50; player.Character.Humanoid.JumpHeight=7.2
  player.Character.HumanoidRootPart.Position=world.ArenaSpawns[index]
  player.Character.HumanoidRootPart.AssemblyLinearVelocity=roblox.Vector3.zero
 end
end
for _,definition in ipairs(events.Definitions) do
 reset()
 local cleanup=definition.Run(context,players[1])
 observe()
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
  assert(not player.Character:FindFirstChildOfClass('Tool') and not player.Backpack:FindFirstChildOfClass('Tool'),definition.Id..' weapon leak')
  assert(player.Character.Humanoid.MaxHealth==100,definition.Id..' armor leaked')
 end
 assert(env.Workspace.Gravity==originalGravity,definition.Id..' global gravity change')
 if definition.Persistent then
  assert(world.Houses[1].Model:GetAttribute('MutationCount')==1,definition.Id..' lost permanent house mutation')
  world.resetArena()
 end
 for part, properties in pairs(originals) do
  for property,value in pairs(properties) do assert(part[property]==value,definition.Id..' changed '..part.Name..'.'..property) end
  assert(part.CustomPhysicalProperties==properties.CustomPhysicalProperties,definition.Id..' physical properties leak')
 end
 advance(30)
 assert(#errors==0,definition.Id..' late task error: '..table.concat(errors,'; '))
 for index=2,#cues do assert(cues[index].Time-cues[index-1].Time>=0.219,'unbounded cue spam') end
 print('PASS runtime',definition.Id,'peak',peakParts,'parts')
end
assert(lobbyPlayer.Character.Humanoid.Health==100)
print('All 52 scheduled events fit the mobile budget, cancel, restore, and exclude lobby participants.')



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
reset()
players[1].Character.HumanoidRootPart.Position=roblox.Vector3.new(world.Platforms[1].Position.X-10,42.2,world.Platforms[1].Position.Z)
cleanup=definition('volcanic_eruption').Run(context,players[1]); advance(27)
local highGroundLabels=0
for _, instance in ipairs(world.Effects:GetDescendants()) do
 if instance:IsA('TextLabel') and instance.Text=='JUMP TO SAFETY' then
  highGroundLabels+=1
  assert(instance.Parent.MaxDistance==65,'high ground labels should hide outside local encounter range')
  assert(instance.Parent.Size.X.Scale==8 and math.abs(instance.Parent.Size.Y.Scale-1.8)<0.001,'high ground labels must shrink with distance')
  assert(instance:FindFirstChildOfClass('UITextSizeConstraint').MaxTextSize==22,'nearby labels need a readable size cap')
 end
end
assert(highGroundLabels==12,'high ground label regression did not inspect every island')
assert(players[1].Character.Humanoid.Health==100,'top jump crate did not protect from magma/bomb blast')
assert(players[2].Character.Humanoid.Health<100,'volcano failed to threaten low ground')
assert(table.find(stages,'Warning') and table.find(stages,'Active') and table.find(stages,'Finale'),'volcano stages missing')
cleanup(); print('PASS volcano jump crates counter lava without stairs')
reset()
cleanup=definition('ufo_invasion').Run(context,players[1]); advance(4.2)
local locked=players[1].Character.HumanoidRootPart.Position
players[1].Character.HumanoidRootPart.Position=roblox.Vector3.new(0,34,0)
players[2].Character.HumanoidRootPart.Position=locked+roblox.Vector3.new(2,0,0)
advance(2.5)
assert(players[1].Character.Humanoid.Health==100,'UFO targeted new position without warning')
assert(players[2].Character.Humanoid.Health<100 and players[2].Character.HumanoidRootPart.AssemblyLinearVelocity.Y>20,'tractor beam failed capture/lift')
cleanup(); print('PASS UFO locks old ground position and beam can be escaped')
reset()
players[1].Character.HumanoidRootPart.Position=world.ArenaSpawns[2]
players[2].Character.HumanoidRootPart.Position=roblox.Vector3.new(0,34,0)
cleanup=definition('kraken_attack').Run(context,players[1]); advance(6)
assert(players[1].Character.Humanoid.Health==100,'kraken hit before telegraph finished')
advance(0.7)
assert(players[1].Character.Humanoid.Health<100,'kraken missed marked island')
assert(players[2].Character.Humanoid.Health==100,'kraken struck unmarked escape route')
cleanup(); print('PASS kraken telegraphed island slams reward evacuation')
reset()
players[1].Character.HumanoidRootPart.Position=world.Platforms[2].Position+roblox.Vector3.new(0,4,-5)
players[2].Character.HumanoidRootPart.Position=world.ArenaSpawns[1]
cleanup=definition('blizzard').Run(context,players[1]); advance(9.8)
assert(players[1].Character.Humanoid.Health==100 and players[1].Character.HumanoidRootPart.AssemblyLinearVelocity==roblox.Vector3.zero,'warm shelter failed to block frost/gusts')
assert(players[2].Character.Humanoid.Health<100 and players[2].Character.HumanoidRootPart.AssemblyLinearVelocity.Magnitude>0,'blizzard failed to threaten exposed survivors')
cleanup(); print('PASS orange warmth blocks frost and wind; exposed players feel both')
reset()
cleanup=definition('meteor_apocalypse').Run(context,players[1]); advance(7)
assert(world.Platforms[2].CanCollide,'apocalypse island crumbled before warning/impact')
advance(2.5)
assert(not world.Platforms[2].CanCollide,'apocalypse failed to crumble impacted island')
assert(world.Platforms[1].CanCollide,'apocalypse crumbled unmarked island')
advance(13.6)
assert(table.find(stages,'Finale'),'apocalypse shockwave finale missing')
cleanup()
for part, properties in pairs(originals) do assert(part.CanCollide==properties.CanCollide,'apocalypse left missing ground') end
print('PASS apocalypse warning precedes island collapse and entire map restores')
reset()
players[1].Character.HumanoidRootPart.Position=roblox.Vector3.new(world.Platforms[1].Position.X-10,42.2,world.Platforms[1].Position.Z)
players[2].Character.HumanoidRootPart.Position=roblox.Vector3.new(39,43,0)
cleanup=definition('flash_flood').Run(context,players[1]); advance(23)
assert(players[1].Character.Humanoid.Health==100,'jump crate failed high-water counter')
assert(players[2].Character.Humanoid.Health==100,'above-water raft height should be safe')
assert(players[3].Character.Humanoid.Health<100,'flood left submerged survivor unharmed')
assert(table.find(stages,'Finale'),'flood current finale missing')
cleanup(); print('PASS flood jump crates and raft heights stay above rising water')
reset()
players[1].Character.HumanoidRootPart.Position=world.Platforms[1].Position+roblox.Vector3.new(0,4,-6)
players[2].Character.HumanoidRootPart.Position=roblox.Vector3.new(20,34,0)
cleanup=definition('singularity').Run(context,players[1]); advance(7)
assert(players[1].Character.HumanoidRootPart.AssemblyLinearVelocity==roblox.Vector3.zero,'anchor failed gravity protection')
assert(players[2].Character.HumanoidRootPart.AssemblyLinearVelocity.Magnitude>0,'singularity failed exposed pull')
advance(11)
assert(table.find(stages,'Finale'),'singularity debris phase missing')
cleanup(); print('PASS green anchors resist the singularity and debris appears in finale')
local function face(player, position, target)
 player.Character.HumanoidRootPart.Position=position
 local direction=target-position
 -- Use the avatar's horizontal yaw, avoiding Lune's lookAt handedness.
 player.Character.HumanoidRootPart.CFrame=roblox.CFrame.new(position)*roblox.CFrame.Angles(0,math.atan2(-direction.X,-direction.Z),0)
end
local function equipped(player,name)
 local tool=player.Backpack:FindFirstChild(name)
 assert(tool and tool:IsA('Tool'),'missing battle gear '..name)
 tool.Parent=player.Character
 return tool
end
reset()
face(players[1],roblox.Vector3.new(0,34,0),roblox.Vector3.new(0,34,-20))
face(players[2],roblox.Vector3.new(0,34,-20),roblox.Vector3.new(0,34,0))
cleanup=definition('blaster_brawl').Run(context,players[1])
local blaster=players[1].Backpack:FindFirstChild('Chaos Blaster')
blaster.Activated:Fire(); assert(players[2].Character.Humanoid.Health==100,'unequipped gun fired')
blaster=equipped(players[1],'Chaos Blaster')
blaster.Activated:Fire(); assert(players[2].Character.Humanoid.Health==100,'gun ignored three-second grace')
advance(3.2); blaster.Activated:Fire()
assert(players[2].Character.Humanoid.Health==75 and attackers[players[2]]==players[1],'valid server gun shot/attacker credit failed: HP='..players[2].Character.Humanoid.Health..' damage='..tostring(damages[players[2]])..' facing='..tostring(players[1].Character.HumanoidRootPart.CFrame.LookVector)..' callbacks='..#blaster.Activated.Callbacks..' time='..t)
for _=1,10 do blaster.Activated:Fire() end
assert(players[2].Character.Humanoid.Health==75,'blaster spam bypassed cooldown')
cleanup(); print('PASS equipped gun grace, server damage attribution and spam cooldown')
reset()
face(players[1],roblox.Vector3.new(0,34,0),roblox.Vector3.new(0,34,-20))
face(players[2],roblox.Vector3.new(0,34,-20),roblox.Vector3.new(0,34,0))
cleanup=definition('blaster_brawl').Run(context,players[1]); blaster=equipped(players[1],'Chaos Blaster'); advance(3.2)
obstruction=world.Floor; blaster.Activated:Fire()
assert(players[2].Character.Humanoid.Health==100,'gun fired through house/blocker')
obstruction=nil; advance(0.8)
face(players[1],roblox.Vector3.new(0,34,0),roblox.Vector3.new(0,34,20)); blaster.Activated:Fire()
assert(players[2].Character.Humanoid.Health==100,'gun hit behind shooter')
advance(0.8); face(players[1],roblox.Vector3.new(0,34,0),roblox.Vector3.new(0,34,-20))
face(players[2],roblox.Vector3.new(0,34,-95),roblox.Vector3.new(0,34,0)); blaster.Activated:Fire()
assert(players[2].Character.Humanoid.Health==100,'gun exceeded server range')
cleanup(); print('PASS blasters validate facing, maximum range and blocked line of sight')
reset()
face(players[1],roblox.Vector3.new(0,34,0),roblox.Vector3.new(0,34,-5))
face(players[2],roblox.Vector3.new(0,34,-5),roblox.Vector3.new(0,34,0))
cleanup=definition('free_swords').Run(context,players[1]); local sword=equipped(players[1],'Chaos Sword'); advance(3.2)
obstruction=world.Floor; sword.Activated:Fire()
assert(players[2].Character.Humanoid.Health==100,'blade hit through a wall')
obstruction=nil; advance(0.8); sword.Activated:Fire()
assert(players[2].Character.Humanoid.Health==68 and attackers[players[2]]==players[1],'valid close blade failed')
advance(0.8); face(players[2],roblox.Vector3.new(0,34,-9),roblox.Vector3.new(0,34,0)); sword.Activated:Fire()
assert(players[2].Character.Humanoid.Health==68,'blade hit beyond melee range')
cleanup(); print('PASS swords validate close-range cone and refuse wall penetration')
reset()
face(players[1],roblox.Vector3.new(0,34,0),roblox.Vector3.new(0,34,-20))
face(players[2],roblox.Vector3.new(0,34,-20),roblox.Vector3.new(0,34,0))
cleanup=definition('blaster_brawl').Run(context,players[1]); blaster=equipped(players[1],'Chaos Blaster'); advance(3.2)
blaster.Parent=players[3].Character; blaster.Activated:Fire()
assert(players[2].Character.Humanoid.Health==100,'stolen tool bypassed owner identity')
blaster.Parent=players[1].Character
local activation=blaster.Activated
cleanup(); activation:Fire(); advance(2)
assert(players[2].Character.Humanoid.Health==100 and #activation.Callbacks==0,'expired weapon still fired or kept a connection')
assert(not blaster.Parent,'expired weapon survived cleanup')
print('PASS tool owner identity, activation disconnection and expired weapon cleanup')
reset()
cleanup=definition('blaster_brawl').Run(context,players[1]); blaster=players[1].Backpack:FindFirstChild('Chaos Blaster')
alive[players[1]]=false; advance(0.2)
assert(not blaster.Parent,'departed survivor retained round weapon')
assert(not lobbyPlayer.Backpack:FindFirstChildOfClass('Tool'),'lobby player received round weapon')
cleanup(); print('PASS player leaving the round releases their equipment and lobby gets no gear')
reset()
face(players[1],roblox.Vector3.new(0,34,0),roblox.Vector3.new(0,34,-5))
face(players[2],roblox.Vector3.new(0,34,-20),roblox.Vector3.new(0,34,0))
face(players[3],roblox.Vector3.new(0,34,-4),roblox.Vector3.new(0,34,0))
cleanup=definition('sword_duel').Run(context,players[1]); sword=equipped(players[1],'Duel Sword'); advance(3.2); sword.Activated:Fire()
assert(players[3].Character.Humanoid.Health==100,'duelist damaged uninvolved bystander')
advance(0.8); face(players[2],roblox.Vector3.new(0,34,-5),roblox.Vector3.new(0,34,0)); sword.Activated:Fire()
assert(players[2].Character.Humanoid.Health==62,'duelist could not damage rival')
cleanup(); print('PASS duel weapons restrict damage to the selected rival')
reset()
cleanup=definition('murder_mystery').Run(context,players[1]); advance(3.2)
local murderer,sheriff,innocent
for _,player in ipairs(players) do
 if roles[player]=='Murderer' then murderer=player elseif roles[player]=='Sheriff' then sheriff=player else innocent=player end
end
assert(murderer and sheriff and innocent,'three mystery roles missing')
assert(not world.Effects:FindFirstChildOfClass('Highlight'),'secret mystery roles advertised with highlights')
face(sheriff,roblox.Vector3.new(0,34,0),roblox.Vector3.new(0,34,-15))
face(murderer,roblox.Vector3.new(30,34,0),roblox.Vector3.new(0,34,0))
face(innocent,roblox.Vector3.new(0,34,-15),roblox.Vector3.new(0,34,0))
local sheriffGun=equipped(sheriff,'Sheriff Blaster'); sheriffGun.Activated:Fire()
assert(innocent.Character.Humanoid.Health==100,'sheriff shot innocent instead of murderer')
advance(1.5); face(murderer,roblox.Vector3.new(0,34,-15),roblox.Vector3.new(0,34,0)); sheriffGun.Activated:Fire()
assert(murderer.Character.Humanoid.Health==0 and attackers[murderer]==sheriff,'sheriff failed valid murderer knockout')
advance(0.2); assert(not sheriffGun.Parent,'resolved mystery retained gun')
cleanup(); print('PASS private mystery roles, innocent protection and sheriff knockout')
reset()
cleanup=definition('battle_kit').Run(context,players[1])
assert(players[1].Character.Humanoid.MaxHealth==140 and players[1].Character.Humanoid.Health==140,'gifted battle armor missing')
assert(#players[1].Backpack:GetChildren()==2,'gifted arsenal requires usable gun and knife')
assert(#players[2].Backpack:GetChildren()==0 and #players[3].Backpack:GetChildren()==0,'gift should choose one survivor')
cleanup()
assert(players[1].Character.Humanoid.MaxHealth==100 and players[1].Character.Humanoid.Health<=100,'temporary battle armor leaked')
print('PASS random battle kit grants two weapons and restores temporary armor')

local Director=env.load('src/shared/DisasterDirector.luau')
assert(not Director.compatible(definition('blaster_brawl'),{definition('murder_mystery')}),'weapons/roles may not overlap')
assert(not Director.compatible(definition('flash_flood'),{definition('volcanic_eruption')}),'incompatible water levels may not overlap')
assert(not Director.compatible(definition('meteor_shower'),{{Definition=definition('meteor_shower')}}),'same hazard selected twice')
assert(Director.compatible(definition('meteor_shower'),{definition('free_swords'),definition('heavy_feet')}),'independent hazards were needlessly excluded')
assert(not Director.compatible(definition('acid_rain'),{definition('volcanic_eruption'),definition('shockwaves'),definition('blaster_brawl')}),'stack visual budget exceeded')
for _=1,20 do
 local selected=events.choose(3,nil,4,{{Id='house_paint',Category='Challenge'}},{definition('volcanic_eruption'),definition('murder_mystery')})
 assert(selected and Director.compatible(selected,{definition('volcanic_eruption'),definition('murder_mystery')}),'selection ignores active scopes')
end
print('PASS stack director rejects duplicate IDs, conflicting channels and excessive combined visuals')

reset()
local lower=definition('slippery_islands').Run(context,players[1])
local upper=definition('blizzard').Run(context,players[1])
assert(world.Platforms[1].Material==roblox.Enum.Material.Snow,'upper surface lease did not apply')
lower()
assert(world.Platforms[1].Material==roblox.Enum.Material.Snow,'older event erased newer snow')
upper()
assert(world.Platforms[1].Material==originals[world.Platforms[1]].Material,'last surface lease did not restore original')
reset()
lower=definition('slippery_islands').Run(context,players[1]); upper=definition('blizzard').Run(context,players[1]); upper()
assert(world.Platforms[1].Material==roblox.Enum.Material.Ice,'newer scope did not restore still-active ice')
lower(); assert(world.Platforms[1].Material==originals[world.Platforms[1]].Material,'surface stack left a stale original')
print('PASS property leases clean in either order without erasing another active event')

reset()
local roleCleanup=definition('cops_robbers').Run(context,players[1])
local newerRoles=definition('free_swords').Run(context,players[1])
roleCleanup()
assert(roles[players[1]]=='Swordfighter','older role cleanup cleared a newer role')
newerRoles(); assert(roles[players[1]]==nil,'last role scope leaked')
reset()
local firstHint=definition('rocket_boots').Run(context,players[1])
local secondHint=definition('heavy_feet').Run(context,players[1])
local bootsHint='ROCKET BOOTS: Your jumps are much stronger. Aim for solid ground!'
secondHint(); assert(players[1]:GetAttribute('EventHint')==bootsHint,'private hint failed to restore still-active instructions')
firstHint(); assert(players[1]:GetAttribute('EventHint')==nil,'private hint lease leaked')
print('PASS role and hint ownership preserve other active scope instructions')

for index=1,8 do
 reset(); players[1].Character.Humanoid.Health=60; forcedRandomInteger=index
 local personal,duration,text=events.runPersonal(context,players[1])
 assert(type(personal)=='function' and duration>=2 and duration<=8 and #text>0,'personal runner contract')
 assert(personalHints[players[1]] and personalHints[players[2]]==nil,'personal consequence leaked to another player')
 local humanoid=players[1].Character.Humanoid
 if index==1 then assert(awards[players[1]]==8,'personal token bonus failed')
 elseif index==2 then assert(humanoid.Health==80,'personal healing failed')
 elseif index==3 then assert(humanoid.WalkSpeed==23,'personal speed failed')
 elseif index==4 then assert(humanoid.JumpPower==68 and humanoid.JumpHeight>10,'personal jump failed')
 elseif index==5 then
  assert(players[1].Character:FindFirstChild('EventPersonalShield'),'personal protection failed')
  humanoid:TakeDamage(25); assert(humanoid.Health==60,'personal forcefield did not protect health')
 elseif index==6 then assert(humanoid.WalkSpeed==11,'personal slow failed')
 elseif index==7 then assert(humanoid.Health==52,'personal sting failed')
 elseif index==8 then assert(world.Effects:FindFirstChild('PersonalMark',true),'personal mark failed') end
 personal(); personal(); advance(duration+1)
 assert(humanoid.WalkSpeed==16 and humanoid.JumpPower==50,'personal movement cleanup failed')
 assert(not players[1].Character:FindFirstChild('EventPersonalShield') and #world.Effects:GetChildren()==0,'personal resource leak')
end
assert(select(2,events.runPersonal(context,lobbyPlayer))==0,'lobby press got a personal consequence')
print('PASS all eight personal consequences, private hints, cleanup and lobby rejection')

reset()
local speed=definition('speed_frenzy').Run(context,players[1]); forcedRandomInteger=3
local personal=events.runPersonal(context,players[1])
assert(players[1].Character.Humanoid.WalkSpeed==36,'personal boost did not stack over major speed')
speed(); assert(players[1].Character.Humanoid.WalkSpeed==36,'major cleanup erased active personal boost')
personal(); assert(players[1].Character.Humanoid.WalkSpeed==16,'personal restored an expired major boost')
reset()
speed=definition('speed_frenzy').Run(context,players[1]); forcedRandomInteger=3; personal=events.runPersonal(context,players[1])
personal(); assert(players[1].Character.Humanoid.WalkSpeed==29,'personal cleanup erased active major boost')
speed(); assert(players[1].Character.Humanoid.WalkSpeed==16,'major speed leaked after personal cleanup')
print('PASS personal and major movement leases expire safely in either order')

reset()
local themeCalls=0; local originalTheme=world.theme
world.theme=function() themeCalls+=1 end
local storm=definition('blizzard').Run(context,players[1]); storm()
assert(themeCalls==0,'event scope owns global world lighting')
world.theme=originalTheme
print('PASS event scopes leave global lighting to the active-event manager')

for _,kind in ipairs({'lift','relocate','shrink','tilt','paint'}) do
 reset()
 local house=world.Houses[1]
 local original={}
 for _,part in ipairs(house.Model:GetDescendants()) do if part:IsA('BasePart') then original[part]={CFrame=part.CFrame,Size=part.Size,Color=part.Color} end end
 local houseCleanup=definition('house_'..kind).Run(context,players[1])
 advance(2.4); assert(house.Model:GetAttribute('MutationCount')==0,'house transformation ignored warning')
 advance(0.2); assert(house.Model:GetAttribute('MutationCount')==1,'warned house did not transform')
 local changed=false
 for part,properties in pairs(original) do if part.CFrame~=properties.CFrame or part.Size~=properties.Size or part.Color~=properties.Color then changed=true end end
 assert(changed,'house mutation had no visible effect')
 houseCleanup(); assert(house.Model:GetAttribute('MutationCount')==1,'house change disappeared at event expiry')
 local vanish=definition('vanishing_islands').Run(context,players[1]); advance(4.2); vanish()
 for part,properties in pairs(world.RoundOriginals) do
  if part:IsDescendantOf(house.Model) then assert(part.CFrame==properties.CFrame and part.Size==properties.Size and part.Color==properties.Color,'transient cleanup erased house mutation') end
 end
 world.resetArena()
 for part,properties in pairs(original) do assert(part.CFrame==properties.CFrame and part.Size==properties.Size and part.Color==properties.Color,'round reset kept house mutation') end
end
print('PASS all five house transformations warn, stay for the round, survive temporary hazards and reset at round end')

reset()
cleanup=definition('iron_survivor').Run(context,players[1])
assert(players[1].Character.Humanoid.MaxHealth==160 and players[1].Character.Humanoid.Health==160,'iron armor not granted')
assert(players[2].Character.Humanoid.MaxHealth==100,'random armor granted to everyone')
cleanup(); assert(players[1].Character.Humanoid.MaxHealth==100 and players[1].Character.Humanoid.Health==100,'iron armor did not restore')
print('PASS targeted iron armor changes health capacity and restores safely')
reset()
cleanup=definition('rocket_boots').Run(context,players[1])
assert(players[1].Character.Humanoid.JumpPower==76 and players[1].Character.Humanoid.JumpHeight==13 and players[1].Character.Humanoid.WalkSpeed==23,'rocket boots do not enhance movement')
alive[players[1]]=false; advance(0.2)
assert(players[1].Character.Humanoid.JumpPower==50 and players[1].Character.Humanoid.WalkSpeed==16,'rocket boots entered lobby')
cleanup(); print('PASS targeted rocket boots release immediately when player leaves the arena')
reset()
cleanup=definition('heavy_feet').Run(context,players[1]); advance(2.9)
assert(players[1].Character.Humanoid.WalkSpeed==16,'handicap ignored preparation time')
advance(0.2); assert(players[1].Character.Humanoid.WalkSpeed==9,'handicap failed to activate')
advance(14.1); assert(awards[players[1]]==15,'surviving handicap was not rewarded')
cleanup(); assert(players[1].Character.Humanoid.WalkSpeed==16,'handicap leaked')
print('PASS concrete shoes give preparation time and reward surviving the handicap')
reset()
players[1].Character.HumanoidRootPart.Position=roblox.Vector3.new(0,34,0)
cleanup=definition('hunter_drone').Run(context,players[1]); advance(3.2)
assert(world.Effects:FindFirstChild('Incomingbomb',true),'hunter drone failed to telegraph its target')
players[1].Character.HumanoidRootPart.Position=roblox.Vector3.new(10,34,0)
advance(2.3); assert(players[1].Character.Humanoid.Health==100,'drone hit survivor after successful dodge')
advance(3.8); assert(players[1].Character.Humanoid.Health<100,'drone did not punish standing in next target')
cleanup(); print('PASS personal hunter drone locks old positions and rewards movement')
reset()
face(players[1],roblox.Vector3.new(0,34,0),roblox.Vector3.new(0,34,-15))
face(players[2],roblox.Vector3.new(0,34,-15),roblox.Vector3.new(0,34,0))
cleanup=definition('gifted_railgun').Run(context,players[1]); local railgun=equipped(players[1],'Gifted Rail Blaster'); advance(3.2)
railgun.Activated:Fire(); assert(players[2].Character.Humanoid.Health==30 and attackers[players[2]]==players[1],'railgun must be usable server-authoritative gear')
assert(not players[2].Backpack:FindFirstChildOfClass('Tool'),'railgun gift went to multiple survivors')
cleanup(); print('PASS targeted railgun grants usable high-damage gear with attribution')
reset()
players[1].Character.HumanoidRootPart.Position=roblox.Vector3.new(0,34,0)
cleanup=definition('jackpot_runner').Run(context,players[1])
players[1].Character.HumanoidRootPart.Position=roblox.Vector3.new(6,34,0); advance(3.2)
players[1].Character.HumanoidRootPart.Position=roblox.Vector3.new(12,34,0); advance(1.1)
assert(awards[players[1]]==6,'jackpot did not reward movement')
advance(3.2); assert(players[1].Character.Humanoid.Health<100,'jackpot did not punish camping')
cleanup(); print('PASS jackpot rewards distance traveled and punishes standing still')

reset()
local eruption=definition('volcanic_eruption').Run(context,players[1])
local rings=definition('shockwaves').Run(context,players[1])
local gear=definition('blaster_brawl').Run(context,players[1])
advance(13); observe()
eruption(); local survivingParts=#world.Effects:GetDescendants(); assert(survivingParts>0,'one cleanup destroyed other hazard scopes')
advance(1); gear(); rings()
assert(#world.Effects:GetChildren()==0 and #errors==0,'stacked hazards leaked or raised a late error')
print('PASS simultaneous eruption, shockwaves and PvP stay bounded and clean independently')
reset()
players[1]:SetAttribute('HouseIndex',7)
local assignedHouse=definition('house_lift').Run(context,players[1])
assert(stages[1]=='Warning','house warning was overwritten with Active immediately')
advance(2.6)
assert(world.Houses[7].Model:GetAttribute('MutationCount')==1 and world.Houses[1].Model:GetAttribute('MutationCount')==0,'mutation targeted vacant house instead of live assigned house')
assignedHouse(); players[1]:SetAttribute('HouseIndex',nil)
print('PASS house mutations target an actual survivor\'s assigned house and preserve the warning phase')
reset()
players[1].Character.HumanoidRootPart.Position=roblox.Vector3.new(0,34,0)
players[2].Character.HumanoidRootPart.Position=roblox.Vector3.new(10,34,0)
players[3].Character.HumanoidRootPart.Position=roblox.Vector3.new(25,34,0)
lobbyPlayer.Character.HumanoidRootPart.Position=roblox.Vector3.new(0,34,0)
local overloadCleanup=events.Overload.Run(context,players[1])
assert(events.Overload.Instant and events.Overload.Duration==0.5 and not eventIds.button_overload,'overload entered normal random selection')
assert(players[1].Character.Humanoid.Health==86 and players[2].Character.Humanoid.Health==90 and players[3].Character.Humanoid.Health==100,'overload damages wrong participants/range')
assert(lobbyPlayer.Character.Humanoid.Health==100 and #jobs==0 and #world.Effects:GetChildren()==0,'overload affects lobby or starts delayed work')
overloadCleanup(); advance(10)
assert(players[1].Character.Humanoid.Health==86,'overload has lingering damage')
lobbyPlayer.Character.HumanoidRootPart.Position=world.LobbySpawn
print('PASS instantaneous button overload damages nearby survivors once, excludes lobby and schedules no work')
print('94 event checks passed. Movement, physics, input and multiplayer need Studio playtests.')
