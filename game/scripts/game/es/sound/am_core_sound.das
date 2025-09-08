require ecs
require game.events.events_game
require game.events.events_active_matter
require game.es.am_core_warrior_common
require sound_utils.modules.sound_control_common
require soundEvent


[es(tag=sound, track=am_core__fragmentsLimit)]
def am_core_sound_track_fragments_limit(evt : Event;
                                        am_core__fragmentsLimit : int;
                                        var sound_control__allowSound : bool&;
                                        am_core_sound__fragmentDroppedPath : string;
                                        transform : float3x4)
  sound_control__allowSound = am_core__fragmentsLimit > 0
  oneshot(am_core_sound__fragmentDroppedPath, transform[3])


[es(tag=sound, track=(isAlive, sound_control__state))]
def am_core_sound_protective_mode_toggle(evt : Event;
                                         isAlive : bool;
                                         sound_control__state : int;
                                         am_core_sound__activeModePath : string;
                                         am_core_sound__protectiveModePath : string;
                                         var am_core_sound__event : SoundEvent&;
                                         transform : float3x4)
  abandon(am_core_sound__event)
  if have_sound(sound_control__state)
    am_core_sound__event |> play(isAlive ? am_core_sound__activeModePath : am_core_sound__protectiveModePath, transform[3])


[es(tag=sound, on_event=ParallelUpdateFrameDelayed, after=sound_begin_update_es, before=sound_end_update_es)]
def am_core_sound_protective_mode_update(evt : Event;
                                         sound_control__state : int;
                                         am_core_sound__event : SoundEvent;
                                         transform : float3x4)
  if have_sound(sound_control__state)
    set_pos(am_core_sound__event, transform[3])


[es(tag=sound, track=isAlive)]
def am_core_enter_active_mode_sound(evt : Event;
                                    isAlive : bool;
                                    am_core_sound__startActiveModePath : string;
                                    transform : float3x4)
  if isAlive
    oneshot(am_core_sound__startActiveModePath, transform[3])


[es(tag=sound)]
def am_core_sound_hit_reaction(evt : EventOnEntityHit; eid : EntityId;
                               isAlive : bool;
                               am_core_sound__hitReactionPath : string;
                               transform : float3x4)
  if isAlive && evt.victim == eid
    oneshot(am_core_sound__hitReactionPath, transform[3])


[es(tag=sound, track=am_core_warrior__state)]
def am_core_warrior_charge_sound(evt : Event;
                                 am_core_sound__warriorCharge : string;
                                 am_core_warrior__state : int;
                                 transform : float3x4)
  if am_core_warrior__state == int(CoreWarriorState.CHARGE)
    oneshot(am_core_sound__warriorCharge, transform[3])


[es(tag=sound, before=core_warrior_update)]
def am_core_warrior_attack_sound(act : ParallelUpdateFrameDelayed;
                                 am_core_sound__warriorAttack : string;
                                 am_core_warrior__actAt : float;
                                 am_core_warrior__state : int;
                                 transform : float3x4)
  if am_core_warrior__state == int(CoreWarriorState.CHARGE)
    if (act.curTime >= am_core_warrior__actAt &&
        act.curTime - act.dt < am_core_warrior__actAt)
      oneshot(am_core_sound__warriorAttack, transform[3])
