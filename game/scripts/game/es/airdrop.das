require ecs
require app
require math.base
require math.random
require DagorMath
require game.events.events_active_matter
require PhysObj
require DngPhysObj


[es(tag=server, on_appear)]
def initial_setup_timer_appear_airdrop(evt : Event;
                                       airdrop_manager__initialTimer : float2;
                                       airdrop_manager__quantityRangeAirdrop : int2;
                                       var airdrop_manager__orderedAirdrop : int&;
                                       var airdrop_manager__startDropAt : float&)
  let curTime = get_sync_time()
  airdrop_manager__startDropAt = curTime + rnd_float(airdrop_manager__initialTimer.x, airdrop_manager__initialTimer.y)
  airdrop_manager__orderedAirdrop = rnd_int(airdrop_manager__quantityRangeAirdrop)


[es(tag=server, no_order)]
def update_airdrop_spawn_state(info : ParallelUpdateFrameDelayed;
                               airdrop_manager__orderedAirdrop : int;
                               airdrop_manager__multZoneRadius : float;
                               airdrop_manager__airdropCreationHeight : float;
                               airdrop_manager__creationAirdropeAngle : float2;
                               airdrop_manager__repeatedTimer : float2;
                               airdrop_manager__airdropTemplate : string;
                               airdrop_manager__airdropPhysTemplate : string;
                               var airdrop_manager__startDropAt : float&;
                               var airdrop_manager__countAirdrop : int&)
  if airdrop_manager__orderedAirdrop <= airdrop_manager__countAirdrop || airdrop_manager__startDropAt > info.curTime
    return
  find_query() <| $[es(REQUIRE=moving_zone__movingVelocity)] (sphere_zone__radius : float;
                                                              transform aka zone_transform : float3x4)
    airdrop_manager__countAirdrop += 1
    if airdrop_manager__orderedAirdrop > airdrop_manager__countAirdrop
      airdrop_manager__startDropAt = info.curTime + rnd_float(airdrop_manager__repeatedTimer.x, airdrop_manager__repeatedTimer.y)

    let possibleRadiusForCreateOnGround = sphere_zone__radius * airdrop_manager__multZoneRadius * rnd_float(0.0, 1.0)
    var airdropMoveTo = float3()
    let generationTries = 10
    for i in range(generationTries)
      let angleFromCenterZone = rnd_float(0.0, TWOPI)
      var sin, cos : float
      sincos(angleFromCenterZone, sin, cos)

      var failedPos = false
      let airdropNewPos = zone_transform[3] + float3(cos, 0.0, sin) * possibleRadiusForCreateOnGround
      query() <| $[es(REQUIRE=airdrop)] (transform aka airdrop_transform : float3x4)
        let distNewPos = distance(float3(airdrop_transform[3].x, 0.0, airdrop_transform[3].z), float3(airdropNewPos.x, 0.0, airdropNewPos.z))
        if sphere_zone__radius * airdrop_manager__multZoneRadius > distNewPos
          failedPos = true
      if !failedPos || (i == generationTries - 1 && airdropMoveTo == float3())
        airdropMoveTo = airdropNewPos
        break

    let minMaxAngleInAir = airdrop_manager__creationAirdropeAngle
    let roll = rnd_float(minMaxAngleInAir.x,  minMaxAngleInAir.y) * DEG_TO_RAD
    let yaw = rnd_float(0.0, TWOPI)
    var quat : quat
    euler_to_quat(yaw, 0.0, roll, quat)
    let airdropMoveFrom = airdropMoveTo + quat_get_up(quat) * airdrop_manager__airdropCreationHeight

    createEntity("{airdrop_manager__airdropTemplate}+{airdrop_manager__airdropPhysTemplate}") <| $(init)
      var tm = IDENT_TM
      tm[3] = airdropMoveFrom
      init |> set("transform", tm)
      init |> set("airdrop__initialPosition", airdropMoveFrom)
      init |> set("airdrop__moveTo", airdropMoveTo)
      init |> set("airdrop__startTime", get_sync_time())
    return true


[es(no_order, REQUIRE=airdrop)]
def update_position_airdrop(info : ParallelUpdateFrameDelayed;
                            first_contact_listener__hadContact : bool;
                            var phys_obj_net_phys : PhysObjActor&;
                            airdrop__startTime : float;
                            airdrop__movingTime : float;
                            airdrop__initialPosition : float3;
                            airdrop__moveTo : float3;
                            var transform : float3x4)
  if !first_contact_listener__hadContact
    let time = cvt(info.curTime, airdrop__startTime, airdrop__startTime + airdrop__movingTime, 0.0, 1.0)
    transform[3] = lerp(airdrop__initialPosition, airdrop__moveTo, float3(time))
    phys_obj_net_phys.phys.currentState.location.P = DPoint3(transform[3])


[es(tag=server, track=first_contact_listener__hadContact, REQUIRE=airdrop)]
def calculate_time_for_smoke(evt : Event;
                             first_contact_listener__hadContact : bool;
                             airdrop__smokeOnGroundTimer : float;
                             var airdrop__smokeOnGroundDestoyAt : float&)
  if first_contact_listener__hadContact
    airdrop__smokeOnGroundDestoyAt = get_sync_time() + airdrop__smokeOnGroundTimer