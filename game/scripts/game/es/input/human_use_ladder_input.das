require ecs
require net
require game.events.input_events
require game.events.events
require game.events.events_active_matter
require game.events.events_game
require DngHuman
require HumanPhys
require DagorMath
require DagorMathUtils
require math.base
require daslib/algorithm
require game.es.use_query_params_common
require game.utils.hero
require game.es.transform_common
require game.es.ladder_common
require DagorInput

// show hud ------------------------------------------------------------

[es(tag=input, after=(human_use_action_es, on_human_ladder__attached_changed),
    track=human_ladder__nearToLadder, REQUIRE=watchedByPlr)]
def on_human_ladder__nearToLadder_changed(evt : Event;
                                          human_inventory__entityToUse : EntityId;
                                          human_ladder__nearToLadder : bool;
                                          human_ladder__attached : bool;
                                          human_ladder__attachHint : string;
                                          human_ladder__detachHint : string;
                                          human_net_phys : HumanActor;
                                          human_ladder__nearLadderTm : float3x4;
                                          human_ladder__descent : bool;
                                          human_ladder__closeDist : float;
                                          human_ladder__closeAngle : float)
  if human_ladder__nearToLadder && !human_ladder__attached
    let autoAttach = (human_inventory__entityToUse == INVALID_ENTITY_ID
                   && in_front_of_ladder(human_net_phys, human_ladder__nearLadderTm, human_ladder__closeDist, human_ladder__closeAngle))
    if human_ladder__descent || !autoAttach
      createEntity("ladder_hint") <| $(var init)
        init |> set("item__setCustomUsePrompt", human_ladder__attachHint)
  elif human_ladder__nearToLadder && human_ladder__attached
    createEntity("ladder_hint") <| $(var init)
      init |> set("item__setCustomUsePrompt", human_ladder__detachHint)
  else
    find_query() <| $ [es(REQUIRE=human_ladder__hint)] (eid aka hint_eid : EntityId)
      destroyEntity(hint_eid)
      return true


[es(tag=input, after=human_es_near_ladder_update, REQUIRE=hero)]
def auto_attach_to_ladder(evt : CmdPostPhysUpdate;
                          eid : EntityId;
                          human_inventory__entityToUse : EntityId;
                          human_net_phys : HumanActor;
                          human_net_phys__isSwimming : bool;
                          human_ladder__nearLadderTm : float3x4;
                          human_ladder__nearToLadder : bool;
                          human_ladder__attached : bool;
                          human_ladder__descent : bool;
                          human_ladder__closeDist : float;
                          human_ladder__closeAngle : float;
                          human_net_phys__ladderTracePos : float3 = float3(0, 1.6, 0);
                          human_net_phys__swimLadderTracePos : float3 = float3(0, 0.7, 0))
  if human_ladder__nearToLadder && !human_ladder__attached && !human_ladder__descent
    if human_inventory__entityToUse == INVALID_ENTITY_ID && in_front_of_ladder(human_net_phys, human_ladder__nearLadderTm, human_ladder__closeDist, human_ladder__closeAngle)
      request_attach_to_ladder(human_ladder__descent, human_ladder__nearLadderTm, human_net_phys, eid,
        human_net_phys__isSwimming ? human_net_phys__swimLadderTracePos : human_net_phys__ladderTracePos)


[es(tag=input, after=human_use_action_es, track=human_ladder__attached, REQUIRE=watchedByPlr)]
def on_human_ladder__attached_changed(evt : Event;
                                      human_ladder__attached : bool;
                                      human_ladder__attachHint : string;
                                      human_ladder__detachHint : string)
  find_query() <| $ [es(REQUIRE=human_ladder__hint)] (var item__setCustomUsePrompt : das_string&)
    item__setCustomUsePrompt := human_ladder__attached ? human_ladder__detachHint : human_ladder__attachHint
    return true


[es(tag=gameClient, REQUIRE=watchedByPlr)]
def human_es_ladder_destroy_hint_on_death(evt : EventEntityDied)
  query() <| $ [es(REQUIRE=human_ladder__hint)] (eid aka hint_eid : EntityId)
    destroyEntity(hint_eid)

// control input -------------------------------------------------------

[es(on_event, tag=gameClient, REQUIRE=human_ladder__hint)]
def human_es_ladder_cmd_resend(evt : CmdUse)
  query(evt.requesterEid) <| $ [es] (human_ladder__attached : bool;
                                     human_ladder__nearToLadder : bool;
                                     human_net_phys : HumanActor;
                                     human_ladder__nearLadderTm : float3x4;
                                     human_ladder__descent : bool;
                                     human_net_phys__isSwimming : bool;
                                     human_net_phys__ladderTracePos : float3 = float3(0, 1.6, 0);
                                     human_net_phys__swimLadderTracePos : float3 = float3(0, 0.7, 0))
    if human_ladder__attached
      send_net_event(evt.requesterEid, ReqDetachFromLadder())
    elif human_ladder__nearToLadder
      request_attach_to_ladder(human_ladder__descent, human_ladder__nearLadderTm, human_net_phys, evt.requesterEid,
        human_net_phys__isSwimming ? human_net_phys__swimLadderTracePos : human_net_phys__ladderTracePos)


[es(on_event, tag=gameClient)]
def human_es_ladder_request_resend(evt : HumanUseObjectRequest;
                                   eid : EntityId;
                                   human_ladder__attached : bool;
                                   human_ladder__nearToLadder : bool;
                                   human_net_phys : HumanActor;
                                   human_ladder__nearLadderTm : float3x4;
                                   human_ladder__descent : bool;
                                   human_net_phys__isSwimming : bool;
                                   human_net_phys__ladderTracePos : float3 = float3(0, 1.6, 0);
                                   human_net_phys__swimLadderTracePos : float3 = float3(0, 0.7, 0))
  if evt.objectEid |> has("human_ladder__hint")
    if human_ladder__attached
      send_net_event(eid, ReqDetachFromLadder())
    elif human_ladder__nearToLadder
      request_attach_to_ladder(human_ladder__descent, human_ladder__nearLadderTm, human_net_phys, eid,
        human_net_phys__isSwimming ? human_net_phys__swimLadderTracePos : human_net_phys__ladderTracePos)


[es(on_event, tag=gameClient)]
def human_es_ladder_detach_jump(evt : EventDaInputActionTriggered;
                                eid : EntityId;
                                human_input__jump : int&;
                                human_ladder__attached : bool)
  if (int(evt.action) == human_input__jump) && human_ladder__attached
    send_net_event(eid, ReqJumpFromLadder())

// pull ----------------------------------------------------------------

[es(tag=gameClient, after=(human_look_dir_camera_es, human_es_transfer_to_ladder), REQUIRE=watchedByPlr)]
def human_es_transfer_to_ladder_update_camera(info : ParallelUpdateFrameDelayed;
                                              human_ladder__pull : bool;
                                              human_to_ladder_animation__startTime : float;
                                              human_to_ladder_animation__wishLookOrient : float4;
                                              human_to_ladder_animation__wishGunOrient : float4;
                                              human_to_ladder_animation__wishPos : float3;
                                              human_to_ladder_animation__ladderUp : float3;
                                              human_ladder__animationVelocity : float;
                                              human_net_phys__prevRootDir : float3;
                                              human_net_phys__prevVertDir : float3;
                                              var human_net_phys : HumanActor;
                                              var human_input__aimAngle : float2&)
  if !human_ladder__pull
    return

  if human_to_ladder_animation__startTime < 0.f
    // not started yet
    return

  assume state = human_net_phys.phys.currentState

  let curPos = float3(state.location.P)
  let gunDirProj = normalize(state.gunDir - dot(state.gunDir, state.vertDirection) * state.vertDirection)
  let curOrient = dir_and_up_to_quat(gunDirProj, state.vertDirection)
  let wishOrient = quat(human_to_ladder_animation__wishGunOrient)
  let duration = get_to_ladder_anim_duration(curPos, human_to_ladder_animation__wishPos,
                                             curOrient, wishOrient, human_to_ladder_animation__ladderUp,
                                             human_ladder__animationVelocity)
  let interpK = info.dt / duration

  let curLook = dir_and_up_to_quat(human_net_phys.phys.producedCT.wishLookDir, state.vertDirection)
  let wishLook = quat(human_to_ladder_animation__wishLookOrient)
  let qLook = slerp(curLook, wishLook, saturate(interpK))
  let fwdLook = quat_get_forward(qLook)
  human_input__aimAngle = basis_aware_dir_to_angles(fwdLook, human_net_phys__prevVertDir, human_net_phys__prevRootDir)
  human_net_phys.phys.producedCT |> human_control_state_set_wish_look_dir(fwdLook)

  let curShoot = dir_and_up_to_quat(human_net_phys.phys.producedCT.wishShootDir, state.vertDirection)
  let wishShoot = quat(human_to_ladder_animation__wishGunOrient)
  let qShoot = slerp(curShoot, wishShoot, saturate(interpK))
  let fwdShoot = quat_get_forward(qShoot)
  human_net_phys.phys.producedCT |> human_control_state_set_wish_shoot_dir(fwdShoot)


[es(track=human_ladder__pull, REQUIRE=watchedByPlr)]
def disable_input_during_pull(evt : Event;
                              human_ladder__pull : bool)
  activate_action_set(get_action_set_handle("Human"), !human_ladder__pull)

// camera restriction --------------------------------------------------

[es(tag=input, after=human_input_es, REQUIRE=watchedByPlr)]
def human_input_camera_on_ladder_es(info : UpdateStageUpdateInput;
                                    human_ladder__attached : bool;
                                    isAlive : bool;
                                    var human_net_phys : HumanActor;
                                    var human_input__aimAngle : float2&;
                                    var human_weap__prevGunAngles : float2&;
                                    human_net_phys__prevVertDir : float3;
                                    human_net_phys__prevRootDir : float3;
                                    human_ladder__curLadderTm : float3x4;
                                    human_ladder__cameraAngle : float4)
  if !human_ladder__attached || !isAlive
    return

  assume ct = human_net_phys.phys.producedCT

  var orientTm = human_ladder__curLadderTm
  orientTm |> orthonormalize()

  let humanPos = float3(human_net_phys.phys.currentState.location.P)
  let human2ladder = human_ladder__curLadderTm[3] - humanPos
  let toLadderDir = basis_aware_x0z(human2ladder, orientTm[1])

  if dot(orientTm[0], toLadderDir) < 0.
    orientTm[0] = -orientTm[0]

  let wishLookDirAngles = basis_aware_dir_to_angles(ct.wishLookDir, human_net_phys__prevVertDir, human_net_phys__prevRootDir)

  human_input__aimAngle = basis_aware_clamp_angles_by_dir(human_input__aimAngle, human_ladder__cameraAngle, orientTm[0], human_net_phys__prevVertDir, human_net_phys__prevRootDir)
  let clampedDir = basis_aware_angles_to_dir(human_input__aimAngle, human_net_phys__prevVertDir, human_net_phys__prevRootDir)
  human_weap__prevGunAngles = dir_to_angles(clampedDir)

  let lookAngle = basis_aware_clamp_angles_by_dir(wishLookDirAngles, human_ladder__cameraAngle, orientTm[0], human_net_phys__prevVertDir, human_net_phys__prevRootDir)
  ct |> human_control_state_set_wish_look_dir(basis_aware_angles_to_dir(lookAngle, human_net_phys__prevVertDir, human_net_phys__prevRootDir))

// hud entity transform ------------------------------------------------

[es(tag=gameClient, no_order, REQUIRE=human_ladder__hint)]
def ladder_hint_position_update(info : UpdateStageInfoAct;
                                var transform aka hint_transform : float3x4&;
                                var item_world_marker__offset : float3&)
  find_query() <| $ [es(REQUIRE=watchedByPlr)] (bindedCamera : EntityId;
                                                human_ladder__curLadderTm : float3x4;
                                                human_ladder__nearLadderTm : float3x4;
                                                human_ladder__descent : bool;
                                                human_ladder__attached : bool)
    query(bindedCamera) <| $ [es] (transform aka camera_transform : float3x4)
      hint_transform = camera_transform
      if human_ladder__attached
        let up = normalize(human_ladder__curLadderTm[1])
        item_world_marker__offset = inverse(hint_transform) * basis_aware_xVz(human_ladder__curLadderTm[3], camera_transform[3], up)
      elif human_ladder__descent
        item_world_marker__offset = inverse(hint_transform) * human_ladder__nearLadderTm[3]
      else
        let up = normalize(human_ladder__nearLadderTm[1])
        item_world_marker__offset = inverse(hint_transform) * basis_aware_xVz(human_ladder__nearLadderTm[3], camera_transform[3], up)
    return true


[es(tag=gameClient, before=hero_human_pre_use_object_es, after=hero_human_use_entity)]
def hero_human_use_ladder_hint(info : UpdateStageInfoAct;
                               var client_usable_objects__usableEids : EidList;
                               var client_usable_objects__usableEntityDots : FloatList)
  let params = get_use_query_params(get_controlled_hero())
  find_query() <| $ [es(REQUIRE=human_ladder__hint)] (eid : EntityId;
                                                      transform : float3x4;
                                                      item_world_marker__offset : float3;
                                                      use_object__enabled = true)
    if !use_object__enabled
      return false

    let ladderPos = transform[3] + rotate(transform, item_world_marker__offset)
    if !is_point_in_sphere_zone(params.pos, ladderPos, square(params.dist.x))
      return false

    let dot = dot(normalize(ladderPos - params.pos), params.dir)
    let insertionIndex = client_usable_objects__usableEntityDots |> lower_bound(dot) <| $(x, y)
      return x > y
    client_usable_objects__usableEids |> push(eid, insertionIndex)
    client_usable_objects__usableEntityDots |> push(dot, insertionIndex)

    return true