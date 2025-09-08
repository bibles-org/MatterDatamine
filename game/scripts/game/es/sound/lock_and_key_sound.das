require ecs
require soundEvent
require sound_utils.modules.sound_utils_events
require soundHash


[es(tag=sound, on_event=EventUseObjectBlocked)]
def play_no_key_use_failed_sound(evt : Event; eid : EntityId; transform : float3x4; interactable__onNoKeySoundPath : string)
  if should_play(transform[3])
    sendEvent(eid, CmdPlaySound(hash = sound_hash(interactable__onNoKeySoundPath), pos = transform[3]))