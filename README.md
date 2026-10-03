# DON'T PRESS THE BUTTON

A complete Roblox party game built around one giant red button, shared surprises, and a server-wide countdown to something special. Made for **Argon 2**, with plain Luau and no external game packages or paid assets.

## Play in Roblox Studio

1. Install [Rokit](https://github.com/rojo-rbx/rokit) if you do not already have Argon. In this folder, run `rokit install` to install the versions pinned in `rokit.toml`.
2. Run `powershell -ExecutionPolicy Bypass -File scripts/build.ps1`.
3. Open `build/DontPressTheButton.rbxl` in Roblox Studio. The complete room is visible immediately.
4. Press **Play**. Walk to the button and press **E**, controller **X**, tap the prompt, click the physical button, or use the on-screen button.

The simpler `argon build default.project.json -o build/Game.rbxl` works too. That place generates the room when Play starts. Use the full build above for a room visible in the editor.

## Connect Argon

The project maps `src/shared` to `ReplicatedStorage.Shared`, `src/server` to `ServerScriptService.Server`, and `src/client` to `StarterPlayer.StarterPlayerScripts.Client`.

1. Install the official [Argon Studio plugin](https://argon.wiki/docs/installation), or run `argon plugin install` once.
2. From this folder, run `powershell -ExecutionPolicy Bypass -File scripts/serve.ps1` (or `argon serve default.project.json --sourcemap`).
3. Open the built place. In Studio's Argon plugin, connect to **127.0.0.1:8000** and sync this project.
4. Keep the server running while editing source. Stop and restart Play to pick up module changes safely.

The project and VS Code recommendations are included. `sourcemap.json` is generated locally. The arena is constructed by `World.luau`, so change that file to change the room; runtime construction replaces the preview arena. Unknown Workspace instances are preserved during sync. See the [Argon project format](https://argon.wiki/api/project).

## Game loop

- Every accepted press adds **1 Button Point**, **1 lifetime press**, and **2 base coins**. Rejected or cooldown presses give nothing.
- All **13 random events** are implemented: payday, random teleport, giant chicken, rain, last player standing, launch, 30-second king, collectible coins, a 10-second countdown with a reward reveal, a temporary button tax, a random gift, a room makeover, and nothing.
- Events run one at a time so players can see their consequences. The button becomes available again after the event ends. Countdown, room effects, coins, gravity, and decorations clean up automatically. King status lasts 30 seconds independently.
- The shared display counts down from **99 accepted presses**. At zero, a **30-second special event** recolors the room, enables low gravity, spawns coins, and gives every loaded player **100 base coins + 25 Button Points**. The counter resets to 99 afterwards.
- The tax event makes presses cost **5 coins for 45 seconds**, then resets them to free. Coin multipliers apply to earned coins, including event rewards and pickups, and never to costs.

## Shop and competition

The shop includes four button skins, two trails, two titles, two funny press sounds, two emotes, two pets, and 2x/3x coin upgrades. All purchases use earned Button Points. Items auto-equip after purchase and can be equipped again free. Optional equipment can be removed. The highest owned coin multiplier applies; multipliers do not stack.

The shared button shows the last presser's equipped skin. Trails, titles, and the king crown appear on the character. Pets render locally for every player's equipped companion. Use **EMOTE** to play the equipped emote with the standard Roblox avatar animation system (R15 recommended). The sounds use Roblox's bundled audio.

Open **SHOP** / **B** or **TOP PRESSERS** / **L**. The global leaderboard and wall board show the top 10 lifetime press counts and refresh every 60 seconds. New totals appear after a save. The built-in player list also shows presses, coins, and points. Mobile touch and controller proximity prompts are supported.

## Saved progress and publishing

Published servers use Roblox DataStores automatically. Coins, points, lifetime presses, ownership, and equipment are saved every 45 seconds and when players leave. Session leases prevent two servers overwriting the same profile. An unavailable or busy save prevents play rather than replacing existing progress with default values. An OrderedDataStore backs the global presses leaderboard.

Studio intentionally uses disposable practice progress and a session leaderboard by default. Your test purchases will reset when Play ends. To test real saves, publish a **separate test experience**, enable **Game Settings → Security → Enable Studio Access to API Services**, and set `PersistenceInStudio = true` in `src/shared/Config.luau`. Studio can access the same stores as live servers, so use a separate test experience. See [Roblox's DataStore documentation](https://create.roblox.com/docs/cloud-services/data-stores).

To release, open the built place and use **File → Publish to Roblox** in your account or group. No Roblox place ID, credentials, paid products, external models, or third-party asset permissions are needed to build or play locally. Publishing the Roblox experience is separate from pushing this source repository.

## Project layout

```text
default.project.json       Argon instance mapping and local connection
rokit.toml                 Pinned Argon and Lune tools
src/shared/                Tuning, shop catalog, save schema, economy, press rules
src/server/                Authoritative button, events, map, saves, cosmetics
src/client/                Responsive HUD, shop, leaderboard, input, pet rendering
scripts/                   Build, serve, and test helpers
tests/                     Automated Luau and Roblox property checks
build/                     Generated Studio places (ignored by Git)
```

Change event tuning in `Config.luau`, products in `Catalog.luau`, and surprises in `Events.luau`. No Wally installation is necessary.

## Verification

Run `powershell -ExecutionPolicy Bypass -File scripts/test.ps1`, or `lune run tests/run.luau`. Checks compile every production script, exercise rewards and purchase rules, sanitize malformed saves, test the 99th press, construct the room and responsive UI against real Roblox property definitions, and verify temporary event cleanup. GitHub Actions runs the checks and uploads a built place.

Before release, use Studio's **Server & Clients** test with at least two players to check simultaneous presses, respawns, coin pickups, controller/touch input, and special-event rewards. Live DataStore access, character physics, and avatar animations require Studio or a published server; offline tests do not emulate them.
