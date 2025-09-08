require ecs
require soundEvent
require sound_utils.modules.sound_player_common
require sound_utils.modules.sound_control_common
require danetlibs.renderer.includes.pufd_events
require math.base


[es(tag=sound, on_appear, after=init_mothman_floating_object_approach_from_pos_server)]
def init_mothman_floating_object_approach_from_pos_emit_sound(evt : Event;
                                                              floating_object_approach_from_pos__pos : float3;
                                                              floating_object__owner : EntityId)
  query(floating_object__owner) <| $ [es] (monstrified_mothman_gathering__objectAppearSound : string)
    oneshot(monstrified_mothman_gathering__objectAppearSound, floating_object_approach_from_pos__pos)


[es(tag=sound, on_event=CmdPlayMothmanIdleSound)]
def mothman_play_idle_sound(evt : Event;
                            transform : float3x4;
                            is_watched_sound : bool;
                            mothman_idle_sound__hero : string;
                            mothman_idle_sound__enemy : string)
  let event = is_watched_sound ? mothman_idle_sound__hero : mothman_idle_sound__enemy
  oneshot(event, transform[3])


[es(tag=sound, on_appear, REQUIRE=mothman_server_launched_object__attachedClientEntity)]
def mothman_attack_sound_enemy(evt : Event; floating_object__owner : EntityId; transform : float3x4)
  // hero launches client side prediction and plays sound at that time
  query(floating_object__owner) <| $ [es(REQUIRE_NOT=hero)] (is_watched_sound : bool;
                                                             mothman_attack_sound__hero : string;
                                                             mothman_attack_sound__enemy : string)
    let event = is_watched_sound ? mothman_attack_sound__hero : mothman_attack_sound__enemy
    oneshot(event, transform[3])


[es(tag=(sound, server, gameClient), on_appear, REQUIRE=mothman_server_launched_object__attachedClientEntity)]
def mothman_attack_sound_offline(evt : Event; floating_object__owner : EntityId; transform : float3x4)
  query(floating_object__owner) <| $ [es] (is_watched_sound : bool;
                                           mothman_attack_sound__hero : string;
                                           mothman_attack_sound__enemy : string)
    let event = is_watched_sound ? mothman_attack_sound__hero : mothman_attack_sound__enemy
    oneshot(event, transform[3])


[es(tag=sound, on_appear, REQUIRE=mothman_hero_client_prediction_launched_object)]
def mothman_attack_sound_watched(evt : Event; floating_object__owner : EntityId; transform : float3x4)
  query(floating_object__owner) <| $ [es(REQUIRE=hero)] (mothman_attack_sound__hero : string)
    oneshot(mothman_attack_sound__hero, transform[3])


[es(tag=sound, on_appear, track=sound_control__state)]
def mothman_flight_sound_init(evt : Event;
                              transform : float3x4;
                              mothman_flight_sound__pathHero : string;
                              mothman_flight_sound__pathEnemy : string;
                              sound_control__state : int;
                              var mothman_flight_sound__event : SoundEvent&)
  abandon(mothman_flight_sound__event)
  if have_sound(sound_control__state)
    assume eventPath = is_watched_sound_state(sound_control__state) ? mothman_flight_sound__pathHero : mothman_flight_sound__pathEnemy
    mothman_flight_sound__event |> play(eventPath, transform[3])


[es(tag=sound)]
def mothman_flight_sound_update(upd : ParallelUpdateFrameDelayed;
                                transform : float3x4;
                                human_net_phys__velocity : float3;
                                monster_flight_mode__speedSprint : float;
                                monster_flight_mode__isSprinting : bool;
                                monster_flight_sound__sprintSoundDampingViscosity : float;
                                sound_control__state : int;
                                mothman_flight_sound__event : SoundEvent&;
                                var mothman_flight_sound__sprintSoundValue : float&)
  if !have_sound(sound_control__state)
    mothman_flight_sound__sprintSoundValue = 0.0
    return

  if monster_flight_mode__isSprinting
    mothman_flight_sound__sprintSoundValue = 1.0
  else
    mothman_flight_sound__sprintSoundValue = approach(mothman_flight_sound__sprintSoundValue, 0.0, upd.dt, monster_flight_sound__sprintSoundDampingViscosity)

  set_pos(mothman_flight_sound__event, transform[3])
  let relSpeed = length(human_net_phys__velocity) / monster_flight_mode__speedSprint
  set_var(mothman_flight_sound__event, "speed", relSpeed)
  set_var(mothman_flight_sound__event, "dash", mothman_flight_sound__sprintSoundValue)
