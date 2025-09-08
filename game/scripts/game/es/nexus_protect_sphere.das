require ecs
require DngNet
require DngHuman
require DagorMath
require game.events.events
require game.es.player_common
require game.es.stat_bq_common
require game.es.nexus_common
require game.events.events_game
require game.events.events_active_matter
require game.utils.net_utils
require game.utils.team
require active_matter.game.es.nexus_round_mode_common


[es(on_appear)]
def nexus_protect_sphere_init(evt : Event;
                              eid : EntityId;
                              sphere_zone__radius : float;
                              nexus_protect_sphere__enemyClosestDistance : float;
                              nexus_protect_sphere__allyClosestDistance : float;
                              var nexus_protect_sphere__enemyRadiusSq : float&;
                              var nexus_protect_sphere__allyRadiusSq : float&;
                              nexus_protect_sphere__activeTemplate : string;
                              nexus_protect_sphere_active : Tag const?)
  let enemyRadius = sphere_zone__radius + nexus_protect_sphere__enemyClosestDistance
  let allyRadius = sphere_zone__radius - nexus_protect_sphere__allyClosestDistance
  nexus_protect_sphere__enemyRadiusSq = enemyRadius * enemyRadius
  nexus_protect_sphere__allyRadiusSq = allyRadius * allyRadius

  if nexus_protect_sphere_active == null
    remote_add_sub_template(eid, nexus_protect_sphere__activeTemplate)

/*
[es(tag=gameClient, REQUIRE=nexus_player, track=team, on_appear)]
def nexus_warm_up_change_color_of_protection_spheres_on_player_team_change(evt : Event
                                                                           team : int)
  query() <| $ [es] (nexus_protect_sphere__team : int
                     nexus_protect_sphere__allyCollor : float4
                     nexus_protect_sphere__enemyCollor : float4
                     var forcefield__color : float4&)
    if nexus_protect_sphere__team == team
      forcefield__color = nexus_protect_sphere__allyCollor
    else
      forcefield__color = nexus_protect_sphere__enemyCollor

[es(tag=gameClient, on_appear)]
def nexus_protect_sphere_change_color_on_sphere_appear(evt : Event
                                                       nexus_protect_sphere__team : int
                                                       nexus_protect_sphere__allyCollor : float4
                                                       nexus_protect_sphere__enemyCollor : float4
                                                       var forcefield__color : float4&)
  query(get_local_player_eid()) <| $ [es] (team : int)
    if nexus_protect_sphere__team == team
      forcefield__color = nexus_protect_sphere__allyCollor
    else
      forcefield__color = nexus_protect_sphere__enemyCollor
*/

[es(REQUIRE=nexus_militant, REQUIRE_NOT=disableUpdate, no_order)]
def nexus_protect_sphere_update(update : CmdPostPhysUpdate;
                                team aka human_team : int;
                                var human_net_phys : HumanActor)
  query() <| $ [es(REQUIRE=nexus_protect_sphere_active)] (transform : float3x4;
                                                          sphere_zone__radius : float;
                                                          nexus_protect_sphere__enemyRadiusSq : float;
                                                          nexus_protect_sphere__allyRadiusSq : float;
                                                          nexus_protect_sphere__enemyClosestDistance : float;
                                                          nexus_protect_sphere__allyClosestDistance : float;
                                                          nexus_protect_sphere__deltaToPush : float;
                                                          nexus_protect_sphere__team : int;
                                                          nexus_protect_sphere_allow_allies_to_exit : Tag const?)
    let humanPos = float3(human_net_phys.phys.currentState.location.P)
    let spherePos = transform[3]
    let vector = humanPos - spherePos
    let distSq = length_sq(vector)
    let isAlly = human_team == nexus_protect_sphere__team
    if isAlly && nexus_protect_sphere_allow_allies_to_exit == null
      let outsideSphere = distSq >= nexus_protect_sphere__allyRadiusSq
      if outsideSphere
        let newPos = spherePos + normalize(vector) * (sphere_zone__radius - nexus_protect_sphere__allyClosestDistance - nexus_protect_sphere__deltaToPush)
        human_net_phys.phys.currentState.location.P = DPoint3(newPos)
      return

    if !isAlly
      let insideSphere = distSq <= nexus_protect_sphere__enemyRadiusSq
      if insideSphere
        let newPos = spherePos + normalize(vector) * (sphere_zone__radius + nexus_protect_sphere__enemyClosestDistance + nexus_protect_sphere__deltaToPush)
        human_net_phys.phys.currentState.location.P = DPoint3(newPos)


[es(tag=server)]
def nexus_auto_create_protection_spheres(evt : EventNexusWarmUpStarted;
                                         nexus_auto_create_protect_spheres__radius : float;
                                         nexus_auto_create_protect_spheres__template : string)
  let protectionSpheresAlreadyExists = find_query() <| $ [es(REQUIRE=nexus_protect_sphere)] () => true
  if protectionSpheresAlreadyExists
    nexus_logerr("Protection spheres already exists (Remove them from scene or remove nexus_auto_create_protect_spheres to avoid auto creation of protect spheres)")
    return

  query() <| $ [es(REQUIRE=respbase)] (team : int;
                                       transform : float3x4)
    let protectionSphereEid = createEntity(nexus_auto_create_protect_spheres__template) <| $(var init)
      set(init, "nexus_protect_sphere__team", team)
      set(init, "transform", transform)
      set(init, "sphere_zone__radius", nexus_auto_create_protect_spheres__radius)
    nexus_log("Created protection sphere <{protectionSphereEid}> (team={team}; position={transform[3]}; radius={nexus_auto_create_protect_spheres__radius})")


[es(tag=server, REQUIRE_NOT=nexus_protect_sphere_active)]
def nexus_protection_sphere_enable(evt : EventNexusEnableProtectSpheres;
                                   eid : EntityId;
                                   nexus_protect_sphere__activeTemplate : string)
  remote_add_sub_template(eid, nexus_protect_sphere__activeTemplate)


[es(tag=server, on_appear)]
def nexus_protect_sphere_create_hint_trigger(evt : Event;
                                             transform : float3x4;
                                             sphere_zone__radius : float;
                                             nexus_protect_sphere__hintSphereTemplate : string)
  createEntity(nexus_protect_sphere__hintSphereTemplate) <| $(var init)
    set(init, "transform", transform)
    set(init, "sphere_zone__radius", max(0.1, sphere_zone__radius - 1.7))


[es(tag=server, REQUIRE=nexus_show_sphere_hint_processor)]
def nexus_protection_sphere_hint_disable(evt : EventNexusDisableProtectSpheres;
                                         eid : EntityId)
  destroyEntity(eid)


[es(tag=server)]
def nexus_protection_sphere_hint_enable(evt : EventNexusEnableProtectSpheres)
  createEntity("nexus_show_sphere_hint_processor")


[es(tag=server, REQUIRE=nexus_protect_sphere_active)]
def nexus_protection_sphere_disable(evt : EventNexusDisableProtectSpheres;
                                    eid : EntityId;
                                    nexus_protect_sphere__activeTemplate : string)
  remote_remove_sub_template(eid, nexus_protect_sphere__activeTemplate)


[es(tag=gameClient, on_appear, on_event=(EventNexusRoundModeRoundChange, EventNexusGameStart), after=nexus_round_mode_start)]
def nexus_protection_sphere_init_fadeout(evt : Event;
                                         nexus_protect_sphere_fadeout__createEffectsInTimeBeforeStart : float;
                                         var nexus_protect_sphere_fadeout__createEffectsAt : float&)
  find_query() <| $ [es] (nexus_round_mode_game_controller__roundStateEndAt : float; nexus_round_mode_game_controller__roundState : int)
    if nexus_round_mode_game_controller__roundState != int(NexusRoundState.Preparation)
      nexus_protect_sphere_fadeout__createEffectsAt = -1.0
      return false

    nexus_protect_sphere_fadeout__createEffectsAt = nexus_round_mode_game_controller__roundStateEndAt - nexus_protect_sphere_fadeout__createEffectsInTimeBeforeStart
    return true


[es(tag=gameClient, track=nexus_round_mode_game_controller__roundState)]
def nexus_protection_sphere_init_fadeout_on_round_state_change(evt : Event;
                                                               nexus_round_mode_game_controller__roundState : int;
                                                               nexus_round_mode_game_controller__roundStateEndAt : float)
  if nexus_round_mode_game_controller__roundState != int(NexusRoundState.Preparation)
    return

  query() <| $ [es] (nexus_protect_sphere_fadeout__createEffectsInTimeBeforeStart : float; var nexus_protect_sphere_fadeout__createEffectsAt : float&)
    nexus_protect_sphere_fadeout__createEffectsAt = nexus_round_mode_game_controller__roundStateEndAt - nexus_protect_sphere_fadeout__createEffectsInTimeBeforeStart


[es(tag=gameClient, no_order)]
def nexus_protection_sphere_create_fadeout_effects(upd : ParallelUpdateFrameDelayed;
                                                   eid : EntityId;
                                                   nexus_protect_sphere_fadeout__effectTemplates : StringList;
                                                   var nexus_protect_sphere_fadeout__createEffectsAt : float&;
                                                   var nexus_protect_sphere_fadeout__effects : EidList)
  if nexus_protect_sphere_fadeout__createEffectsAt < 0.0 || upd.curTime < nexus_protect_sphere_fadeout__createEffectsAt
    return

  if !empty(nexus_protect_sphere_fadeout__effects)
    return

  for effectTemplate in nexus_protect_sphere_fadeout__effectTemplates
    let newEffect = createEntity(string(effectTemplate)) <| $(var init)
      set(init, "game_effect__attachedTo", eid)
    push(nexus_protect_sphere_fadeout__effects, newEffect)

  nexus_protect_sphere_fadeout__createEffectsAt = -1.0


[es(tag=gameClient, on_disappear)]
def nexus_protection_sphere_deinit_fadeout(evt : Event;
                                           nexus_protect_sphere_fadeout__effects : EidList)
  for effectEid in nexus_protect_sphere_fadeout__effects
    destroyEntity(effectEid)


[es(tag=gameClient, no_order)]
def nexus_protection_sphere_update_fadeout(upd : ParallelUpdateFrameDelayed;
                                           nexus_protect_sphere_fadeout__abberationStrength : float;
                                           nexus_protect_sphere_fadeout__targetAbberationShift : float4;
                                           var forcefield__aberrationShift : float4&)
  forcefield__aberrationShift = nexus_protect_sphere_fadeout__targetAbberationShift * nexus_protect_sphere_fadeout__abberationStrength
