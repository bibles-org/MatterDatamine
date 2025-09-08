require ecs
require soundEvent
require game.events.events_active_matter


[es(tag=sound)]
def teleportation_sound(evt : EventPortalTeleportEntity;
                        human_teleportation_sound__heroPath : string;
                        human_teleportation_sound__inPath : string;
                        human_teleportation_sound__outPath : string;
                        is_watched_sound : bool)

  if is_watched_sound
    oneshot(human_teleportation_sound__heroPath, evt.newTm[3], true/*allow_far_oneshots*/)
  else
    oneshot(human_teleportation_sound__inPath, evt.oldTm[3])
    oneshot(human_teleportation_sound__outPath, evt.newTm[3])
