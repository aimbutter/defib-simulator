
# Defib Simulator


## My binds & Notes

``bind x "nb_delete_all; wait 5; sm_fake; wait 50; warp_all_survivors_to_checkpoint; wait 50; say !saferoom"; bind c "say !defib"``

After changing map, use `changelevel <mapname>` instead because `map <mapname>` would take kinda long to load (because of the sm_fake i guess?)

Use this when you are exploring the maps for tricks, skips only. When you are attempting a TAS, put this thing out of the `plugins` folder or put `sm plugins unload defib` in your console.


## Commands

* **Step 1: `!saferoom`** — Run this inside the saferoom to mark the checkpoint destination for your team.
* **Step 2:`!defib`** — Teleports all other survivors to the `!saferoom` spot, locks the doors, kills you (or handles your existing death), and triggers the map transition to revive you at your outside position.
  
* **Optional: `!forcedefib`** — Performs the same transition sequence as `!defib`, but skips finding and closing checkpoint doors (useful for custom maps without saferoom doors). If this plugin has any problem with a certain map that has no saferoom door or unregular map transition then idk lol
