# Original disaster sound pack

Seventeen original mono WAV effects made by `scripts/generate_audio.py`, using oscillators
and seeded noise. There are no third-party samples, recordings, voices, or subscription
requirements. The included source and generated audio can be used, modified, and
redistributed with this game without paying royalties. See `LICENSE.txt`.

The game plays Roblox's bundled audio immediately. This pack is an optional higher
quality replacement; files on your computer cannot act as runtime Roblox SoundIds.

1. Import the WAV files as audio in the Roblox Creator Dashboard or Studio.
2. Allow this experience to use each uploaded asset.
3. Put its `rbxassetid://...` identifier in `src/shared/AudioCatalog.luau`.
   Map `button` to press, `warning` to warning/eventstart, `impact` to impact/explosion,
   `eruption` to eruption, `storm` to storm/lightning, `scifi` to scifi, `whoosh` to chase,
   and `reward` to relief/reward/roundend. The new `gunshot`, `sword`, `role`, `supply`,
   `checkpoint`, `obby`, `purchase`, `knockout`, and `victory` files map directly to
   cues with those names. Adjust volume after a Studio playtest.

Roblox's [audio asset guide](https://create.roblox.com/docs/audio/assets) covers
importing and experience permissions. This repository does not contain Roblox
credentials or claim that these optional files have already been uploaded.

Run `python scripts/generate_audio.py` to regenerate identical files. `manifest.json`
records durations, sample rate, peak, and RMS levels. Peak amplitude is 0.78 to preserve
headroom when effects overlap.
