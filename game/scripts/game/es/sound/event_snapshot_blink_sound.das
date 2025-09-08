require ecs
require math.base
require soundEvent
require soundSystem
require game.events.events_active_matter


[es(tag=sound)]
def event_snapshot_blink_sound(evt : EventSnapshotBlink;
                               event_snapshot_blink_sound__path : string)
  let cam = get_listener_pos()
  oneshot(event_snapshot_blink_sound__path, distance_sq(cam, evt.from[3]) < distance_sq(cam, evt.to[3]) ? evt.from[3] : evt.to[3])


[es(tag=sound)]
def event_nphys_teleport_sound(evt : EventNPhysTeleported;
                               event_nphys_teleport_sound__path : string)
  let cam = get_listener_pos()
  oneshot(event_nphys_teleport_sound__path, distance_sq(cam, evt.from[3]) < distance_sq(cam, evt.to[3]) ? evt.from[3] : evt.to[3])
