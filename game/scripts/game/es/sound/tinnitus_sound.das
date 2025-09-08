require ecs
require soundHash
require game.events.sound_events
require sound_utils.modules.sound_utils_events


[es(tag=sound, REQUIRE=net_sound__descs)]
def tinnitus_sound(evt : CmdStartTinnitusSfx;
                   eid : EntityId)
  sendEvent(eid, CmdPlaySound(hash = sound_hash("tinnitus"), pos = evt.pos, param = evt.power))
