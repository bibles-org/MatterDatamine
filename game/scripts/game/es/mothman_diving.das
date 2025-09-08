require ecs
require ecs.common
require ecs.safe
require app
require math.base
require game.events.events
require game.events.events_game
require game.events.events_active_matter
require game.es.ability_common
require game.es.ability_enums_common
require game.es.teleport_common
require DngNet
require DngHuman
require DagorMath
require Grid


[es(on_appear)]
def mothman_diving_grab_ability_on_appear(evt : Event;
                                          hero_ability__abilities : Array;
                                          var mothman_diving_grab_ability__abilityIdx : int&)
  mothman_diving_grab_ability__abilityIdx = get_ability_index_by_name(hero_ability__abilities, "mothman_grab_enemy")


[es(tag=server, on_appear, REQUIRE=deadEntity)]
def mothman_diving_grab_ability_cancel_on_death(evt : Event;
                                                eid aka mothman_eid : EntityId;
                                                mothman_diving_grab_ability__abilityIdx : int)
  send_net_event(mothman_eid, RqCancelAbility(idx = mothman_diving_grab_ability__abilityIdx))


[es(tag=server, track=mothman_diving_grab_ability__state)]
def mothman_diving_grab_ability_track_state_server(evt : Event;
                                                   eid aka mothman_eid : EntityId;
                                                   mothman_diving_grab_ability__state : int;
                                                   mothman_diving_grab_ability__abilityIdx : int;
                                                   mothman_diving_grab_ability__potentialTargetEid : EntityId;
                                                   mothman_diving_grab_ability__targetStunAffectTemplate : string;
                                                   mothman_diving_grab_ability__targetAffectTemplate : string;
                                                   var mothman_diving_grab_ability__targetEid : EntityId&;
                                                   var mothman_diving_grab_ability__targetAffectEid : EntityId&;
                                                   var mothman_diving_grab_ability__targetStunAffectEid : EntityId&)
  if mothman_diving_grab_ability__state == int(MothmanDivingGrabState.NONE)
    mothman_diving_grab_ability__targetEid = INVALID_ENTITY_ID
  elif mothman_diving_grab_ability__state == int(MothmanDivingGrabState.GRABBING)
    var isTargetValid = false

    query(mothman_diving_grab_ability__potentialTargetEid) <| $ [es(REQUIRE_NOT=deadEntity, REQUIRE=human_net_phys)] ()
      // TODO: Validate target (distance, etc)
      isTargetValid = true

    if isTargetValid
      mothman_diving_grab_ability__targetEid = mothman_diving_grab_ability__potentialTargetEid
    else
      send_net_event(eid, RqCancelAbility(idx = mothman_diving_grab_ability__abilityIdx))
      mothman_diving_grab_ability__targetEid = INVALID_ENTITY_ID


  // Target affect
  let targetAffectRequired = (mothman_diving_grab_ability__state != int(MothmanDivingGrabState.NONE))
  let targetAffectExists = doesEntityExist(mothman_diving_grab_ability__targetAffectEid)

  if targetAffectRequired && !targetAffectExists
    mothman_diving_grab_ability__targetAffectEid = createEntity(mothman_diving_grab_ability__targetAffectTemplate) <| $(var init : ComponentsInitializer)
      init |> set("game_effect__attachedTo", mothman_diving_grab_ability__targetEid)
      init |> set("game_effect__ownerEid", mothman_eid)
  elif !targetAffectRequired && targetAffectExists
    destroyEntity(mothman_diving_grab_ability__targetAffectEid)


  // Target stun affect
  // let targetStunAffectRequired = mothman_diving_grab_ability__state == int(MothmanDivingGrabState.FLIGHT) || mothman_diving_grab_ability__state == int(MothmanDivingGrabState.HOLD)
  let targetStunAffectRequired = (mothman_diving_grab_ability__state != int(MothmanDivingGrabState.NONE))
  let targetStunAffectExists = doesEntityExist(mothman_diving_grab_ability__targetStunAffectEid)

  if targetStunAffectRequired && !targetStunAffectExists
    mothman_diving_grab_ability__targetStunAffectEid = createEntity(mothman_diving_grab_ability__targetStunAffectTemplate) <| $(var init : ComponentsInitializer)
      init |> set("game_effect__attachedTo", mothman_diving_grab_ability__targetEid)
      init |> set("game_effect__ownerEid", mothman_eid)
  elif !targetStunAffectRequired && targetStunAffectExists
    destroyEntity(mothman_diving_grab_ability__targetStunAffectEid)


[es(track=mothman_diving_grab_ability__state)]
def mothman_diving_grab_ability_track_state(evt : Event;
                                            human_net_phys : HumanActor;
                                            mothman_diving_grab_ability__state : int;
                                            var monster_flight_mode__forceVelocity : float3&;
                                            var monster_flight_mode__forceVelocityEnabled : bool&)
  assume phys = human_net_phys.phys
  assume curState = phys.currentState

  let forceVelocityEnabled = (mothman_diving_grab_ability__state != int(MothmanDivingGrabState.NONE))

  if forceVelocityEnabled && !monster_flight_mode__forceVelocityEnabled
    monster_flight_mode__forceVelocityEnabled = true
    monster_flight_mode__forceVelocity = curState.velocity
  elif !forceVelocityEnabled && monster_flight_mode__forceVelocityEnabled
    monster_flight_mode__forceVelocityEnabled = false


[es(tag=server, on_appear)]
def monstrified_diving_mothman_grab_enemy_affect_state(evt : Event;
                                                       game_effect__attachedTo : EntityId;
                                                       monstrified_diving_mothman_grab_enemy_affect_state__state : int)
  query(game_effect__attachedTo) <| $ [es] (var mothman_diving_grab_ability__state : int&)
    assume state = monstrified_diving_mothman_grab_enemy_affect_state__state
    mothman_diving_grab_ability__state = state


[es(REQUIRE=monstrified_diving_mothman_grab_enemy_affect_flight,
  before=human_first_contact_dispatcher,
  before=monster_freeflight_mode)]
def monstrified_diving_mothman_grab_enemy_affect_flight(act : UpdateStageInfoAct;
                                                        game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (human_net_phys : HumanActor;
                                            mothman_diving_grab_ability__flightVelocity : float;
                                            mothman_diving_grab_ability__flightAcc : float;
                                            var monster_flight_mode__forceVelocity : float3&)
    assume flightVelocity = mothman_diving_grab_ability__flightVelocity
    assume flightAcc = mothman_diving_grab_ability__flightAcc

    let flighthVelocity = flightVelocity * human_net_phys.phys.currentState.vertDirection
    monster_flight_mode__forceVelocity = lerp(monster_flight_mode__forceVelocity, flighthVelocity,
                                              saturate(flightAcc * act.dt))


[es]
def mothman_diving_grab_ability_validate_prereqs(var evt : ValidateAbilityPrereqs;
                                                 mothman_diving_grab_ability__potentialTargetEid : EntityId)
  if mothman_diving_grab_ability__potentialTargetEid == INVALID_ENTITY_ID
    evt.canUseAbility = false


[es(tag=gameClient)]
def mothman_diving_grab_ability_prepare_client(var evt : PreRqUseAbility;
                                               eid aka mothman_eid : EntityId;
                                               mothman_diving_grab_ability__potentialTargetEid : EntityId)
  send_net_event(mothman_eid, MothmanGrabAbilityPrepare(targetEid = mothman_diving_grab_ability__potentialTargetEid))


[es(tag=server)]
def mothman_diving_grab_ability_prepare_server(evt : MothmanGrabAbilityPrepare;
                                               var mothman_diving_grab_ability__potentialTargetEid : EntityId&)
  mothman_diving_grab_ability__potentialTargetEid = evt.targetEid


[es(after=monster_freeflight_mode, before=human_phys_es)]
def mothman_diving_grab_ability_phys_update_server(evt : CmdPostPhysUpdate;
                                                   mothman_diving_grab_ability__targetEid : EntityId;
                                                   mothman_diving_grab_ability__grabOffset : float3;
                                                   mothman_diving_grab_ability__state : int;
                                                   mothman_diving_grab_ability__flightVelocity : float;
                                                   mothman_diving_grab_ability__flightAcc : float;
                                                   mothman_diving_grab_ability__grabVelocity : float = 12.0;
                                                   mothman_diving_grab_ability__grabVelocityGrabbingMult : float = 0.666;
                                                   human_net_phys aka mothman_human_net_phys : HumanActor;
                                                   var monster_flight_mode__forceVelocity : float3&)
  assume grabOffset = mothman_diving_grab_ability__grabOffset
  assume flightVelocity = mothman_diving_grab_ability__flightVelocity

  var flightAcc = mothman_diving_grab_ability__flightAcc

  query(mothman_diving_grab_ability__targetEid) <| $ [es] (var human_net_phys aka target_human_net_phys : HumanActor)
    var targetFlightVelocity : float3

    var locationTm : float3x4
    location_toTM(mothman_human_net_phys.phys.currentState.location, locationTm)

    if mothman_diving_grab_ability__state == int(MothmanDivingGrabState.FLIGHT)
      targetFlightVelocity = flightVelocity * human_net_phys.phys.currentState.vertDirection
    elif mothman_diving_grab_ability__state == int(MothmanDivingGrabState.GRABBING)
      let backAwayDir =  normalize(-locationTm[0] + locationTm[1] * 1.5)
      targetFlightVelocity = backAwayDir * 4.0
    elif mothman_diving_grab_ability__state == int(MothmanDivingGrabState.HOLD)
      flightAcc *= 2.0 // Accelerated braking


    monster_flight_mode__forceVelocity = lerp(monster_flight_mode__forceVelocity, targetFlightVelocity,
                                              saturate(flightAcc * evt.dt))

    let grabPos = locationTm[3] + locationTm[0] * grabOffset.x + locationTm[1] * grabOffset.y + locationTm[2] * grabOffset.z

    target_human_net_phys.phys.currentState.velocity += gravity() * target_human_net_phys.phys.currentState.vertDirection * evt.dt

    let toGrabPos = grabPos - float3(target_human_net_phys.phys.currentState.location.P)
    let toGrabPosDistSq = length_sq(toGrabPos)
    if toGrabPosDistSq > 1e-5
      let toGrabPosDist = sqrt(toGrabPosDistSq)
      let toGrabPosDir = toGrabPos / toGrabPosDist

      var velocityMult = mothman_diving_grab_ability__grabVelocity
      if mothman_diving_grab_ability__state == int(MothmanDivingGrabState.GRABBING)
        velocityMult *= mothman_diving_grab_ability__grabVelocityGrabbingMult

      target_human_net_phys.phys.currentState.velocity = lerp(
        target_human_net_phys.phys.currentState.velocity,
        toGrabPosDir * (sqrt(toGrabPosDist) * velocityMult), 8.0 * evt.dt)

    target_human_net_phys.phys.currentState.moveState = HUMoveState.EMS_STAND


[es(REQUIRE=mothman_diving_grab_ability_target_affect, no_order)]
def mothman_diving_grab_ability_target_affect_update(act : UpdateStageInfoAct;
                                                     eid aka affect_eid : EntityId;
                                                     game_effect__attachedTo : EntityId;
                                                     game_effect__ownerEid : EntityId;
                                                     mothman_diving_grab_ability_target_affect__releaseSpeed : float;
                                                     var mothman_diving_grab_ability_target_affect__releaseProgress : float&)
  assume releaseSpeed = mothman_diving_grab_ability_target_affect__releaseSpeed
  assume releaseProgress = mothman_diving_grab_ability_target_affect__releaseProgress

  query(game_effect__ownerEid) <| $ [es] (mothman_diving_grab_ability__abilityIdx : int)
    query(game_effect__attachedTo) <| $ [es] (human_net_phys : HumanActor)
      assume phys = human_net_phys.phys
      assume ct = phys.appliedCT

      let isReleaseInput = is_control_bit_set(ct, HumanPhysControlType.HCT_JUMP)

      let releaseProgressDelta = releaseSpeed * act.dt * (isReleaseInput ? 1.0 : -1.0)
      releaseProgress = max(0.0, releaseProgress + releaseProgressDelta)
      if releaseProgress >= 1.0
        releaseProgress = 1.0
        if is_server()
          send_net_event(game_effect__ownerEid, RqCancelAbility(idx = mothman_diving_grab_ability__abilityIdx))
          destroyEntity(affect_eid)
