require ecs
require soundEvent
require game.events.events_active_matter
require game.es.traps_common
require sound_utils.modules.sound_control_common
require level


[es(tag=sound, on_disappear)]
def trap_disappear_sound(evt : Event;
                         transform : float3x4;
                         trap_trigger_sound__path : string)
  if !is_level_unloading() && trap_trigger_sound__path != ""
    oneshot(trap_trigger_sound__path, transform[3])


[es(tag=sound, track=teleport_trap_affect__state)]
def teleport_trap_affect_sound(evt : Event;
                               teleport_trap_affect__teleportTm : float3x4;
                               teleport_trap_affect__state : int;
                               teleport_trap_affect_sound__path : string)
  if teleport_trap_affect__state == int(TeleportTrapAffectState.TELEPORT)
    oneshot(teleport_trap_affect_sound__path, teleport_trap_affect__teleportTm[3], true/*allow_far_oneshots*/)



[es(tag=sound, on_appear, track=sound_control__state, after=sound_effect_track, REQUIRE=anomalySoundEffectWithVars)]
def anomaly_sound_effect_with_vars(evt : Event;
                                   eid : EntityId;
                                   sound_control__state : int;
                                   sound_effect__event : SoundEvent)
  if have_sound(sound_control__state)
    query() <| $ [es] (anomaly_effect__ownerAnomalyEid : EntityId; affect_anomaly_sound__var : string)
      if eid == anomaly_effect__ownerAnomalyEid
        set_var(sound_effect__event, affect_anomaly_sound__var, 1.)


[es(tag=sound, on_appear)]
def anomaly_effect_sound_appear(evt : Event;
                                anomaly_effect__ownerAnomalyEid : EntityId;
                                affect_anomaly_sound__var : string)
  query(anomaly_effect__ownerAnomalyEid) <| $ [es] (sound_effect__event : SoundEvent)
    set_var(sound_effect__event, affect_anomaly_sound__var, 1.)


[es(tag=sound, on_disappear)]
def anomaly_effect_sound_disappear(evt : Event;
                                   anomaly_effect__ownerAnomalyEid : EntityId;
                                   affect_anomaly_sound__var : string)
  query(anomaly_effect__ownerAnomalyEid) <| $ [es] (sound_effect__event : SoundEvent)
    set_var(sound_effect__event, affect_anomaly_sound__var, 0.)
