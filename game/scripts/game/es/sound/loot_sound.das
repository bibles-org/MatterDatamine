require ecs
require ecs.common
require app
require soundHash
require soundEvent
require game.events.events_active_matter
require game.events.sound_net_events
require sound_utils.modules.sound_utils_events
require game.utils.hero
require game.events.events_game
require game.events.inventory_events

def play_sound(human_eid : EntityId; hash : uint; transform : float3x4; var loot_sound__time : float&)
  if get_sync_time() > loot_sound__time + 0.1
    loot_sound__time = get_sync_time()
    if should_play(transform[3])
      sendEvent(human_eid, CmdPlaySound(hash = hash, pos = transform[3]))

[es(tag=sound)]
def loot_sound(cmd : CmdPlayLootSound; eid : EntityId; transform : float3x4; var loot_sound__time : float&)
  if get_sync_time() < cmd.time + 5.
    play_sound(eid, cmd.hash, transform, loot_sound__time)

[es(tag=sound)]
def loot_sound_enemy(cmd : CmdPlayLootSoundForEnemy; eid : EntityId; transform : float3x4; var loot_sound__time : float&)
  if get_sync_time() < cmd.time + 5.
    play_sound(eid, cmd.hash, transform, loot_sound__time)

[es(tag=sound)]
def loot_sound_pickup(evt : CmdItemPickup; eid : EntityId; transform : float3x4; var loot_sound__time : float&)
  let lootSoundType = get_string(evt.item, "item__lootSoundType", "other")
  play_sound(eid, sound_hash("pick_{lootSoundType}"), transform, loot_sound__time)

[es(tag=sound)]
def loot_sound_drop(evt : EventOnItemDrop; eid : EntityId; transform : float3x4; is_watched_sound : bool; var loot_sound__time : float&)
  if is_watched_sound
    let lootSoundType = get_string(evt.itemEid, "item__lootSoundType", "other")
    play_sound(eid, sound_hash("drop_{lootSoundType}"), transform, loot_sound__time)

[es(tag=sound, REQUIRE=hero)]
def loot_sound_inventory_pickup(evt : CmdItemPickup)
  query(evt.item) <| $ [es] (item__isInUse = false)
    if !item__isInUse
      sendEvent(evt.item, CmdPlaySoundSimple(hash = sound_hash("inventoryPickup")))
