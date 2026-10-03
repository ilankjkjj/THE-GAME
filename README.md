# DON'T PRESS THE BUTTON

A Roblox survival party game: twelve colorful floating cottages, narrow bridges, one giant red button, and a new hazard whenever someone presses it. Survive longer than everyone else to win. A separate sunny lobby lets players queue, spectate, shop, or practice a safe hopping course between rounds.

Made for **Argon 2**, with plain Luau, Roblox's bundled assets, and no external game packages or paid models.

## Play in Roblox Studio

1. Install [Rokit](https://github.com/rojo-rbx/rokit) if you do not already have Argon. In this folder, run `rokit install` to install the versions pinned in `rokit.toml`.
2. Run `powershell -ExecutionPolicy Bypass -File scripts/build.ps1`.
3. Open `build/DontPressTheButton.rbxl` in Roblox Studio. The complete floating arena and lobby are visible in the editor.
4. Press **Play**. Players join the next-round queue automatically. Use **JOIN NEXT ROUND** to rejoin the queue, or **QUEUED · LEAVE** to take a break. The lobby portal also has a join prompt.
5. After the lobby countdown, players appear on their islands. Reach the central button and press **E**, controller **X**, tap its prompt, click the physical button, or use the on-screen press action.

The simpler `argon build default.project.json -o build/Game.rbxl` also works. That place generates the full arena and lobby when Play starts. Use the full build above for a map visible in the editor.

## Connect Argon

The project maps `src/shared` to `ReplicatedStorage.Shared`, `src/server` to `ServerScriptService.Server`, and `src/client` to `StarterPlayer.StarterPlayerScripts.Client`.

1. Install the official [Argon Studio plugin](https://argon.wiki/docs/installation), or run `argon plugin install` once.
2. From this folder, run `powershell -ExecutionPolicy Bypass -File scripts/serve.ps1` (or `argon serve default.project.json --sourcemap`).
3. Open the built place. In Studio's Argon plugin, connect to **127.0.0.1:8000** and sync this project.
4. Keep the server running while editing source. Stop and restart Play to pick up module changes safely.

The project and VS Code recommendations are included. `sourcemap.json` is generated locally. `World.luau` constructs the arena, cottages, lobby, boards, and lighting; runtime construction replaces the preview map. Unknown Workspace instances are preserved during sync. See the [Argon project format](https://argon.wiki/api/project).

## Survival rounds

- **15-second intermission:** queued players prepare in the protected lobby. Up to **12 players** enter each round; late arrivals wait for the next one.
- **150-second round:** button presses start random events. Each event has its own instructions, effects, and danger. Events run one at a time, with a short pause between them. The arena also starts events automatically if nobody presses.
- **Last survivor wins:** falling off, dying, or resetting a character ends that player's life for the current round. Eliminated players return to the lobby, can watch the survivors, and remain queued unless they leave the queue.
- **Sudden death:** if multiple players remain when time runs out, coral rings warn of storm strikes. Dodge before they hit; rings widen as overtime continues. A last survivor wins, or the round ends in a draw after 60 seconds without a winner reward.
- **8-second results:** competitive winners receive **120 base coins, 20 Button Points, and 1 win**. The arena resets before the next round.
- **Solo practice:** one player can test a complete survival round. Surviving the timer gives **40 base coins and 8 points**; competitive wins require a round that started with at least two players.

Every accepted player press earns **1 Button Point**, **1 lifetime press**, and **2 base coins**. Only living round participants within 15 studs of the physical button can press. Rejected presses award nothing. Surviving a completed event earns **8 base coins and 2 points**, and some events offer extra pickups or role rewards.

Hazards target active round participants. The lobby has its own spawn pads and stays outside the arena's damage and collection rules. Temporary event visuals, jobs, roles, movement changes, and island mutations are cleaned up when events end or the round finishes. Falling out of the arena eliminates a survivor; falling from the lobby returns a visitor to safety.

## Random events

The event catalog currently contains **29 events**. Selection avoids repeating the previous event, respects minimum player counts, and gives fewer calm events as the round's threat level rises.

| Event | What happens |
| --- | --- |
| Cops & Robbers | A blue cop chases a red robber after a head start. Capture and escape earn different rewards. |
| The Lava Is Rising | Lava climbs toward the islands; emergency stairs and high roofs offer refuge. |
| Laser Limbo | A pink beam sweeps across the arena. Jump over it. |
| Meteor Mayhem | Red warning circles reveal where meteors will strike. |
| Chicken's Revenge | A giant chicken pursues the nearest survivor. |
| Zombie Outbreak | Three zombies chase players across the islands. |
| Hot Potato | Pass a bomb by tagging another survivor before its eight-second fuse runs out. |
| Musical Islands | Reach a green island before the safety window closes. Safe islands change during the event. |
| Now You See It... | Marked islands, their cottages, and their bridges become unsafe after a warning. |
| Honey, I Shrunk the Islands | Outer floors contract, leaving smaller places to stand. |
| Acid Rain | Green emergency umbrellas protect players from damaging rain. |
| Tidal Trouble | A blue wave crosses the map; climb high or jump clear. |
| Jump! Jump! Jump! | Expanding golden shockwaves sweep outward from the button. |
| Ice Ice Maybe | Low-friction icy islands and bridges make movement slippery. |
| Moon Walk | Round participants get floaty jumps while the lobby keeps normal gravity. |
| Speed Limit: None | Survivors run faster across the narrow bridges. |
| Lightning Likes You | Yellow circles warn of lightning aimed at players' previous positions. |
| The Great Spinner | A rotating red arm sweeps around the arena. |
| Greed Is Dangerous | Collect gold coins and avoid red trap coins. |
| Red Light, Green Light | Move on green and freeze on red after a brief stopping grace. |
| Special Delivery: Bombs | Delayed blasts target where survivors were standing. |
| A Moment of Mercy | Supply crates restore health and award coins. |
| Earthquake! | Platforms shake and tremors shove grounded survivors. |
| Twister on the Loose | A moving purple tornado pulls nearby players toward it. |
| The Cursed Crown | A marked survivor earns coins while losing health; contact passes the curse. |
| Freeze Tag | A blue tagger briefly freezes and damages nearby survivors. |
| Boing! | Outer islands become trampolines that launch players upward. |
| Bridge Roulette | Half the bridges turn red and lose their collision after a warning. |
| Laser Grid | Four neon fences pulse between safe blue and dangerous pink. |

## UI, lobby, and progression

The HUD uses cream cards, coral actions, teal accents, clear health and round timers, and event instructions. It adapts to desktop, portrait mobile, and landscape mobile screens. The map uses bright grass, pastel cottage roofs, warm daylight, soft sky haze, and restrained bloom.

Use **SHOP / B**, **RANKS / L**, and **PLAYERS / P** to open the menus. The player roster groups living survivors separately from lobby visitors and spectators, with roles, wins, and presses. **WATCH / V** follows surviving players; press it again to cycle or stop. **Q** toggles the next-round queue while outside a round. **EMOTE** plays the equipped emote.

The shop includes four button skins, two trails, two titles, two press sounds, two emotes, two pets, and 2x/3x coin upgrades. Purchases use earned Button Points. Items auto-equip after purchase; owned equipment can be equipped again free or removed. The highest owned coin multiplier applies to earned coins; multipliers do not stack.

The shared button shows the last presser's equipped skin. Player trails, titles, and current event roles appear on characters. Pets render locally for each player's equipped companion. Emotes use the standard Roblox avatar animation system; R15 is recommended. Sounds use Roblox's bundled audio.

The **Hall of Survivors** menu and lobby board show the top **10 survival win totals** and refresh every **60 seconds**. Published servers use the global win leaderboard; Studio practice uses a session leaderboard. New global totals appear after a successful save and refresh. Roblox's built-in player list shows **Wins, Presses, Coins, Button Points, and Status**, with separate Lobby and Survivors teams.

## Saved progress and publishing

Published servers use Roblox DataStores automatically. Coins, points, lifetime presses, survival wins, completed rounds, ownership, and equipment are saved every **45 seconds** and when players leave. Session leases protect profiles from concurrent server writes. An unavailable or busy profile load prevents play rather than replacing saved progress with defaults.

Existing version-one player profiles migrate to version two while retaining their coins, points, presses, ownership, and equipped items. New win and round counters start at zero. The existing `ButtonProfiles_v1` profile store and `ButtonPresses_v1` press totals are retained, while `ButtonWins_v1` stores the global survival win ranking.

Studio intentionally uses disposable practice progress and a session leaderboard by default. Purchases reset when Play ends. To test real saves, publish a **separate test experience**, enable **Game Settings → Security → Enable Studio Access to API Services**, and set `PersistenceInStudio = true` in `src/shared/Config.luau`. Studio can access the same stores as live servers, so use a separate test experience. See [Roblox's DataStore documentation](https://create.roblox.com/docs/cloud-services/data-stores).

To release, open the built place and use **File → Publish to Roblox** in your account or group. No Roblox place ID, credentials, paid products, or third-party model permissions are needed to build or play locally. Publishing the Roblox experience is separate from pushing this source repository.

## Project layout

```text
default.project.json       Argon instance mapping and local connection
rokit.toml                 Pinned Argon and Lune tools
src/shared/                Tuning, shop catalog, save schema, economy, round/press rules
src/server/                Round lifecycle, events, map, saves, character cosmetics
src/client/                Responsive HUD, shop, ranks, roster, spectating, pets
scripts/                   Build, serve, and test helpers
tests/                     Automated Luau and Roblox property checks
build/                     Generated Studio places (ignored by Git)
```

Change round timing and rewards in `Config.luau`, shop products in `Catalog.luau`, event behavior in `Events.luau`, and map aesthetics in `World.luau`. No Wally installation is necessary.

## Verification

Run `powershell -ExecutionPolicy Bypass -File scripts/test.ps1`, or run both `lune run tests/run.luau` and `lune run tests/events.luau`. Automated checks compile production scripts, exercise rewards and purchases, sanitize and migrate saves, check round transitions, construct the world and responsive UI against Roblox property definitions, and run every event through a virtual clock. Event checks cover captures, escapes, bomb fuses, warning dodges, lobby isolation, cleanup, and cancellation. GitHub Actions runs the checks and uploads a built Studio place.

Before release, use Studio's **Server & Clients** test with at least two players to check queue changes, simultaneous presses, role chases, hazard telegraphs, deaths, respawns, round outcomes, spectating, and touch/controller input. Character physics, avatar animations, networking, and live DataStore behavior require Studio or a published server. Offline checks do not establish that multiplayer playtesting has passed.
