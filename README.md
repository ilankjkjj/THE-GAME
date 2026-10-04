# DON'T PRESS THE BUTTON

A Roblox survival party game: twelve full-size walk-in houses, studded islands, one giant red button, and a new hazard whenever someone presses it. Survive longer than everyone else to win. A separate sunny lobby lets players queue, spectate, shop, or practice a checkpoint obby for tokens between rounds.

Made for **Argon 2**, with plain Luau, Roblox's bundled assets, and no external game packages or paid models.

## Play in Roblox Studio

1. Install [Rokit](https://github.com/rojo-rbx/rokit) if you do not already have Argon. In this folder, run `rokit install` to install the versions pinned in `rokit.toml`.
2. Run `powershell -ExecutionPolicy Bypass -File scripts/build.ps1`.
3. Open `build/DontPressTheButton.rbxl` in Roblox Studio. The complete floating arena and lobby are visible in the editor.
4. Press **Play**. Players join the next-round queue automatically. Use **JOIN NEXT ROUND** to rejoin the queue, or **QUEUED Â· LEAVE** to take a break. The lobby portal also has a join prompt.
5. After the lobby countdown, players appear on their islands. Reach the central button and press **E**, controller **X**, tap its prompt, click the physical button, or use the on-screen press action.

The simpler `argon build default.project.json -o build/Game.rbxl` also works. That place generates the full arena and lobby when Play starts. Use the full build above for a map visible in the editor.

## Connect Argon

The project maps `src/shared` to `ReplicatedStorage.Shared`, `src/server` to `ServerScriptService.Server`, and `src/client` to `StarterPlayer.StarterPlayerScripts.Client`.

1. Install the official [Argon Studio plugin](https://argon.wiki/docs/installation), or run `argon plugin install` once.
2. From this folder, run `powershell -ExecutionPolicy Bypass -File scripts/serve.ps1` (or `argon serve default.project.json --sourcemap`).
3. Open the built place. In Studio's Argon plugin, connect to **127.0.0.1:8000** and sync this project.
4. Keep the server running while editing source. Stop and restart Play to pick up module changes safely.

The project and VS Code recommendations are included. `sourcemap.json` is generated locally. `World.luau` constructs the arena, cottages, lobby, boards, and lighting; runtime construction replaces the preview map. Unknown Workspace instances are preserved during sync. See the [Argon project format](https://argon.wiki/api/project).

## Button-controlled rounds

- A 15-second intermission boards up to 12 queued players. Late arrivals remain in the protected lobby.
- Rounds last 150 seconds. **Only a living, nearby player's button press starts an event.** Nothing auto-starts during idle time; there is no automatic overtime storm or special-press countdown.
- Events run one at a time. After cleanup, the button becomes available in two seconds. Disasters get more dangerous as round threat increases; the event selector avoids the previous four events and gives PvP a strong chance in multiplayer.
- Death, falling, resetting, or leaving the queue ends that player's round life. The last survivor wins. Multiple survivors at the time limit draw.
- Results show the winner, placements, knockouts and each player's tokens earned during the round. The server returns everyone to the lobby; **RETURN TO LOBBY** dismisses the results screen.
- An idle round with no button press ends as **NO CONTEST**, with no win or survival bonus. Solo practice rewards require at least one event and never count as competitive wins.

## Events and PvP

The bank contains **41 events**, including five equipment-based PvP events:

| Event | Play |
| --- | --- |
| One Knife. One Sheriff. | A random murderer receives a knife, a sheriff gets a blaster, and innocents hide or flee. Roles and personal instructions are sent only to their owner. The sheriff can damage only the murderer. Requires three players. |
| A Duel of Bad Decisions | Two survivors receive swords; only their selected rival can be hit. |
| Everyone Brought a Sword | Every survivor receives a sword. No teams. |
| One Lucky Arsenal | A random survivor gets a blaster, knife and temporary extra health. Houses provide cover for everyone else. |
| Free Blasters. Bad Idea. | Every survivor receives a blaster. Use walls for cover. |

Select a weapon in the Roblox backpack, **face an opponent and click or tap**. Guns aim in the character's facing direction. Server checks validate equipment, ownership, original avatar, alive status, cooldown, range, facing and line of sight. Weapons have a three-second grace period, cannot be dropped, never target lobby visitors, and disappear when their event ends or their owner leaves the round.

Major disasters include a volcano with arcing lava bombs and rising magma; an invading UFO with tractor beams and laser salvos; a kraken with telegraphed island slams; a blizzard with heat shelters; an asteroid that destroys marked islands; a flash flood with drifting rafts; and a singularity with green anchors and orbital debris. Green jump crates provide demanding high-ground routes during lava and flood events, without roof stairs.

The rest of the bank includes cops and robbers, rising lava, lasers, meteors, giant chicken and zombie chases, hot potato, musical and vanishing islands, shrinking islands, acid rain, tidal waves, shockwaves, slippery platforms, moon gravity, speed boosts, lightning, a spinner, trap tokens, red-light/green-light, falling bombs, supply drops, earthquakes, tornadoes, a cursed crown, freeze tag, trampolines, bridge roulette and a laser grid.

All event damage, pickups and PvP rewards are limited to current round participants. Event jobs, tools, effects, roles and temporary island changes are scoped and cleaned up on expiry or round end.

## Classic map, lobby and controls

The map uses a classic Roblox style: native studded plastic surfaces, simple brick chimneys, bright flat daylight and rectangular SourceSans UI. These are Roblox's built-in surfaces and materials, rather than an externally downloaded historical texture pack. There is no bloom, neon scenery or heavy normal-day color grading. Disasters temporarily change the atmosphere, then restore normal daylight.

Each 26-stud island holds a walk-in house with a 5.6-by-8 doorway, a 13.4-by-13.4 interior and 9.8 studs of headroom. Furniture stays against the walls, leaving the middle open for hiding and chases. There are no permanent roof stairs or roof decks. Lobby spawn pads remain invisible beneath the floor.

The lobby includes a real ten-checkpoint obby. Reach its numbered pads in order and finish to earn **20 tokens**; the reward refreshes after **60 seconds**. The server checks character identity, position, checkpoint order and course timing. Joining a round or respawning resets the run. Missed jumps land on the lobby floor.

Persistent HUD controls sit at the edges. **SHOP / B**, **RANKS / L**, and **PLAYERS / P** open menus; **Q** toggles queue while in the lobby. **WATCH / V** begins or ends spectating. The spectator bar has **previous / next / stop** controls; **[ / ]** cycle players. Spectating switches away from a dead target and restores your camera when you rejoin a round.

## Tokens and usable supplies

The old skins, trails, pets, titles, emotes, coin multipliers and Button Points shop have been removed. The only spendable currency is **Tokens**. Presses remain a lifetime statistic and give no tokens by themselves.

- Competitive win: **60 tokens and one win**.
- Solo survival with at least one event: **20 tokens**, without a competitive win.
- Survive a complete event: **6 tokens**, plus pickups or event-specific rewards.
- PvP knockout: **5 tokens**, credited once to the attacker.
- Lobby obby completion: **20 tokens**, with a 60-second reward cooldown.

Buy supplies in the lobby. You receive one tool for each stocked type at the start of a round; only activating a supply spends a unit. Unused stock stays saved. Each type holds at most five units.

| Supply | Price | Use |
| --- | ---: | --- |
| Medkit | 30 tokens | Heal 35 HP. Using it at full health keeps it stocked. |
| Bloxy Soda | 20 tokens | +6 movement speed for eight seconds. |
| Jump Spring | 25 tokens | +15 jump power for eight seconds. |
| Shield Capsule | 45 tokens | Block damage for five seconds. Falling still eliminates you. |

Supplies require the owner's equipped tool and original living round avatar. Tools and temporary buffs clear on death or round end. Movement supplies retain their remaining duration across event transitions.

## Audio

The game immediately uses Roblox's bundled sounds for presses, warnings, disaster impacts, PvP weapons, role changes, supplies, checkpoint progress, purchases, knockouts and wins. An **SFX mute** button stops local audio. Small nearby camera accents are bounded and cleaned up safely.

`assets/audio/` contains **17 original synthesized WAV effects** with no external samples or subscription requirement. They are optional replacements and **have not been uploaded to Roblox**. Import them, grant the experience permission and put their uploaded IDs in `AudioCatalog.luau`. See [the audio pack instructions](assets/audio/README.md) and [Roblox's audio asset guide](https://create.roblox.com/docs/audio/assets). `python scripts/generate_audio.py` regenerates the deterministic source pack.

## Saved progress and publishing

Published servers save Tokens, inventory, wins, knockouts, presses and completed rounds every 45 seconds and when players leave. Session leases prevent concurrent writes. Existing version-one/two coin and point balances migrate once into Tokens; lifetime wins and presses are retained, while retired cosmetic ownership is removed. The existing profile store and global wins ranking remain in use.

Studio defaults to disposable session progress. For save testing, use a separate published test experience, enable Studio API access and set `PersistenceInStudio = true`. See [Roblox's DataStore guide](https://create.roblox.com/docs/cloud-services/data-stores). Publish the built place through Studio when ready; pushing Git source does not publish the Roblox experience.

## Source and verification

`src/shared/` contains tuning, profiles, token economy and supply catalog; `src/server/` contains rounds, events, saves, world construction, supplies and the lobby obby; `src/client/` contains UI, spectating and audio feedback. Generated `build/` places and sourcemaps stay ignored.

Run `powershell -ExecutionPolicy Bypass -File scripts/test.ps1`. Four suites check production Luau compilation, native Roblox properties, economy migration and saving, button-only rounds, event cancellation, all 41 events, PvP validation, owner-only mystery state, responsive UI, results, spectating, supplies and obby rewards. GitHub Actions repeats the checks and uploads the complete built Studio place.

For a specific event preview during a Studio round, switch to **Server** and run `game.ServerScriptService.Server.StudioDisasterPreview:Fire("blaster_brawl")` in the Luau command bar using **Run / Ctrl+Enter**. Previews are restricted to Studio and still enforce each event's minimum players. Other IDs include `murder_mystery`, `free_swords`, `battle_kit`, `volcanic_eruption`, `ufo_invasion`, `kraken_attack`, `blizzard`, `meteor_apocalypse`, `flash_flood`, and `singularity`.

Use Studio's **Server & Clients** with two players (three for murder mystery) to verify actual equipping, facing, weapon input, house collision, jumping, spectating and round results. Offline checks validate logic and Roblox properties, and do not replace native multiplayer or published DataStore testing.
