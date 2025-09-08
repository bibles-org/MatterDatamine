require ecs
require app
require net
require game.events.events_active_matter
require game.events.events
require game.events.events_game
require DngHuman
require HumanPhys
require DagorMath
require math.base
require DagorMathUtils
require gameObject
require Dacoll
require game.es.ladder_common
require active_matter.game.es.moving_zone_common
require game.es.validation_common
require game.es.ecs_common
require DagorSystem

// client --------------------------------------------------------------

[es(tag=gameClient, after=(human_phys_es, before_net_phys_sync), before=after_net_phys_sync,
    REQUIRE=hero, REQUIRE_NOT=deadEntity)]
def human_es_near_ladder_update(act : CmdPostPhysUpdate;
                                human_ladder__attached : bool;
                                human_ladder__detached : bool;
                                human_ladder__pull : bool;
                                human_net_phys : HumanActor;
                                var human_ladder__nearToLadder : bool&;
                                var human_ladder__nearLadderTm : float3x4&;
                                var human_ladder__descent : bool&;
                                human_net_phys__ladderTracePos : float3 = float3(0, 1.6, 0);
                                human_net_phys__swimLadderTracePos : float3 = float3(0, 0.7, 0);
                                human_ladder__traceDist : float = 1.0f;
                                human_ladder__markerCheckDist : float = 3.0;
                                human_ladder__markerObserveAngle : float = PI / 8.)
  if human_ladder__attached || human_ladder__detached || human_ladder__pull
    human_ladder__nearToLadder = human_ladder__attached
    return

  human_ladder__nearToLadder = get_near_ladder(human_net_phys, human_ladder__nearLadderTm,
                                               human_ladder__descent, human_net_phys__ladderTracePos,
                                               human_net_phys__swimLadderTracePos,
                                               human_ladder__traceDist, human_ladder__markerCheckDist,
                                               human_ladder__markerObserveAngle)

// common --------------------------------------------------------------

[es(before=human_phys_es, REQUIRE_NOT=disableUpdate)]
def human_set_guided_by_ladder(act : CmdPostPhysUpdate; var human_net_phys : HumanActor)
  assume state = human_net_phys.phys.currentState
  state.guidedByLadder = state.isAttachedToLadder


[es(no_order)]
def on_use_ladder_request(evt : ReqAttachToLadder;
                          eid : EntityId;
                          transform : float3x4;
                          human_ladder__attached : bool;
                          human_ladder__detached : bool;
                          var human_ladder__pull : bool&;
                          var human_net_phys : HumanActor&;
                          human_ladder__maxUseDistance : float;
                          human_ladder__checkPlaceParams : float3;
                          human_ladder__weaponSwitchMultJump : float;
                          human_ladder__weaponSwitchMult : float;
                          human_to_ladder_animation__abortTime : float = 3.f;
                          var human_to_ladder_animation__wishPos : float3&;
                          var human_to_ladder_animation__wishGunOrient : float4&;
                          var human_to_ladder_animation__wishLookOrient : float4&;
                          var human_to_ladder_animation__ladderUp : float3&;
                          var human_to_ladder_animation__startTime : float&;
                          var human_to_ladder_animation__autoAbort : float&)
  if is_server() && (!is_client_value_in_distance(evt.wishPos, transform[3], 20.0) ||
    !is_client_value_valid(evt.wishGunOrient) ||
    !is_client_value_valid(evt.wishLookOrient) ||
    !is_client_value_valid(evt.ladderUp))
    logwarn("[LADDER] {get_entity_info(eid)}: client event validation failed! evt={evt}")
    return

  if human_ladder__attached || human_ladder__detached || human_ladder__pull
    return

  if !check_ladder_availability(human_net_phys, evt.wishPos, evt.ladderUp, human_ladder__maxUseDistance, human_ladder__checkPlaceParams)
    if is_server()
      send_net_event(eid, CmdDetachLadder())
    return

  sendEventImmediate(eid, EventInterruptItemUse())
  let isInAir = (int(human_net_phys.phys.currentState.isInAirHistory) & 1) != 0

  human_ladder__pull = true
  human_net_phys.phys.currentState.velocity = float3(0.0f)
  human_net_phys.phys.currentState.fasterChangeWeaponMult = isInAir ? human_ladder__weaponSwitchMultJump : human_ladder__weaponSwitchMult
  human_to_ladder_animation__wishPos = evt.wishPos
  human_to_ladder_animation__wishGunOrient = evt.wishGunOrient
  human_to_ladder_animation__wishLookOrient = evt.wishLookOrient
  human_to_ladder_animation__ladderUp = evt.ladderUp
  human_to_ladder_animation__startTime = -1.f
  human_to_ladder_animation__autoAbort = get_sync_time() + human_to_ladder_animation__abortTime

// unarmed effect ------------------------------------------------------

[es(track=(human_ladder__attached, human_ladder__detached, human_ladder__pull))]
def start_unarmed_effect(evt : Event;
                         eid : EntityId;
                         human_ladder__attached : bool;
                         human_ladder__detached : bool;
                         human_ladder__pull : bool;
                         var human_ladder__unarmedEffectEid : EntityId&)
  if human_ladder__attached || human_ladder__detached || human_ladder__pull
    if human_ladder__unarmedEffectEid == INVALID_ENTITY_ID
      human_ladder__unarmedEffectEid = createEntity("human_unarmed_on_ladder") <| $(var init)
        set(init, "game_effect__attachedTo", eid)
  elif human_ladder__unarmedEffectEid != INVALID_ENTITY_ID
    destroyEntity(human_ladder__unarmedEffectEid)
    human_ladder__unarmedEffectEid = INVALID_ENTITY_ID

// animation -----------------------------------------------------------

[es]
def start_ladder_anim_on_unarmed_set(evt : HumanEquipStateWeaponEquipped;
                                     human_ladder__pull : bool;
                                     var human_net_phys : HumanActor;
                                     var human_to_ladder_animation__startTime : float&)
  if human_ladder__pull && int(evt.slot) == int(HUWeaponSlots.EWS_UNARMED)
    human_to_ladder_animation__startTime = get_sync_time()
    human_net_phys.phys.currentState.fasterChangeWeaponMult = 1f


[es]
def auto_abort_pull_on_timeout(evt : CmdPostPhysUpdate;
                               eid : EntityId;
                               human_to_ladder_animation__autoAbort : float;
                               var human_ladder__pull : bool&;
                               var human_net_phys : HumanActor)
  if (human_ladder__pull && get_sync_time() > human_to_ladder_animation__autoAbort)
    human_ladder__pull = false
    human_net_phys.phys.currentState.fasterChangeWeaponMult = 1f
    logerr("[LADDER] pull was aborted for {get_entity_info(eid)} at {human_to_ladder_animation__autoAbort}")


[es(after=human_weapon_aim)]
def human_es_transfer_to_ladder(evt : CmdPostPhysUpdate;
                                eid : EntityId;
                                human_ladder__pull : bool;
                                human_to_ladder_animation__startTime : float;
                                human_to_ladder_animation__wishPos : float3;
                                human_to_ladder_animation__wishGunOrient : float4;
                                human_to_ladder_animation__ladderUp : float3;
                                human_ladder__animationVelocity : float;
                                var human_net_phys : HumanActor)
  if !human_ladder__pull
    return

  if human_to_ladder_animation__startTime < 0.f
    // not started yet
    return

  assume state = human_net_phys.phys.previousState

  let curPos = float3(state.location.P)
  let gunDirProj = normalize(state.gunDir - dot(state.gunDir, state.vertDirection) * state.vertDirection)
  let curOrient = dir_and_up_to_quat(gunDirProj, state.vertDirection)
  let wishOrient = quat(human_to_ladder_animation__wishGunOrient)
  let duration = get_to_ladder_anim_duration(curPos, human_to_ladder_animation__wishPos,
                                             curOrient, wishOrient, human_to_ladder_animation__ladderUp,
                                             human_ladder__animationVelocity)
  let interpK = float3(evt.dt / duration)

  let toLadderDir = (human_to_ladder_animation__wishPos - curPos -
                     human_to_ladder_animation__ladderUp * dot(human_to_ladder_animation__wishPos - curPos, human_to_ladder_animation__ladderUp))
  let path = length(toLadderDir) + abs(dot(human_to_ladder_animation__wishPos - curPos, human_to_ladder_animation__ladderUp))
  let pathK = length(toLadderDir) / path
  let pos = (interpK.x < pathK ? lerp(curPos, curPos + toLadderDir, saturate(interpK / pathK)) :
             lerp(curPos, human_to_ladder_animation__wishPos, saturate(interpK)))
  let q = slerp(curOrient, wishOrient, saturate(interpK.x))
  let curUp = state.vertDirection
  let wishUp = quat_get_up(wishOrient)
  let qUp = slerp(dir_to_quat(curUp), dir_to_quat(wishUp), saturate(interpK.x))

  if get_DAECS_EXTENSIVE_CHECKS() != 0
    validate_gameplay_position(pos) <| $()
      return <- "human_es_transfer_to_ladder
eid={get_entity_info(eid)}
interpK={interpK}
pathK={pathK}
curPos={curPos}
toLadderDir={toLadderDir}
human_to_ladder_animation__wishPos={human_to_ladder_animation__wishPos}
currentState.location.P={human_net_phys.phys.currentState.location.P}
currentState.velocity={human_net_phys.phys.currentState.velocity}"

  human_net_phys.phys.currentState.location.P = DPoint3(pos)
  human_net_phys.phys.currentState.velocity = float3(0.0f)
  human_net_phys.phys.currentState.gunDir = quat_get_forward(q)
  human_net_phys.phys.currentState.vertDirection = quat_get_forward(qUp)


[es(after=human_es_transfer_to_ladder)]
def human_es_attach_to_ladder(evt : CmdPostPhysUpdate;
                              eid : EntityId;
                              var human_ladder__pull : bool&;
                              human_to_ladder_animation__startTime : float;
                              human_to_ladder_animation__wishPos : float3;
                              human_to_ladder_animation__wishGunOrient : float4;
                              human_to_ladder_animation__ladderUp : float3;
                              human_ladder__animationVelocity : float;
                              human_net_phys : HumanActor)
  if !human_ladder__pull
    return

  assume state = human_net_phys.phys.previousState
  let curPos = float3(state.location.P)
  let gunDirProj = normalize(state.gunDir - dot(state.gunDir, state.vertDirection) * state.vertDirection)
  let curOrient = dir_and_up_to_quat(gunDirProj, state.vertDirection)
  let wishOrient = quat(human_to_ladder_animation__wishGunOrient)
  let duration = get_to_ladder_anim_duration(curPos, human_to_ladder_animation__wishPos,
                                             curOrient, wishOrient, human_to_ladder_animation__ladderUp,
                                             human_ladder__animationVelocity)

  if human_to_ladder_animation__startTime > 0.f && duration < evt.dt
    set_ladder_for_attach(eid)
    human_ladder__pull = false

// check detach --------------------------------------------------------

[es(on_event)]
def human_es_jump_from_ladder_update(evt : ReqJumpFromLadder;
                                     var human_net_phys : HumanActor;
                                     var human_ladder__attached : bool&;
                                     var human_ladder__detached : bool&;
                                     var human_ladder__pull : bool&;
                                     human_ladder__unarmedEffectEid : EntityId;
                                     human_ladder__ladderTm : float3x4;
                                     human_ladder__jumpSpeed : float;
                                     human_ladder__zeroAngleAdmit : float)
  if human_ladder__attached
    human_ladder__attached = false
    human_ladder__pull = false
    if human_ladder__unarmedEffectEid != INVALID_ENTITY_ID
      human_ladder__detached = true
    jump_from_ladder(human_net_phys, human_ladder__ladderTm,
                     human_ladder__jumpSpeed, human_ladder__zeroAngleAdmit)


[es(track=human_net_phys__isClimbing, before=human_pre_phys_ladder_update_es)]
def on_ladder_climb(evt : Event;
                    human_net_phys__isClimbing : bool;
                    human_ladder__unarmedEffectEid : EntityId;
                    var human_ladder__attached : bool&;
                    var human_ladder__detached : bool&;
                    var human_ladder__pull : bool&)
  if human_ladder__attached && human_net_phys__isClimbing
    human_ladder__attached = false
    human_ladder__pull = false
    if human_ladder__unarmedEffectEid != INVALID_ENTITY_ID
      human_ladder__detached = true


[es(on_event=(CmdDetachLadder, ReqDetachFromLadder))]
def on_detach_request(evt : Event;
                      human_ladder__unarmedEffectEid : EntityId;
                      var human_ladder__attached : bool&;
                      var human_ladder__detached : bool&;
                      var human_ladder__pull : bool&)
  human_ladder__attached = false
  human_ladder__pull = false
  if human_ladder__unarmedEffectEid != INVALID_ENTITY_ID
    human_ladder__detached = true


[es(REQUIRE=human_unarmed_on_ladder)]
def end_unarmed_state_on_landing_after_detach(evt : ParallelUpdateFrameDelayed;
                                              game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (human_net_phys : HumanActor;
                                            var human_ladder__detached : bool&)
    let isInAir = (int(human_net_phys.phys.currentState.isInAirHistory) & 1) != 0
    let isInWater = human_phys_state_get_is_swimming(human_net_phys.phys.currentState)
    let isClimbing = human_net_phys.phys.currentState |> human_phys_state_get_isClimbing
    if ((!isInAir || isInWater) && !isClimbing && human_ladder__detached)
      human_ladder__detached = false


[es(tag=gameClient, after=human_ladder_update_current,
    REQUIRE_NOT=deadEntity)]
def human_ladder_check_end(evt : CmdPostPhysUpdate;
                           eid : EntityId;
                           human_net_phys : HumanActor;
                           human_ladder__curLadderTm : float3x4;
                           human_ladder__ladderTm : float3x4)
  if human_net_phys.phys.currentState.isAttachedToLadder
    if distance_sq(human_ladder__curLadderTm[3], human_ladder__ladderTm[3]) < FLT_EPSILON
      let walkDir = dot(human_net_phys.phys.currentState.velocity, human_ladder__curLadderTm[1])
      let down = walkDir < 0.0f
      if down
        let itm = inverse(human_ladder__curLadderTm)
        let humanPos = float3(human_net_phys.phys.currentState.location.P)
        let localPos = itm * humanPos
        if localPos.y < IDENT_BBOX.boxMin.y
          assume standingHeight = human_net_phys.phys.standingHeight
          let localHeadPos = itm * (humanPos + standingHeight * normalize(human_ladder__curLadderTm[1]))
          if localHeadPos.y < IDENT_BBOX.boxMin.y
            send_net_event(eid, ReqDetachFromLadder())
        // trace ground
        let dir = -normalize(human_ladder__curLadderTm[1])
        let dist = 0.1f
        let from = humanPos - dir * dist
        if rayhit_normalized(from, dir, dist * 2.f, ETF_DEFAULT, -1)
          send_net_event(eid, ReqDetachFromLadder())


[es(tag=server)]
def human_ladder_check_detach_on_push(evt : CmdPostPhysUpdate;
                                      eid : EntityId;
                                      human_net_phys : HumanActor;
                                      human_ladder__maxImpulse : float;
                                      human_ladder__attached : bool;
                                      human_ladder__pull : bool)
  if human_ladder__attached || human_ladder__pull
    let impulse = length(human_net_phys.phys.currentState.velocity)
    if impulse > human_ladder__maxImpulse
      send_net_event(eid, CmdDetachLadder())

// markers spawn -------------------------------------------------------

// REQUIRE contains tag in ri_extra_gen__createEntityWhenDone template
[es(tag=server, REQUIRE=doorsGenerationDone, on_appear)] // works when all doors entities are created
def ladder_markers_spawn(evt : Event;
                         ladder_human_width : float = 0.25f;
                         ladder_template : string = "ladder_marker")
  find_query() <| $ [es] (game_objects : GameObjects)
    let templ = getTemplateByName(ladder_template)
    let traceDist = *templ |> getTemplateComponent("ladder_marker__traceDist") |> get_float() ?? 1.0

    let zone = get_current_moving_zone()
    let searchBox = BBox3(zone.pos, zone.radius * 2f)

    game_objects.ladders |> for_scene_game_objects(searchBox) <| $ [unused_argument(ni)] (ni : uint; ladder_tm : float3x4#)
      var tm = ladder_tm
      tm |> orthonormalize()
      let dir = tm[1]
      tm[3] += ladder_tm[1] / 2.0
      let norm = tm[0]
      let ladderWidth = length(ladder_tm[0]) * 2f + ladder_human_width
      tm[3] += norm * float3(ladderWidth)
      tm[0] = -norm
      tm[2] = -tm[2]
      var pos = tm[3]
      pos -= dir * traceDist / 2.
      if !rayhit_normalized(pos, dir, traceDist, ETF_ALL, -1) || check_door(tm * scale_tm(traceDist * dir))
        createEntity(ladder_template) <| $(var init : ComponentsInitializer)
          init |> set("transform", tm)
      else // check other side
        debug("Ladder could be bad in {ladder_tm[3]}. It hasn't markers.")
    return true

// state ---------------------------------------------------------------

[es(track=(human_ladder__attached, human_net_phys__isClimbing))]
def human_attach_and_climb_track(evt : Event;
                                 eid : EntityId;
                                 human_ladder__attached : bool;
                                 human_net_phys__isClimbing : bool;
                                 var human_on_ladder__animation : EntityId&)
  if human_ladder__attached && !human_net_phys__isClimbing
    human_on_ladder__animation = createEntity("human_on_ladder_animation") <| $(var init)
      set(init, "game_effect__attachedTo", eid)
  elif ((human_net_phys__isClimbing || !human_ladder__attached) &&
        human_on_ladder__animation != INVALID_ENTITY_ID)
    destroyEntity(human_on_ladder__animation)
    human_on_ladder__animation = INVALID_ENTITY_ID


[es(before=check_other_ladder)]
def human_ladder_update_current(evt : CmdPostPhysUpdate;
                                transform : float3x4;
                                human_net_phys : HumanActor;
                                human_anim__ladder__handToLegsOffset : float3&;
                                human_ladder__ladderTm : float3x4&;
                                human_ladder__numSteps : int;
                                var human_ladder__curLadderTm : float3x4&;
                                var human_ladder__curNumSteps : int&)
  if !human_net_phys.phys.currentState.isAttachedToLadder
    return
  if distance_sq(human_ladder__curLadderTm[3], human_ladder__ladderTm[3]) > FLT_EPSILON
    let checkedUp = normalize(human_ladder__ladderTm[1])
    let checkedDir = human_ladder__ladderTm[3] - transform[3]
    let dir = basis_aware_x0z(checkedDir, checkedUp)
    let pos = transform[3] + human_anim__ladder__handToLegsOffset + length(human_ladder__ladderTm[0]) * normalize(dir)
    if abs(inverse(human_ladder__ladderTm) * pos).y <= IDENT_BBOX.boxMax.y
      human_ladder__curLadderTm = human_ladder__ladderTm
      human_ladder__curNumSteps = human_ladder__numSteps


[es(after=after_net_phys_sync)]
def check_other_ladder(evt : CmdPostPhysUpdate;
                       var human_ladder__ladderTm : float3x4&;
                       human_ladder__curLadderTm : float3x4;
                       var human_ladder__numSteps : int&;
                       human_net_phys : HumanActor)
  let toNextLadder = human_ladder__ladderTm[3] - human_ladder__curLadderTm[3]
  let walkDir = dot(human_net_phys.phys.currentState.velocity, human_ladder__curLadderTm[1])
  if ((length_sq(toNextLadder) > FLT_EPSILON && (abs(walkDir) < FLT_EPSILON ||
      walkDir * dot(toNextLadder, human_ladder__curLadderTm[1]) >= 0.0f))
      || !human_net_phys.phys.currentState.isAttachedToLadder)
    return
  var humanTransform : float3x4
  location_toTM(human_net_phys.phys.currentState.location, humanTransform)
  let itm = inverse(human_ladder__curLadderTm)
  let ladderHeight = length(human_ladder__curLadderTm[1])
  assume standingHeight = human_net_phys.phys.standingHeight
  let localHeight = (itm * humanTransform[3]).y * ladderHeight
  let up = walkDir > 0.0f || (length_sq(toNextLadder) < FLT_EPSILON && abs(walkDir) < FLT_EPSILON)
  let down = walkDir < 0.0f
  if localHeight + standingHeight > ladderHeight / 2.0f && up
    human_ladder__ladderTm = human_ladder__curLadderTm
    let ladderUp = normalize(human_ladder__curLadderTm[1])
    let fromPos = human_ladder__curLadderTm * float3(0., IDENT_BBOX.boxMax.y, 0.) + 0.1f * ladderUp
    let toPos = fromPos + ladderUp * standingHeight
    find_ladder(fromPos, toPos, human_ladder__ladderTm, human_ladder__numSteps)
  elif localHeight < -ladderHeight / 2.0f && down // for better animation
    human_ladder__ladderTm = human_ladder__curLadderTm
    let ladderUp = normalize(human_ladder__curLadderTm[1])
    let fromPos = human_ladder__curLadderTm * float3(0., IDENT_BBOX.boxMin.y, 0.) - 0.1f * ladderUp
    let toPos = fromPos - ladderUp * standingHeight
    find_ladder(fromPos, toPos, human_ladder__ladderTm, human_ladder__numSteps)
