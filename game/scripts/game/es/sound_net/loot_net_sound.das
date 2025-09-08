require ecs
require ecs.common
require app
require DngNet
require soundHash
require game.events.events
require game.events.inventory_events
require game.events.sound_net_events
require game.utils.net_utils
require game.utils.sound_utils

let DEF_LOOT_RANGE : float = 20.

[es(tag=server)]
def loot_net_sound_on_loot_pickup(evt : EventOnItemPickup; eid : EntityId)
  let lootSoundType = get_string(evt.itemEid, "item__lootSoundType", "other")
  send_net_event(eid, CmdPlayLootSoundForEnemy(hash = sound_hash("pick_{lootSoundType}"), time = get_sync_time()),
                 enum_connections_near_entity(eid, /*range*/ DEF_LOOT_RANGE, TEAM_UNASSIGNED/*team*/, INVALID_ENTITY_ID/*squad*/, eid/*except_possessed*/))

[es(tag=server)]
def loot_net_sound_on_loot_use(evt : EventOnLootUse; eid : EntityId)
  let lootSoundType = get_string(evt.itemEid, "item__lootSoundType", "other")
  send_net_event(eid, CmdPlayLootSound(hash = sound_hash("use_{lootSoundType}"), time = get_sync_time()),
                 enum_connections_near_entity(eid, /*range*/ DEF_LOOT_RANGE))
