require app
require ecs
require player
require DagorInput
require DagorMathUtils
require game.es.player_common
require game.events.input_events
require game.es.client.spectator_common
require game.events.events_active_matter


[es(on_appear)]
def spectator_appear_es(evt : Event; eid : EntityId; var spectator__target : EntityId&; spectator__teamId : int)
  if spectator__target != INVALID_ENTITY_ID
    set_spectated(eid, spectator__target, spectator__target, /*initial*/ true)
  else
    set_spectated(eid, spectator__target, find_next_spec_target(spectator__teamId, INVALID_ENTITY_ID, +1), /*initial*/ true)

[es(on_appear, REQUIRE_NOT=deadEntity)]
def spectators_update_on_hero_spawn(evt : Event;
                                    team : int;
                                    eid aka target_eid : EntityId;
                                    isSpectatable, countAsAlive, isAlive : bool)
  if isSpectatable && countAsAlive && isAlive
    query() <| $ [es] (eid aka camera_eid : EntityId; spectator__teamId : int; var spectator__target : EntityId&)
      if spectator__teamId == team && (spectator__target == INVALID_ENTITY_ID || !doesEntityExist(spectator__target))
        set_spectated(camera_eid, spectator__target, target_eid, /*initial*/ true)

[es(track=allowEnemiesToSpectate)]
def spectators_update_on_enemy_become_spectatable(evt : Event;
                                                  team : int;
                                                  allowEnemiesToSpectate : bool;
                                                  eid aka target_eid : EntityId;
                                                  isSpectatable, countAsAlive, isAlive : bool)
  if allowEnemiesToSpectate && isSpectatable && countAsAlive && isAlive
    query() <| $ [es] (eid aka camera_eid : EntityId; spectator__teamId : int; var spectator__target : EntityId&)
      if (spectator__teamId != team) && (spectator__target == INVALID_ENTITY_ID || !doesEntityExist(spectator__target))
        set_spectated(camera_eid, spectator__target, target_eid, /*initial*/ true)

[es(REQUIRE=spectator, on_disappear)]
def spectator_disappear_es(evt : Event; spectator__target : EntityId)
  if spectator__target != INVALID_ENTITY_ID && doesEntityExist(spectator__target)
    removeSubTemplate(spectator__target, "spectator_observed")

[es(tag=input, REQUIRE=fov)]
def spectator_bhv_es(evt : UpdateStageInfoAct;
                     spectator_input__aim : int;
                     var shooter_cam__alternative_settings : bool&;
                     camera__target : EntityId;
                     var spectator__ang : float2&;
                     var spectator__dir : float3&) : void
  shooter_cam__alternative_settings = true

  query(camera__target) <| $ [es] (var camera__lookDir : float3&)
    camera__lookDir = spectator__dir

  let aim = get_analog_stick_action_state(uint16(spectator_input__aim))
  spectator__ang += float2(aim.x * PI, aim.y * PI)
  spectator__ang.y = clamp(spectator__ang.y, -PI / 2. + 1e-3f, PI / 2. - 1e-3f)
  spectator__dir = angles_to_dir(spectator__ang)

[es(tag=input)]
def spectator_bhv_on_action_triggered_es(evt : EventDaInputActionTriggered;
                                         eid : EntityId;
                                         spectator_input__prev : int;
                                         spectator_input__next : int;
                                         spectator__teamId : int;
                                         spectator__changeTargetTime : float;
                                         var spectator__changeTargetAvaliableAt : float&;
                                         var spectator__target : EntityId&) : void
  let curTime = get_sync_time()
  if curTime < spectator__changeTargetAvaliableAt
    return
  spectator__changeTargetAvaliableAt = curTime + spectator__changeTargetTime
  if int(evt.action) == spectator_input__next
    let nextTarget : EntityId = find_next_spec_target(spectator__teamId, spectator__target, +1)
    set_spectated(eid, spectator__target, nextTarget)
  elif int(evt.action) == spectator_input__prev
    let nextTarget : EntityId = find_next_spec_target(spectator__teamId, spectator__target, -1)
    set_spectated(eid, spectator__target, nextTarget)

[es(on_appear, tag=input, before=spectator_appear_es)]
def spectator_init_es(evt : Event; team : int; var spectator__teamId : int&)
  spectator__teamId = team