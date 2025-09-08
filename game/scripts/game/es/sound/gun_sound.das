require ecs
require ecs.safe
require soundEvent
require soundHash
require soundSystem
require weapon_sounds.modules.weapon_sounds_events
require common_sounds.modules.common_sounds_events
require danetlibs.renderer.includes.pufd_events
require sound_utils.modules.sound_player_common
require game.es.sound.gun_sound_common
require DagorMath
require Gun
require game.events.events_game
require game.events.sound_events


def try_shot_loop(var sound_event : SoundEvent&; pos : float3; shot_path, tags : Object; is_watched : bool)
  release(sound_event)
  let path = make_gun_shot_sound_path_str(shot_path, tags, is_watched, false)
  sound_event |> reset(sound_player_common::play_name_path_impl(path, "", pos, false))


def is_oneshot(gun : Gun; firing_mode : uint)
  return gun_getFiringMode(gun, int(firing_mode)).modeType != EFiringModeType.EFM_AUTOMATIC


def abandon_shot_loop(var sound_event : SoundEvent&)
  if is_valid_handle_value(sound_event)
    abandon(sound_event)


def get_smid_from_gun_owner(gun__owner : EntityId) : float
  var smid = 0.
  query(gun__owner) <| $ [es] (human_steps_sound__smid : float)
    smid = human_steps_sound__smid
  return smid


def on_launch(gun_eid : EntityId;
              launch_pos : float3;
              firing_mode : uint;
              gun : Gun;
              time_between_shots : float;
              force_oneshot, force_oneshot_enemy : bool;
              start_loop_with_n_oneshots : int;
              var num_shots_in_loop : int&;
              var sound_event : SoundEvent&;
              time_between_shots_mad : float2;
              var shot_loop_timeout : float&;
              gun__owner : EntityId;
              shot_path : Object;
              tags : Object)

  let isWatched = is_watched_gun_sound(gun__owner)
  if sound_event.enabled != isWatched
    abandon_shot_loop(sound_event)
    sound_event.enabled = isWatched

  let forceOneshot = isWatched ? force_oneshot : force_oneshot_enemy
  var isOneshot = forceOneshot || is_oneshot(gun, firing_mode)
  var isLoop = false

  // force N oneshots on loop start
  if !isOneshot && isWatched && start_loop_with_n_oneshots > 0
    if num_shots_in_loop == -1
      num_shots_in_loop = start_loop_with_n_oneshots
    if num_shots_in_loop > 0
      --num_shots_in_loop
      isOneshot = true

  if isOneshot
    abandon_shot_loop(sound_event)
    let path = make_gun_shot_sound_path_str(shot_path, tags, isWatched, true)
    var handle = sound_player_common::play_name_path(path, "", launch_pos, false/*is_abandon*/)
    set_occlusion_group(handle, gun_eid)
    if isWatched
      set_var_optional(handle, "mat", get_smid_from_gun_owner(gun__owner))
    abandon(handle)
  else
    isLoop = is_valid_handle_value(sound_event)
    if !is_valid_handle_value(sound_event)
      try_shot_loop(sound_event, launch_pos, shot_path, tags, isWatched)
    if is_valid_handle_value(sound_event)
      set_pos(sound_event, launch_pos)
      if isWatched
        set_var_optional(sound_event, "mat", get_smid_from_gun_owner(gun__owner))

  broadcastEvent(EventOnWeaponSound(pos = launch_pos, isLoop = isLoop))
  shot_loop_timeout = (time_between_shots * time_between_shots_mad.x + time_between_shots_mad.y)



[es(tag=sound, REQUIRE=gunSound)]
def gun_sound_on_shot(evt : EventShot;
                      eid : EntityId;
                      gun : Gun;
                      gun__timeBetweenShots : float = 0.;
                      gun_sound__forceOneshot : bool;
                      gun_sound__forceOneshotEnemy : bool;
                      gun_sound__startLoopWithNOneshots : int;
                      var gun_sound__numShotsInLoop : int&;
                      var gun_sound__event : SoundEvent&;
                      gun_sound__playerTimeBetweenShotsMad : float2;
                      var gun_sound__shotLoopTimeout : float&;
                      gun__owner : EntityId;
                      @shared_comp gun_sound__shotPath : Object;
                      sound_tags : Object;
                      gun_sound__isEnabled : bool;
                      sound_banks_state__isPresetLoaded : bool)
  if gun_sound__isEnabled && sound_banks_state__isPresetLoaded
    on_launch(eid,
              evt.launchDesc.tm[3],
              evt.launchDesc.firingMode,
              gun,
              gun__timeBetweenShots,
              gun_sound__forceOneshot,
              gun_sound__forceOneshotEnemy,
              gun_sound__startLoopWithNOneshots,
              gun_sound__numShotsInLoop,
              gun_sound__event,
              gun_sound__playerTimeBetweenShotsMad,
              gun_sound__shotLoopTimeout,
              gun__owner,
              gun_sound__shotPath,
              sound_tags)


[es(tag=sound, REQUIRE=gunSound)]
def gun_sound_on_net_shot(evt : CmdNetShot;
                          eid : EntityId;
                          gun : Gun;
                          gun__timeBetweenShots : float = 0.;
                          gun_sound__forceOneshot : bool;
                          gun_sound__forceOneshotEnemy : bool;
                          gun_sound__startLoopWithNOneshots : int;
                          var gun_sound__numShotsInLoop : int&;
                          var gun_sound__event : SoundEvent&;
                          gun_sound__netTimeBetweenShotsMad : float2;
                          var gun_sound__shotLoopTimeout : float&;
                          gun__owner : EntityId;
                          @shared_comp gun_sound__shotPath : Object;
                          sound_tags : Object;
                          gun_sound__isEnabled : bool;
                          sound_banks_state__isPresetLoaded : bool)
  if gun_sound__isEnabled && sound_banks_state__isPresetLoaded
    on_launch(eid,
              evt.tm[3],
              evt.firingMode,
              gun,
              gun__timeBetweenShots,
              gun_sound__forceOneshot,
              gun_sound__forceOneshotEnemy,
              gun_sound__startLoopWithNOneshots,
              gun_sound__numShotsInLoop,
              gun_sound__event,
              gun_sound__netTimeBetweenShotsMad,
              gun_sound__shotLoopTimeout,
              gun__owner,
              gun_sound__shotPath,
              sound_tags)


def is_shooting(gun_sound__shotLoopTimeout : float)
  return gun_sound__shotLoopTimeout > 0.

[es(tag=sound, REQUIRE=gunSound, after=sound_begin_update_es, before=sound_end_update_es)]
def gun_sound_update(info : ParallelUpdateFrameDelayed;
                     eid : EntityId;
                     animchar_bbox : bbox3f;
                     var gun_sound__shotLoopTimeout : float&;
                     var gun_sound__deltaTime : float4&;
                     var gun_sound__numShotsInLoop : int&;
                     var gun_sound__event : SoundEvent&;
                     gun_sound__isEnabled : bool;
                     sound_banks_state__isPresetLoaded : bool;
                     gun__overheat : float = 0.)

  if gun_sound__shotLoopTimeout > -1.
    set_occlusion_pos(eid, get_gun_sound_pos(animchar_bbox))

  if is_valid_handle_value(gun_sound__event)
    set_var_optional(gun_sound__event, "heat", gun__overheat)
    if !gun_sound__isEnabled || !sound_banks_state__isPresetLoaded || !is_shooting(gun_sound__shotLoopTimeout)
      abandon_shot_loop(gun_sound__event)
      //logerr("abandon gun_sound__event at {info.curTime} ---------------------------------")

  if gun_sound__numShotsInLoop != -1 && !is_shooting(gun_sound__shotLoopTimeout)
    gun_sound__numShotsInLoop = -1

  gun_sound__deltaTime.w = gun_sound__deltaTime.z
  gun_sound__deltaTime.z = gun_sound__deltaTime.y
  gun_sound__deltaTime.y = gun_sound__deltaTime.x
  gun_sound__deltaTime.x = info.dt
  gun_sound__shotLoopTimeout -= min(min(min(gun_sound__deltaTime.x, gun_sound__deltaTime.y), gun_sound__deltaTime.z), gun_sound__deltaTime.w)


def gun_sound_on_irq_impl(irq : string;
                          irq_type : uint;
                          animchar_bbox : bbox3f;
                          gun_sound__isEnabled : bool;
                          sound_banks_state__isPresetLoaded : bool;
                          gun__owner : EntityId;
                          sound_tags : Object;
                          @shared_comp sound_irqs : Object;
                          sound_max_irq_dist = 40.)
  if gun_sound__isEnabled && sound_banks_state__isPresetLoaded
    let isWatched = is_watched_gun_sound(gun__owner)
    if isWatched || should_play(get_gun_sound_pos(animchar_bbox), sound_max_irq_dist)
      query(gun__owner) <| $ [es] (var sound_event_group : SoundEventGroup&)
        let handle = sound_player_common::play_path(irq, sound_irqs, sound_tags, isWatched, get_gun_sound_pos(animchar_bbox), false)
        if is_valid_handle_value(handle)
          add_sound(sound_event_group, sound_hash(""), handle)
          if irq_type == sound_hash("matUnderFeet")
            set_var(handle, "mat", get_smid_from_gun_owner(gun__owner))


[es(tag=sound, REQUIRE=gunSound)]
def gun_sound_on_irq(evt : CmdSoundIrq;
                     animchar_bbox : bbox3f;
                     gun_sound__isEnabled : bool;
                     sound_banks_state__isPresetLoaded : bool;
                     gun__owner : EntityId;
                     sound_tags : Object;
                     @shared_comp sound_irqs : Object;
                     sound_max_irq_dist = 40.)
  gun_sound_on_irq_impl(evt.irq, evt.irqType, animchar_bbox, gun_sound__isEnabled, sound_banks_state__isPresetLoaded,
                        gun__owner, sound_tags, sound_irqs, sound_max_irq_dist)


[es(tag=sound, REQUIRE=gunSound)]
def gun_sound_on_irq_sim(evt : CmdSoundGenIrqSim;
                         animchar_bbox : bbox3f;
                         gun_sound__isEnabled : bool;
                         sound_banks_state__isPresetLoaded : bool;
                         gun__owner : EntityId;
                         sound_tags : Object;
                         @shared_comp sound_irqs : Object;
                         sound_max_irq_dist = 40.)
  gun_sound_on_irq_impl(evt.irq, sound_hash(""), animchar_bbox, gun_sound__isEnabled, sound_banks_state__isPresetLoaded,
                        gun__owner, sound_tags, sound_irqs, sound_max_irq_dist)


def gun_irq_sim(a, b : float;
                irqs : Array;
                gun__owner : EntityId;
                animchar_bbox : bbox3f;
                sound_tags : Object;
                is_watched : bool)
  for it in irqs
    let obj = get_ecs_object(it)
    let relPos = obj?.relPos ?? .0
    if relPos >= a && relPos < b
      query(gun__owner) <| $ [es] (var sound_event_group : SoundEventGroup&)
        let handle = sound_player_common::play_path(*obj, sound_tags, is_watched, get_gun_sound_pos(animchar_bbox), false)
        if is_valid_handle_value(handle)
          add_sound(sound_event_group, sound_hash(""), handle)
          if has(*obj, "matUnderFeet")
            set_var(handle, "mat", get_smid_from_gun_owner(gun__owner))


[es(tag=sound)]
def gun_bolt_action_sound_update(info : ParallelUpdateFrameDelayed&;
                                 gun : Gun&;
                                 var gun_bolt_action_sound__time : float&;
                                 @shared_comp gun_bolt_action_sound__irqs : Array;

                                 gun_sound__isEnabled : bool;
                                 sound_banks_state__isPresetLoaded : bool;
                                 sound_tags : Object;

                                 gun__owner : EntityId;
                                 animchar_bbox : bbox3f;
                                 sound_max_irq_dist = 40.)

  let cur = gun |> gun_lerpBoltActionTime(info.curTime)
  assume prev = gun_bolt_action_sound__time

  if prev == cur
    return

  if gun_sound__isEnabled && sound_banks_state__isPresetLoaded

    let isWatched = is_watched_gun_sound(gun__owner)
    if isWatched || should_play(get_gun_sound_pos(animchar_bbox), sound_max_irq_dist)

      if prev < cur
        gun_irq_sim(prev, cur, gun_bolt_action_sound__irqs, gun__owner, animchar_bbox, sound_tags, isWatched)
      else
        gun_irq_sim(prev, 2., gun_bolt_action_sound__irqs, gun__owner, animchar_bbox, sound_tags, isWatched)
        if cur > 0.
          gun_irq_sim(0., cur, gun_bolt_action_sound__irqs, gun__owner, animchar_bbox, sound_tags, isWatched)

  prev = cur



[es(tag=sound, track=sound_banks_state__isPresetLoaded, REQUIRE=gunSound)]
def gun_sound_toggle(evt : Event;
                     sound_banks_state__isPresetLoaded : bool;
                     var gun_sound__event : SoundEvent&)
  if !sound_banks_state__isPresetLoaded
    release_immediate(gun_sound__event)


[es(tag=sound, after=(animchar_before_render_es, sound_begin_update_es), before=sound_end_update_es)]
def gun_owner_sound_event_group_update(info : ParallelUpdateFrameDelayed;
                                       var gun_owner_sound_event_group : SoundEventGroup&)
  update_sounds(gun_owner_sound_event_group)
