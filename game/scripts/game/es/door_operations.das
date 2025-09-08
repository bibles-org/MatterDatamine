require ecs
require ecs.safe
require ecs.common
require app
require game.events.events
require game.events.events_game
require game.events.events_active_matter
require game.es.grav_zones_common
require game.es.door_operations_common
require PhysVars
require game.es.action_common
require net
require game.utils.net_utils
require math.base
require math.ang
require Grid
require AnimV20
require RendInst
require DagorMath
require DagorSystem


[es(on_appear)]
def human_operate_door_action_appear(evt : Event;
                                     actions__actions : Array;
                                     var human_operate_door_action__actionIdx : int&)
  human_operate_door_action__actionIdx = get_action_idx(actions__actions, "operate_door")


[es(before=start_interaction_on_interactable_used)]
def door_operations(evt : CmdUse;
                    eid : EntityId)
  call_open_door_action(eid, evt.requesterEid, false)

[es(tag=netClient)]
def door_client_operations(evt : HumanUseObjectRequest; eid : EntityId)
  call_open_door_action(evt.objectEid, eid, false)


[es(before=start_interaction_on_interactable_used)]
def door_operations_alt(evt : CmdUseAlt;
                        eid : EntityId)
  call_open_door_action(eid, evt.requesterEid, true)

[es(tag=netClient)]
def door_client_operations_alt(evt : HumanUseAltObjectRequest; eid : EntityId)
  call_open_door_action(evt.objectEid, eid, true)


[es(tag=netClient, no_order)]
def door_client_prediction(info : ParallelUpdateFrameDelayed; eid : EntityId; door_client_prediction__doorEid : EntityId;
                           door_client_prediction__atTime, door_client_prediction__timeout : float)
  if info.curTime >= door_client_prediction__atTime + door_client_prediction__timeout
    query(door_client_prediction__doorEid) <| $ [es] (var rendinst_axis_rotation__targetAngle : float&; door_operations__serverTargetAngle : float)
      rendinst_axis_rotation__targetAngle = door_operations__serverTargetAngle
    destroyEntity(eid)

[es(track=door_operations__serverTargetAngle, REQUIRE_NOT=rotating_rendinst_simple_phys_processing)]
def door_operations_apply_server(evt : Event; var rendinst_axis_rotation__targetAngle : float&; door_operations__serverTargetAngle : float)
  rendinst_axis_rotation__targetAngle = door_operations__serverTargetAngle

[es(tag=netClient, on_appear, before=rendinst_axis_force_initial_rotation_es)]
def door_operations_init_client(evt : Event; var rendinst_axis_rotation__targetAngle : float&; door_operations__serverTargetAngle : float)
  rendinst_axis_rotation__targetAngle = door_operations__serverTargetAngle

[es(tag=server, on_appear)]
def door_operations_init_server(evt : Event; rendinst_axis_rotation__targetAngle : float; var door_operations__serverTargetAngle : float&)
  door_operations__serverTargetAngle = rendinst_axis_rotation__targetAngle

[es(tag=server, on_event=EventRiRotationPrematureStop)]
def sync_target_angles_on_stop_server(evt : Event; rendinst_axis_rotation__targetAngle : float; var door_operations__serverTargetAngle : float&)
  door_operations__serverTargetAngle = rendinst_axis_rotation__targetAngle


def get_start_state_preset_weight(item)
  let itemInfo = get_ecs_object(item)
  return get_float(itemInfo, "weight") ?? 1.0


def get_start_state_preset_total_weight(weights : array<float>)
  var sum = 0.0
  for weight in weights
    sum += weight
  return sum


def start_state_preset_choose_one_index(weights : array<float>; rand : float)
  if length(weights) == 0
    return -1

  let totalWeight = get_start_state_preset_total_weight(weights)

  let weightedRand = rand * totalWeight
  var sum = 0.0
  for weight, idx in weights, range(length(weights))
    sum += weight
    if sum >= weightedRand
      return idx

  return 0


[es(tag=server, before=(rendinst_axis_force_initial_rotation_es, door_operations_init_server), on_appear, on_event=EventRendinstsLoaded)]
def door_operations_randomize_spawn_angle(evt : Event;
                                          eid : EntityId;
                                          door_operations__riStartStatePreset : string;
                                          door_operations__openedAngle : float;
                                          door_operations__closedAngle : float;
                                          door_operations__ajarAngleKoef : float;
                                          var rendinst_axis_rotation__targetAngle : float&;
                                          var door_operations__state : int&;
                                          var door_operations__reqState : int&)
  let templateInfo = getTemplateByName(door_operations__riStartStatePreset)
  if templateInfo == null
    logerr("[Door Operations] Trying to get ri start state preset of unknown template: <{door_operations__riStartStatePreset}>")
  else
    let presets = get_ecs_array(getTemplateComponent(*templateInfo, "ri_start_state_preset__chances"))
    if presets != null
      var weights : array<float>
      reserve(weights, length(*presets))
      for statePreset in (*presets)
        weights |> push(get_start_state_preset_weight(statePreset))

      // use eid_frnd for random number generation, so resulting preset will be the same on server and on clients
      let idx = start_state_preset_choose_one_index(weights, eid_frnd(eid))
      let itemInfo = get_ecs_object((*presets)[idx])
      let spawnAngleMultRange = get_Point2(itemInfo, "angle_mult_range") ?? float2(0., 0.)

      if (spawnAngleMultRange.x > spawnAngleMultRange.y ||
          spawnAngleMultRange.x < 0.f || spawnAngleMultRange.y > 1.f)
        logerr("[Door Operations] angle_mult_range params are out of range in entity {eid} <{getEntityTemplateName(eid)}>: ri start state preset <{door_operations__riStartStatePreset}>; angle_mult_range = ({spawnAngleMultRange})")
        return

      // use eid_frnd(eid + 1) to get different random number from the one used for choosing preset
      let rndMult = spawnAngleMultRange.x + eid_frnd(EntityId(uint(eid) + 1u)) * (spawnAngleMultRange.y - spawnAngleMultRange.x)
      rendinst_axis_rotation__targetAngle = door_operations__closedAngle + (door_operations__openedAngle - door_operations__closedAngle) * rndMult

  door_operations__state = detect_door_state_by_angle(rendinst_axis_rotation__targetAngle,
                                                      door_operations__openedAngle,
                                                      door_operations__closedAngle,
                                                      door_operations__ajarAngleKoef)
  door_operations__reqState = door_operations__state


[es(tag=server, REQUIRE=rendinst_axis_rotation__enabled, on_appear)]
def door_state_by_rendinst_axis_rotation_appear_server(evt : Event;
                                                       rendinst_axis_rotation__curAngle : float;
                                                       door_operations__openedAngle : float;
                                                       door_operations__closedAngle : float;
                                                       door_operations__ajarAngleKoef : float;
                                                       var door_operations__state : int&)
  door_operations__state = detect_door_state_by_angle(rendinst_axis_rotation__curAngle,
                                                          door_operations__openedAngle,
                                                          door_operations__closedAngle,
                                                          door_operations__ajarAngleKoef)


[es(tag=server, REQUIRE=rendinst_axis_rotation__enabled, on_disappear)]
def door_state_by_rendinst_axis_rotation_disappear_server(evt : Event;
                                                          rendinst_axis_rotation__curAngle : float;
                                                          door_operations__openedAngle : float;
                                                          door_operations__closedAngle : float;
                                                          door_operations__ajarAngleKoef : float;
                                                          var door_operations__state : int&;
                                                          var door_operations__reqState : int&)
  door_operations__state = detect_door_state_by_angle(rendinst_axis_rotation__curAngle,
                                                      door_operations__openedAngle,
                                                      door_operations__closedAngle,
                                                      door_operations__ajarAngleKoef)
  door_operations__reqState = door_operations__state


[es(tag=server, track=locked__isLocked)]
def door_operations_locked_track(evt : Event;
                                 eid : EntityId;
                                 locked__isLocked : bool;
                                 door_operations__openOnUnlock : bool;
                                 door_operations__closeOnLock : bool;
                                 door_operations__reqState : int)
  if !locked__isLocked
    if door_operations__reqState == int(DoorState.CLOSED) && door_operations__openOnUnlock
      change_door_state(eid, int(DoorState.OPENED), float3(), /*is_server*/true)
  else
    if door_operations__reqState != int(DoorState.CLOSED) && door_operations__closeOnLock
      change_door_state(eid, int(DoorState.CLOSED), float3(), /*is_server*/true, /*ignore_lock*/true, /*ignore_cooldown*/true)


def get_door_action_use_prompt(target_state : int;
                               door_operation : DoorOperation;
                               door_operations__localizations : Object const? = null)
  if target_state == int(DoorState.OPENED)
    if door_operation == DoorOperation.PULL
      return door_operations__localizations?.open_pull ?? "hud/open_door_pull"
    elif door_operation == DoorOperation.PUSH
      return door_operations__localizations?.open_push ?? "hud/open_door_push"
    else
      return door_operations__localizations?.open ?? "hud/open_door"
  elif target_state == int(DoorState.CLOSED)
    return door_operations__localizations?.close ?? "hud/close_door"
  elif target_state == int(DoorState.AJAR)
    return door_operations__localizations?.ajar ?? "hud/open_door_slightly"
  return ""


def get_window_action_use_prompt(target_state : int)
  if target_state == int(DoorState.OPENED)
    return "hud/open_window"
  elif target_state == int(DoorState.CLOSED)
    return "hud/close_window"
  elif target_state == int(DoorState.AJAR)
    return "hud/open_window_slightly"
  return ""


def update_door_custom_prompt_for_current_actor(door_eid : EntityId)
  query(door_eid) <| $ [es] (door_operations__reqState : int;
                             isDoor : bool = true;
                             door_operations__omniRotate : bool = false;
                             door_operations__openedAngle : float;
                             door_operations__closedAngle : float;
                             door_operations__ajarAngleKoef : float;
                             rendinst_axis_rotation__curAngle : float;
                             rendinst_axis_rotation__axis : float3;
                             transform aka door_transform : float3x4;
                             var item__setCustomUsePrompt : das_string&;
                             var item__setCustomUseAltPrompt : das_string?;
                             door_operations__localizations : Object const?)
    query() <| $ [es(REQUIRE=watchedByPlr)] (transform aka player_transform : float3x4)
      if isDoor

        var doorOperation = DoorOperation.NONE
        var doorPushOrientation : float

        detect_door_operation(player_transform,
                              door_transform,
                              door_operations__reqState,
                              door_operations__omniRotate,
                              door_operations__openedAngle,
                              door_operations__closedAngle,
                              door_operations__ajarAngleKoef,
                              rendinst_axis_rotation__curAngle,
                              rendinst_axis_rotation__axis,
                              doorOperation,
                              doorPushOrientation)

        item__setCustomUsePrompt := get_door_action_use_prompt(
          get_door_main_action(door_operations__reqState),
          doorOperation,
          door_operations__localizations)

        if item__setCustomUseAltPrompt != null
          if door_operations__reqState == int(DoorState.OPENED)
            *item__setCustomUseAltPrompt := ""
          else
            *item__setCustomUseAltPrompt := get_door_action_use_prompt(
              get_door_alt_action(door_operations__reqState),
              doorOperation,
              door_operations__localizations)
      else
        item__setCustomUsePrompt := get_window_action_use_prompt(get_window_main_action(door_operations__reqState))

  query(door_eid) <| $ [es(REQUIRE=sliding_rendinst)] (door_operations__reqState : int;
                                                       var item__setCustomUsePrompt : das_string&;
                                                       door_operations__localizations : Object const?)
    item__setCustomUsePrompt := get_door_action_use_prompt(
      get_door_main_action(door_operations__reqState),
      DoorOperation.NONE,
      door_operations__localizations)


[es(tag=gameClient, on_appear, track=door_operations__reqState, REQUIRE=door_operations__reqState, REQUIRE_NOT=interactable__heroEid)]
def track_door_custom_prompt(evt : Event;
                             eid aka door_eid : EntityId)
  update_door_custom_prompt_for_current_actor(door_eid)


[es(tag=gameClient, REQUIRE=watchedByPlr, track=human_use_object__selectedObject)]
def set_door_custom_prompt_for_current_hero(evt : Event;
                                            eid : EntityId;
                                            human_use_object__selectedObject : EntityId;
                                            door_interactor : Tag const?)
  if human_use_object__selectedObject == INVALID_ENTITY_ID
    if door_interactor != null
      removeSubTemplate(eid, "door_interactor")
  else
    query(human_use_object__selectedObject) <| $ [es(REQUIRE=isDoor)] ()
      update_door_custom_prompt_for_current_actor(human_use_object__selectedObject)
      if door_interactor == null
        addSubTemplate(eid, "door_interactor")


[es(tag=gameClient, REQUIRE=(watchedByPlr, door_interactor), no_order)]
def door_interactor_update(act : UpdateStageInfoAct;
                           human_use_object__selectedObject : EntityId;
                           door_interactor__updateInterval : float = 0.5;
                           var door_interactor__updateAt : float&)
  if act.curTime < door_interactor__updateAt
    return

  door_interactor__updateAt = act.curTime + door_interactor__updateInterval
  update_door_custom_prompt_for_current_actor(human_use_object__selectedObject)


[es(tag=server, REQUIRE=rotating_rendinst_simple_phys_processing, on_appear)]
def door_state_on_simple_phys_rotation_started(evt : Event;
                                               var door_operations__state : int&;
                                               var door_operations__reqState : int&)
  door_operations__state = int(DoorState.AJAR)
  door_operations__reqState = door_operations__state


[es(tag=server, REQUIRE=rotating_rendinst_simple_phys_processing, on_disappear)]
def door_state_on_simple_phys_rotation_finished(evt : Event;
                                                door_operations__openedAngle : float;
                                                door_operations__closedAngle : float;
                                                door_operations__ajarAngleKoef : float;
                                                rendinst_axis_rotation__curAngle : float;
                                                var door_operations__state : int&;
                                                var door_operations__reqState : int&)
  door_operations__state = detect_door_state_by_angle(rendinst_axis_rotation__curAngle,
                                                      door_operations__openedAngle,
                                                      door_operations__closedAngle,
                                                      door_operations__ajarAngleKoef)
  door_operations__reqState = door_operations__state


[es(tag=server, REQUIRE=rotating_rendinst_simple_phys__angularVelocity, after=rotating_rendinst_simple_phys_update_finished)]
def sync_door_target_angles_on_simple_phys_rotation_server(evt : RotatingRendinstSimplePhysUpdateFinished;
                                                           rendinst_axis_rotation__targetAngle : float;
                                                           var door_operations__serverTargetAngle : float&)
  door_operations__serverTargetAngle = rendinst_axis_rotation__targetAngle


[es(tag=netClient, before=rotating_rendinst_simple_phys_fixed_update)]
def sync_door_target_angles_on_simple_phys_rotation_client(evt : RotatingRendinstSimplePhysFixedUpdate;
                                                           transform aka door_transform : float3x4;
                                                           initialTransform aka door_initialTransform : float3x4;
                                                           ri_extra : RiExtraComponent;
                                                           rendinst_axis_rotation__curAngle : float;
                                                           door_operations__minDesyncAngleValue : float = 0.1;
                                                           door_operations__desyncAngleTorquPow : float = 1.5;
                                                           door_operations__desyncAngleTorqueMult : float = 0.3;
                                                           door_operations__desyncAngleTorqueMin : float = 1.0;
                                                           door_operations__desyncAngleExtraDampingDelta : float = 40.0;
                                                           door_operations__desyncAngleExtraDampingValue : float = 5.0;
                                                           door_operations__serverTargetAngle : float;
                                                           rotating_door_simple_phys__collisionDesyncCheckMinAngle : float = 3.0;
                                                           rotating_door_simple_phys__collisionDesyncCheckInterval : float;
                                                           rotating_door_simple_phys__collisionDesyncCheckRadius : float = 0.5;
                                                           var rotating_door_simple_phys__collisionDesyncCheckAt : float&;
                                                           var rotating_rendinst_simple_phys__torque : float&;
                                                           var rotating_rendinst_simple_phys__angularVelocity : float&;
                                                           var rotating_rendinst_simple_phys__idleUpdate : bool&;
                                                           var rotating_rendinst_simple_phys__kinematicCollisionsEnabled : bool&)
  let serverTargetAngleRad = door_operations__serverTargetAngle * DEG_TO_RAD
  let curAngleRenormed = renorm_ang(rendinst_axis_rotation__curAngle * DEG_TO_RAD, serverTargetAngleRad)  * RAD_TO_DEG
  let desyncAngleDelta = door_operations__serverTargetAngle - curAngleRenormed
  let desyncAngleValue = abs(desyncAngleDelta)

  if desyncAngleValue > door_operations__minDesyncAngleValue
    // Definitely not best net synchronization logic, probably with some prediction it could work much better
    let syncTorque = pow(desyncAngleDelta, door_operations__desyncAngleTorquPow) * door_operations__desyncAngleTorqueMult
    let syncTorqueSign = sign(desyncAngleDelta)

    if desyncAngleValue >= door_operations__desyncAngleExtraDampingDelta && syncTorqueSign != sign(rotating_rendinst_simple_phys__angularVelocity)
      // Velocity is opposite to synchronization dir, so we need to damp it asap
      rotating_rendinst_simple_phys__angularVelocity *= 1.0 / (1.0 + door_operations__desyncAngleExtraDampingValue * evt.dt)

    rotating_rendinst_simple_phys__torque += syncTorqueSign * max(door_operations__desyncAngleTorqueMin, syncTorque)
    rotating_rendinst_simple_phys__idleUpdate = false


  // Collision desync check (Actor collided door from opposite sides on server and on client)
  let curTime = get_sync_time()
  if curTime > rotating_door_simple_phys__collisionDesyncCheckAt
    rotating_door_simple_phys__collisionDesyncCheckAt = curTime + rotating_door_simple_phys__collisionDesyncCheckInterval

    var desyncFound = false
    if desyncAngleValue > rotating_door_simple_phys__collisionDesyncCheckMinAngle
      let riType = handle_to_ri_type(ri_extra.handle)
      let riCollres = get_ri_gen_extra_collres(int(riType))
      if riCollres != null
        let collresBox = BBox3(riCollres.vFullBBox)
        let sphereCenter = door_transform[3] + rotate(transform, collresBox.center)
        let sphereCheckRadius = riCollres.boundingSphereRad + rotating_door_simple_phys__collisionDesyncCheckRadius
        let sphere = BSphere3(sphereCenter, sphereCheckRadius)

        let doorInversedInitialTransform = inverse(initialTransform)

        let minAngle = min(curAngleRenormed, door_operations__serverTargetAngle)
        let maxAngle = max(curAngleRenormed, door_operations__serverTargetAngle)

        let desyncEid = find_entity_in_grid(ecs_hash("humans"), sphere, GridEntCheck.POS) <| $[unused_argument(targetEid)] (targetEid : EntityId; targetPos : float3)
          let posDoorSpace = doorInversedInitialTransform * targetPos
          let toPosVec = normalize(float2(posDoorSpace.x, posDoorSpace.y))
          let angle = renorm_ang(angle(float2(1, 0), toPosVec), serverTargetAngleRad) * RAD_TO_DEG
          return angle > minAngle && angle < maxAngle

        desyncFound = (desyncEid != INVALID_ENTITY_ID)

    // In case of desync we should disable kinematic collisions, so the door will be forced to server angle
    rotating_rendinst_simple_phys__kinematicCollisionsEnabled = !desyncFound


[es(tag=server, on_appear, on_event=EventRendinstsLoaded, track=(door_operations__state, rendinst_axis_rotation__targetAngle),
  after=door_operations_randomize_spawn_angle)]
def rotating_rendinst_simple_phys_enabled_by_door_state(evt : Event;
                                                        door_operations__state : int;
                                                        rendinst_axis_rotation__targetAngle : float;
                                                        door_operations__closedAngle : float;
                                                        rotating_door_simple_phys__closeOnClosedAngleReached : bool;
                                                        var rotating_rendinst_simple_phys__startEnabled : bool&)
  if (rotating_door_simple_phys__closeOnClosedAngleReached &&
    door_operations__state == int(DoorState.CLOSED) &&
    is_equal_float(rendinst_axis_rotation__targetAngle, door_operations__closedAngle))
    rotating_rendinst_simple_phys__startEnabled = false
  else
    rotating_rendinst_simple_phys__startEnabled = true


[es]
def rotating_rendinst_simple_phys_close_door_by_clamp_angle_reached(evt : RotatingRendinstSimplePhysClampAngleReached;
                                                                    door_operations__closedAngle : float;
                                                                    rotating_door_simple_phys__closeOnClosedAngleReached : bool;
                                                                    var rotating_rendinst_simple_phys__angularVelocity : float&;
                                                                    var rotating_rendinst_simple_phys__torque : float&)
  if rotating_door_simple_phys__closeOnClosedAngleReached && is_equal_float(evt.angle, door_operations__closedAngle)
    rotating_rendinst_simple_phys__angularVelocity = 0.0
    rotating_rendinst_simple_phys__torque = 0.0


[es(tag=server)]
def rotating_rendinst_simple_phys_close_door_by_clamp_angle_reached_server(evt : RotatingRendinstSimplePhysClampAngleReached;
                                                                           door_operations__closedAngle : float;
                                                                           rotating_door_simple_phys__closeOnClosedAngleReached : bool;
                                                                           var door_operations__state : int&;
                                                                           var door_operations__reqState : int&;
                                                                           var rendinst_axis_rotation__targetAngle : float&;
                                                                           var door_operations__serverTargetAngle : float&;
                                                                           var rotating_rendinst_simple_phys__startEnabled : bool&)
  if rotating_door_simple_phys__closeOnClosedAngleReached && is_equal_float(evt.angle, door_operations__closedAngle)
    door_operations__state = int(DoorState.CLOSED)
    door_operations__reqState = int(DoorState.CLOSED)

    rendinst_axis_rotation__targetAngle = door_operations__closedAngle
    door_operations__serverTargetAngle = door_operations__closedAngle

    rotating_rendinst_simple_phys__startEnabled = false



[es(on_appear, before=anim_phys_init_es)]
def human_door_anim_init(evt : Event;
                         var human_anim__doorPushOrientationVarId : int&;
                         var human_anim__doorOperationVarId : int&;
                         var human_anim__doorPullEnumVarId : int&;
                         var human_anim__doorPushEnumVarId : int&;
                         var phys_vars : PhysVars)
  human_anim__doorPushOrientationVarId = registerVar(phys_vars, "door_push_orientation", 1.0)
  human_anim__doorOperationVarId = registerVar(phys_vars, "door_operation", 0.0)
  human_anim__doorPullEnumVarId = animV20_add_enum_value("door_pull")
  human_anim__doorPushEnumVarId = animV20_add_enum_value("door_push")


def call_open_door_action(door_eid, opener_eid : EntityId;
                          alt_action : bool = false)
  query(door_eid) <| $ [es] (transform aka door_transform : float3x4;
                             door_operations__reqState : int;
                             door_operations__omniRotate : bool = false;
                             door_operations__openedAngle : float;
                             door_operations__closedAngle : float;
                             door_operations__ajarAngleKoef : float;
                             rendinst_axis_rotation__curAngle : float;
                             rendinst_axis_rotation__axis : float3;
                             door_operations__lastUseTime : float;
                             door_operations__useCooldown : float;
                             pair_door__eid : EntityId)
    if door_operations__lastUseTime + door_operations__useCooldown > get_sync_time()
      return
    query(opener_eid) <| $ [es] (transform aka player_transform : float3x4;
                                 human_operate_door_action__noAnimation : Tag const?;
                                 var human_anim__doorAnimEid : EntityId&;
                                 var human_operate_door_action__alternativeAction : bool&)
      assume alternativeAction = human_operate_door_action__alternativeAction
      alternativeAction = alt_action

      var doorOperation = DoorOperation.NONE
      var doorPushOrientation : float

      detect_door_operation(player_transform,
                            door_transform,
                            door_operations__reqState,
                            door_operations__omniRotate,
                            door_operations__openedAngle,
                            door_operations__closedAngle,
                            door_operations__ajarAngleKoef,
                            rendinst_axis_rotation__curAngle,
                            rendinst_axis_rotation__axis,
                            doorOperation,
                            doorPushOrientation)

      if doorOperation != DoorOperation.NONE && human_operate_door_action__noAnimation == null
        set_door_operation_phys_vars(opener_eid, doorOperation, doorPushOrientation)
        run_action(opener_eid, "operate_door")
        human_anim__doorAnimEid = door_eid
      else
        cmd_use_door(door_eid, opener_eid, pair_door__eid,
                     alternativeAction ? get_door_alt_action(door_operations__reqState) : get_door_main_action(door_operations__reqState),
                     is_server())


  // Sliding doors
  query(door_eid) <| $ [es(REQUIRE=sliding_rendinst)] (pair_door__eid : EntityId const?;
                                                       door_operations__reqState : int)
    cmd_use_door(door_eid, opener_eid, pair_door__eid ?? INVALID_ENTITY_ID,
                 alt_action ? get_door_alt_action(door_operations__reqState) : get_door_main_action(door_operations__reqState),
                 is_server())


def set_door_operation_phys_vars(eid : EntityId;
                                 doorOperation : DoorOperation;
                                 doorPushOrientation : float)
  // sending animation parameters along with sending action
  // to both current host (when this is online client or server) and to online clients (when this isw online server)
  send_net_event(eid,
                EventSetDoorOperationParams(doorOperation = int(doorOperation), doorPushOrientation = doorPushOrientation),
                enum_connections_near_entity(eid, DEF_ACTION_RANGE, TEAM_UNASSIGNED/*team*/, INVALID_ENTITY_ID/*squad*/, eid/*except_possessed*/))


[es]
def set_door_operation_phys_vars_on_current_host(evt : EventSetDoorOperationParams;
                                                 var phys_vars : PhysVars;
                                                 human_anim__doorPullEnumVarId : int;
                                                 human_anim__doorPushEnumVarId : int;
                                                 human_anim__doorOperationVarId : int;
                                                 human_anim__doorPushOrientationVarId : int)
  setVar(phys_vars, human_anim__doorPushOrientationVarId, evt.doorPushOrientation)
  if evt.doorOperation == int(DoorOperation.PULL)
    setVar(phys_vars, human_anim__doorOperationVarId, float(human_anim__doorPullEnumVarId))
  elif evt.doorOperation == int(DoorOperation.PUSH)
    setVar(phys_vars, human_anim__doorOperationVarId, float(human_anim__doorPushEnumVarId))


[es]
def start_door_anim(evt : EventAction;
                    eid : EntityId;
                    human_operate_door_action__actionIdx : int;
                    human_anim__doorAnimEid : EntityId;
                    human_operate_door_action__alternativeAction : bool)
  assume alternativeAction = human_operate_door_action__alternativeAction

  if human_operate_door_action__actionIdx == evt.actionIdx
    query(human_anim__doorAnimEid) <| $ [es] (pair_door__eid : EntityId;
                                              door_operations__reqState : int)
      cmd_use_door(human_anim__doorAnimEid, eid, pair_door__eid,
                    alternativeAction ? get_door_alt_action(door_operations__reqState) : get_door_main_action(door_operations__reqState),
                    is_server())


[es(track=door_operations__reqState, REQUIRE=sliding_rendinst)]
def sliding_door_track_required_state(evt : Event;
                                      door_operations__reqState : int;
                                      var sliding_rendinst__slidedState : bool&)
  sliding_rendinst__slidedState = (door_operations__reqState == int(DoorState.OPENED)) ? true : false


[es(track=sliding_rendinst__slidedState, REQUIRE=sliding_rendinst)]
def sliding_door_track_slided_state(evt : Event;
                                    sliding_rendinst__slidedState : bool;
                                    var door_operations__reqState : int&)
  door_operations__reqState = sliding_rendinst__slidedState ? int(DoorState.OPENED) : int(DoorState.CLOSED)