require ecs
require app
require math.base
require math.random
require math.ang
require AnimV20
require game.es.bighead_common
require game.events.events_active_matter
require net
require game.es.grav_zones_common
require DagorMath


[es(on_appear)]
def bighead_attack_start(evt : Event;
                         eid : EntityId;
                         transform : float3x4;
                         bighead_attack__prepareTime : float;
                         bighead_attack__attackTime : float;
                         bighead_attack__throwAmount : int;
                         bighead_attack__prepareObjectsHeight : float;
                         bighead_victims__eid : EidList;
                         floating_objects__creationRiList : StringList;
                         floating_objects__minMaxEllipseHeight : float2;
                         floating_objects__ellipseWidthHeightRatio : float;
                         floating_objects__minMaxSpeed : float2;
                         floating_objects__minMaxOscillationFrequency : float2;
                         floating_objects__minMaxOscillationAmplitude : float2;
                         floating_objects__minMaxOrbitAnglesDeg : float2;
                         bighead_animgraph_ids__attackPrepare : int;
                         var animchar : AnimcharBaseComponent&;
                         var bighead_attack__state : int&;
                         var bighead_attack__chosenObjects : EidList;
                         var bighead_attack__finishPrepareAt : float&;
                         var bighead_attack__finishAttackAt : float&;
                         var bighead_attack__startedAt : float&)
  bighead_attack__state = int(BigheadAttackState.PREPARE)
  let heightOffset = float3(0.0, bighead_attack__prepareObjectsHeight, 0.0)
  let circleRadius = float(bighead_attack__throwAmount)

  bighead_attack__startedAt = get_sync_time()
  bighead_attack__finishPrepareAt = bighead_attack__startedAt + bighead_attack__prepareTime
  bighead_attack__finishAttackAt = bighead_attack__finishPrepareAt + bighead_attack__attackTime

  assume animGraph = animchar.animGraph
  *animGraph |> anim_graph_enqueueState(*animchar.animState, bighead_animgraph_ids__attackPrepare)

  if !is_server()
    return

  for i in range(bighead_attack__throwAmount)
    if empty(bighead_victims__eid)
      break
    let sideAngle = float(i) / float(bighead_attack__throwAmount) * 2.0 * PI
    let sideOffset = float3(sin(sideAngle), 0.0, cos(sideAngle)) * circleRadius
    let target = bighead_victims__eid[i % length(bighead_victims__eid)]
    // NOTE: this is not a good seed, should be fixed when adding bighead to the game
    let objectSeed = int(uint(eid)) + int(uint(target)) + i
    let object = create_floating_object(floating_objects__creationRiList, objectSeed,
                                        transform,
                                        eid, floating_objects__minMaxEllipseHeight,
                                        floating_objects__ellipseWidthHeightRatio,
                                        floating_objects__minMaxOrbitAnglesDeg,
                                        floating_objects__minMaxSpeed,
                                        floating_objects__minMaxOscillationAmplitude,
                                        floating_objects__minMaxOscillationFrequency,
                                        "bighead_floating_object+bighead_floating_object_attack") <| $(init)
      set(init, "bighead_floating_object_attack__target", target)
      set(init, "bighead_floating_object_attack__preparePosition", transform[3] + heightOffset + sideOffset)
    push(bighead_attack__chosenObjects, object)


[es(no_order)]
def bighead_update_attack(act : ParallelUpdateFrameDelayed;
                          bighead_attack__prepareTime : float;
                          bighead_attack__attackTime : float;
                          bighead_attack__finishPrepareAt : float&;
                          bighead_attack__finishAttackAt : float&;
                          bighead_attack__startedAt : float&;
                          bighead_attack__chosenObjects : EidList;
                          bighead_animgraph_ids__paramActionProgress : int;
                          bighead_animgraph_ids__attackThrow : int;
                          bighead_animgraph_ids__fly : int;
                          bighead_attack__launchAt : float;
                          var bighead_attack__launchedProjectiles : bool&;
                          var animchar : AnimcharBaseComponent&;
                          var bighead_attack__state : int&)
  var actionProgress = 1.0
  assume animGraph = animchar.animGraph

  let now = get_sync_time()
  if bighead_attack__state == int(BigheadAttackState.PREPARE)
    if now >= bighead_attack__finishPrepareAt
      bighead_attack__state = int(BigheadAttackState.ATTACK)
      *animGraph |> anim_graph_enqueueState(*animchar.animState, bighead_animgraph_ids__attackThrow)
    else
      actionProgress = (now - bighead_attack__startedAt) / bighead_attack__prepareTime

  if bighead_attack__state == int(BigheadAttackState.ATTACK)
    if now >= bighead_attack__finishAttackAt
      bighead_attack__state = int(BigheadAttackState.DONE)
      *animGraph |> anim_graph_enqueueState(*animchar.animState, bighead_animgraph_ids__fly)
    else
      actionProgress = (now - bighead_attack__finishPrepareAt) / bighead_attack__attackTime
      if !bighead_attack__launchedProjectiles && actionProgress > bighead_attack__launchAt
        bighead_attack__launchedProjectiles = true
        for obj in bighead_attack__chosenObjects
          sendEvent(obj, CmdLaunchBigheadProjectile())

  *animchar.animState |> anim_state_holder_setParam(bighead_animgraph_ids__paramActionProgress, actionProgress)


[es(REQUIRE=bighead, on_appear, after=bighead_init_animgraph_ids)]
def bighead_init(evt : Event;
                 bighead_animgraph_ids__fly : int;
                 var animchar : AnimcharBaseComponent&)
  var animGraph = animchar.animGraph
  *animGraph |> anim_graph_enqueueState(*animchar.animState, bighead_animgraph_ids__fly)


[es(on_appear)]
def bighead_init_animgraph_ids(evt : Event;
                               animchar : AnimcharBaseComponent;
                               var bighead_animgraph_ids__attackPrepare : int&;
                               var bighead_animgraph_ids__attackThrow : int&;
                               var bighead_animgraph_ids__fly : int&;
                               var bighead_animgraph_ids__paramActionProgress : int&;
                               var bighead_animgraph_ids__paramMoveAngleHorizontal : int&;
                               var bighead_animgraph_ids__paramMoveAngleVertical : int&;
                               var bighead_animgraph_ids__paramMoveSpeed : int&)
  assume animGraph = animchar.animGraph
  bighead_animgraph_ids__attackPrepare = *animGraph |> anim_graph_getStateIdx("attack_prepare")
  bighead_animgraph_ids__attackThrow = *animGraph |> anim_graph_getStateIdx("attack_throw")
  bighead_animgraph_ids__fly = *animGraph |> anim_graph_getStateIdx("fly")
  bighead_animgraph_ids__paramActionProgress = *animGraph |> anim_graph_getParamId("action_progress", int(PT_ScalarParam))
  bighead_animgraph_ids__paramMoveAngleHorizontal = *animGraph |> anim_graph_getParamId("move_angle_horizontal", int(PT_ScalarParam))
  bighead_animgraph_ids__paramMoveAngleVertical = *animGraph |> anim_graph_getParamId("move_angle_vertical", int(PT_ScalarParam))
  bighead_animgraph_ids__paramMoveSpeed = *animGraph |> anim_graph_getParamId("move_speed", int(PT_ScalarParam))


[es(no_order)]
def bighead_update_animgraph_movement(update : ParallelUpdateFrameDelayed;
                                      bighead_animgraph_ids__paramMoveAngleHorizontal : int;
                                      bighead_animgraph_ids__paramMoveAngleVertical : int;
                                      bighead_animgraph_ids__paramMoveSpeed : int;
                                      bighead__speedAnimgraphMultiplier : float;
                                      bighead__verticalSpeedAnimgraphMultiplier : float;
                                      bighead_victims__eid : EidList;
                                      var transform : float3x4&;
                                      var bighead__previousPosition : float3&;
                                      var bighead__previousSpeed : float&;
                                      var animchar : AnimcharBaseComponent&)
  assume animGraph = animchar.animGraph

  let velocity = transform[3] - bighead__previousPosition
  let curSpeed = length(velocity)
  let speed = approach(bighead__previousSpeed, curSpeed, update.dt, 0.6)
  bighead__previousSpeed = speed
  let angleHorizontal = atan2(dot(cross(velocity, transform[0]), transform[1]), dot(transform[0], velocity)) * RAD_TO_DEG
  *animchar.animState |> anim_state_holder_setParam(bighead_animgraph_ids__paramMoveAngleHorizontal, -angleHorizontal)
  *animchar.animState |> anim_state_holder_setParam(bighead_animgraph_ids__paramMoveSpeed, speed * bighead__speedAnimgraphMultiplier)

  let verticalSpeed = velocity.y
  let angleVertical = verticalSpeed * bighead__verticalSpeedAnimgraphMultiplier
  *animchar.animState |> anim_state_holder_setParam(bighead_animgraph_ids__paramMoveAngleVertical, angleVertical)

  let up = -get_grav_dir(transform[3])
  let projectOnGravity = $ <| (vector : float3; len : float)
    let normalCos = dot(-up, vector / len)
    let projection = -up * len * normalCos
    return projection

  let normalProjection = invoke(projectOnGravity, velocity, speed)
  let projectedVelocity = velocity - normalProjection
  var desiredForward : float3
  if length(bighead_victims__eid) == 1
    assume bighead_transform = transform
    query(bighead_victims__eid[0]) <| $ [es] (transform aka victim_transform : float3x4)
      desiredForward = normalize(victim_transform[3] - bighead_transform[3])
  else
    desiredForward = length_sq(projectedVelocity) > 0.0001 * update.dt ? normalize(projectedVelocity) : transform[0]
  let currentForward = transform[0]
  let q = slerp(dir_to_quat(currentForward), dir_to_quat(desiredForward), 1.5 * update.dt)
  let forward =  q |> quat_get_forward()
  transform[0] = normalize(forward - invoke(projectOnGravity, forward, length(forward))) //length(desiredForward) > 0.01 * update.dt ? normalize(desiredForward) : transform[0]
  transform[1] = normalize(up)
  transform[2] = cross(transform[0], transform[1])

  bighead__previousPosition = transform[3]


[es(tag=server, on_event=EventLevelLoaded)]
def spawn_bighead(evt : Event;
                  eid : EntityId;
                  transform aka territory_transform : float3x4;
                  bighead_territory__monsterTemplate : string;
                  var bighead_territory__bighead : EntityId&)
  var isInZone = true
  find_query() <| $ [es(REQUIRE=dmgzone__damage)] (sphere_zone__radius : float; shrinkedZonePos : float2)
    let zonePos = float3(shrinkedZonePos.x, 0.0, shrinkedZonePos.y)
    isInZone = distance_sq(territory_transform[3], zonePos) < square(sphere_zone__radius)
    return isInZone
  if !isInZone
    destroyEntity(eid)
    return
  bighead_territory__bighead = createEntity(bighead_territory__monsterTemplate) <| $(init)
    set(init, "transform", transform)
    set(init, "bighead__territory", eid)


[es(on_disappear, tag=server)]
def despawn_bighead(evt : Event;
                    bighead_territory__bighead : EntityId)
  destroyEntity(bighead_territory__bighead)
