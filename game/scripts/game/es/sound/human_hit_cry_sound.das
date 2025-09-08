require ecs
require app
require human_sounds.modules.human_sounds_events
require game.events.sound_net_events
require game.events.events_active_matter


let MAX_NET_DELAY = 3.

[es(tag=sound)]
def human_hit_cry_sound(evt : CmdHumanHitNetSound;
                        eid : EntityId;
                        human_hit_cry_sound__cooldown : float;
                        var human_hit_cry_sound__nextTime : float&)
  if get_sync_time() < evt.time + MAX_NET_DELAY && get_sync_time() >= human_hit_cry_sound__nextTime
    human_hit_cry_sound__nextTime = get_sync_time() + human_hit_cry_sound__cooldown
    sendEvent(eid, CmdHumanVoiceEffectOneshot(phrase = "hitCry"))


[es(tag=sound)]
def human_hit_cry_sound_from_projectile(evt : OnShellHitEntityFx;
                                        eid : EntityId;
                                        human_hit_cry_sound__cooldown : float;
                                        var human_hit_cry_sound__nextTime : float&)
  if eid == evt.victimEid && get_sync_time() >= human_hit_cry_sound__nextTime
    human_hit_cry_sound__nextTime = get_sync_time() + human_hit_cry_sound__cooldown
    sendEvent(eid, CmdHumanVoiceEffectOneshot(phrase = "hitCry"))
