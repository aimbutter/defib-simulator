
# Defib Simulator

## Commands

* **`!saferoom`** — Run this inside the saferoom to mark the checkpoint destination for your team.
* **`!defib`** — Teleports all other survivors to the `!saferoom` spot, locks the doors, kills you (or handles your existing death), and triggers the map transition to revive you at your outside position.
* **`!forcedefib`** — Performs the same transition sequence as `!defib`, but skips finding and closing checkpoint doors (useful for custom maps without saferoom doors).

## Features

* **ConVar Adjustment:** Automatically sets `director_afk_timeout` to `42069` so players won't go idle.
* **Human Player Check:** Prevents accidental map soft-locks by verifying at least one human player is connected before initiating the sequence.
* **Transition Fail Detection:** Sends a chat warning after 3 seconds if the saferoom location didn't trigger the engine's `map_transition` event.
* **Auto-Defib Upon Map Transition:** Simulates a defibrillator revive on the command caller right as the map transition starts.

## Requirements

* **Core:** [SourceMod](https://www.sourcemod.net/), [MetaMod:Source](https://www.metamodsource.net/)
* **Fake Players (Any of the following):**
* [TAS-Kit (GitHub)](https://github.com/sw1ft747/TAS-Kit)
* [Left4TAS (GitHub)](https://github.com/sw1ft747/Left4TAS)
* [Fake Client Plugin (AlliedModders Thread)](https://forums.alliedmods.net/showthread.php?t=304789)
