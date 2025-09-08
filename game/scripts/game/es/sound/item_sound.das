require ecs
require soundEvent
require sound_utils.modules.sound_player_common
require game.events.events_active_matter


[es(tag=sound)]
def item_destroyed_sound(evt : CmdItemDestroyed;
                         item_destroyed_sound__path : string;
                         item__humanOwnerEid : EntityId)
  query(item__humanOwnerEid) <| $ [es] (transform aka human_transform : float3x4)
    oneshot(item_destroyed_sound__path, human_transform[3])
