require ecs
require app
require sound_utils.modules.sound_player_common
require soundEvent
require soundSystem
require GuidanceLock
require DagorSystem


def gun_guidance_state_sound_track(gun_guidance_state_sound__warmingUpPath : string;
                                   gun_guidance_state_sound__activePath : string;
                                   gun_guidance_state_sound__trackingPath : string;
                                   var gun_guidance_state_sound__event : SoundEvent&;
                                   var gun_guidance_state_sound__guidanceState : int&;
                                   guidance_state : int;
                                   is_watched_sound : bool)

  if gun_guidance_state_sound__guidanceState != guidance_state || gun_guidance_state_sound__event.enabled != is_watched_sound
    gun_guidance_state_sound__guidanceState = guidance_state
    gun_guidance_state_sound__event.enabled = is_watched_sound
    abandon(gun_guidance_state_sound__event)

    if guidance_state == int(EGuidanceLockState.RESULT_WARMING_UP)
      gun_guidance_state_sound__event |> reset(soundEvent::play(apply_watched_prefix(gun_guidance_state_sound__warmingUpPath, is_watched_sound), get_listener_pos()))
    elif guidance_state == int(EGuidanceLockState.RESULT_LOCKING)
      gun_guidance_state_sound__event |> reset(soundEvent::play(apply_watched_prefix(gun_guidance_state_sound__activePath, is_watched_sound), get_listener_pos()))
    elif guidance_state == int(EGuidanceLockState.RESULT_TRACKING)
      gun_guidance_state_sound__event |> reset(soundEvent::play(apply_watched_prefix(gun_guidance_state_sound__trackingPath, is_watched_sound), get_listener_pos()))

/*
    if is_watched_sound
      if guidance_state == int(EGuidanceLockState RESULT_STANDBY)
        sound_debug("{get_sync_time()} guidanceState=RESULT_STANDBY")
      elif guidance_state == int(EGuidanceLockState RESULT_INVALID)
        sound_debug("{get_sync_time()} guidanceState=RESULT_INVALID")
      elif guidance_state == int(EGuidanceLockState RESULT_WARMING_UP)
        sound_debug("{get_sync_time()} guidanceState=RESULT_WARMING_UP")
      elif guidance_state == int(EGuidanceLockState RESULT_LOCKING)
        sound_debug("{get_sync_time()} guidanceState=RESULT_LOCKING")
      elif guidance_state == int(EGuidanceLockState RESULT_TRACKING)
        sound_debug("{get_sync_time()} guidanceState=RESULT_TRACKING")
      elif guidance_state == int(EGuidanceLockState RESULT_LOCK_AFTER_LAUNCH)
        sound_debug("{get_sync_time()} guidanceState=RESULT_LOCK_AFTER_LAUNCH")
      else
        sound_debug("{get_sync_time()} guidanceState={guidance_state}")
*/



[es(tag=sound, track=(gun__guidanceState, gun__owner))]
def gun_guidance_state_sound_track_gun(evt : Event;
                                       eid aka gun_eid : EntityId;
                                       gun_guidance_state_sound__warmingUpPath : string;
                                       gun_guidance_state_sound__activePath : string;
                                       gun_guidance_state_sound__trackingPath : string;
                                       var gun_guidance_state_sound__event : SoundEvent&;
                                       var gun_guidance_state_sound__guidanceState : int&;
                                       gun__guidanceState : int;
                                       gun__owner : EntityId)

  var guidanceState = int(EGuidanceLockState.RESULT_INVALID)
  var isWatchedSound = false

  query(gun__owner) <| $ [es] (is_watched_sound, human_net_phys__isAiming : bool;
                               human_weap__gunEids : EidList;
                               human_weap__curGunSlot : int;
                               human_attached_gun__attachedGunEid : EntityId = INVALID_ENTITY_ID)

    let selectedGunEid = human_weap__curGunSlot >= 0 && !human_attached_gun__attachedGunEid ? human_weap__gunEids[human_weap__curGunSlot] : human_attached_gun__attachedGunEid
    if selectedGunEid == gun_eid && human_net_phys__isAiming
      guidanceState = gun__guidanceState
      isWatchedSound = is_watched_sound

  gun_guidance_state_sound_track(gun_guidance_state_sound__warmingUpPath,
                                 gun_guidance_state_sound__activePath,
                                 gun_guidance_state_sound__trackingPath,
                                 gun_guidance_state_sound__event,
                                 gun_guidance_state_sound__guidanceState,
                                 guidanceState,
                                 isWatchedSound)



[es(tag=sound, track=(is_watched_sound, human_net_phys__isAiming, human_weap__curGunSlot, human_weap__gunEids, human_attached_gun__attachedGunEid))]
def gun_guidance_state_sound_track_human(evt : Event;
                                         eid aka human_eid : EntityId;
                                         is_watched_sound, human_net_phys__isAiming : bool;
                                         human_weap__gunEids : EidList;
                                         human_weap__curGunSlot : int;
                                         human_attached_gun__attachedGunEid : EntityId = INVALID_ENTITY_ID)

  let selectedGunEid = human_weap__curGunSlot >= 0 && !human_attached_gun__attachedGunEid ? human_weap__gunEids[human_weap__curGunSlot] : human_attached_gun__attachedGunEid

  query() <| $ [es] (eid aka gun_eid : EntityId;
                     gun_guidance_state_sound__warmingUpPath : string;
                     gun_guidance_state_sound__activePath : string;
                     gun_guidance_state_sound__trackingPath : string;
                     var gun_guidance_state_sound__event : SoundEvent&;
                     var gun_guidance_state_sound__guidanceState : int&;
                     gun__guidanceState : int;
                     gun__owner : EntityId)

    if gun__owner == human_eid

      gun_guidance_state_sound_track(gun_guidance_state_sound__warmingUpPath,
                                     gun_guidance_state_sound__activePath,
                                     gun_guidance_state_sound__trackingPath,
                                     gun_guidance_state_sound__event,
                                     gun_guidance_state_sound__guidanceState,
                                     selectedGunEid == gun_eid && human_net_phys__isAiming ? gun__guidanceState : int(EGuidanceLockState.RESULT_INVALID),
                                     is_watched_sound)

