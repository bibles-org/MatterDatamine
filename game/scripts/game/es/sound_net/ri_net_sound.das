require ecs
require ecs.common
require app
require DngNet
require soundHash
require game.events.events
require game.events.sound_net_events
require game.utils.net_utils
require game.utils.sound_utils

[es(tag=server, REQUIRE=net_sound__riextraDestroyed)]
def ri_net_sound_on_riextra_destroyed(evt : EventRiExtraDestroyed;
                                      eid : EntityId)
  broadcast_net_sound(eid, "riextraDestroyed", 0./*param*/, TEAM_UNASSIGNED, INVALID_ENTITY_ID, INVALID_ENTITY_ID, false/*should_exist*/)
