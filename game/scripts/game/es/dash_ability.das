require ecs
require net
require DngNet
require ecs.common
require math
require app
require math.base
require Dacoll
require DagorSystem
require DngHuman
require HumanPhys
require GamePhys
require DagorRandom
require DagorMath
require PhysMat
require GridCollision
require CollisionTraces
require game.es.grav_zones_common
require game.es.game_effect_common
require game.es.ability_enums_common
require game.utils.team
require game.events.events_game
require game.events.events_active_matter
require debug.logerr_once


let DASH_ABILITY_NAME = "dash"


[es(tag=server, before=net_phys_update_es)]
def dash_update_stamina(act : UpdateStageInfoAct;
                        dash__staminaRegen : float;
                        dash__maxStamina : float;
                        var dash__stamina : float&)
  if dash__stamina >= dash__maxStamina
    return

  dash__stamina = min(dash__maxStamina, dash__stamina + dash__staminaRegen * act.dt)


[es(tag=server, on_appear, REQUIRE=dash_affect_activator)]
def dash_affect_activator(evt : Event;
                          game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (game_effect__dashInWater : bool = true;
                                            human_net_phys : HumanActor;
                                            team aka my_team : int;
                                            personal_enemies__enemies : EidList const?;
                                            dash__staminaConsumption : float;
                                            game_effect__dashDistance : float;
                                            game_effect__mainDashMatId : int = -1;
                                            game_effect__dashCooldown : float;
                                            game_effect__dashBufferDistance : float = 0.5f;
                                            game_effect__dashTraceBackwardOffset : float = 0.3f;
                                            game_effect__dashMaxElevation : float = 4.f;
                                            game_effect__dashMaxWaterElevation : float = 2.f;
                                            game_effect__dashTargetPushVelocity : float = 2.5f;
                                            game_effect__dashTargetAimPunchStrength : float = 1.5;
                                            var dash__stamina : float&)
    assume curState = human_net_phys.phys.currentState
    assume phys = human_net_phys.phys

    let atTime = get_sync_time()
    let canDash = atTime > curState.lastDashTime + game_effect__dashCooldown && (game_effect__dashInWater || !human_phys_state_get_is_swimming(curState))

    if dash__stamina < dash__staminaConsumption
      send_net_event(game_effect__attachedTo, AbilityUseFailed(ability_name := DASH_ABILITY_NAME,
                                                               reason = int(AbilityUseFailedReason.NOT_ENOUGH_STAMINA)))
      return

    if !canDash
      return

    var locationTm : float3x4
    location_toTM(curState.location, locationTm)

    var gunTM : float3x4
    human_phys_calcGunTm(human_net_phys.phys, PrecomputedPresetMode.TPV, locationTm, curState.gunAngles.y, curState.leanPosition, curState.height, gunTM)

    let castMatId = human_net_phys.phys.rayMatId
    let walkRad = human_net_phys.phys.walkRad

    let localCcdPos = human_net_phys.phys.ccdPos
    let ccdPos = locationTm * localCcdPos

    // cast from gunPos forward
    let mainCastMatId = game_effect__mainDashMatId != -1 ? game_effect__mainDashMatId : castMatId
    let maxDst = (game_effect__dashDistance + game_effect__dashBufferDistance)

    let gunDir = gunTM[0]
    var gunPos = gunTM[3] - (gunDir * game_effect__dashTraceBackwardOffset)

    // cast from ccd to gunPos
    var ccdToGunCastRes = ShapeQueryOutput()
    sphere_cast(ccdPos, gunPos, walkRad, ccdToGunCastRes, castMatId)
    gunPos = lerp(ccdPos, gunPos, float3(ccdToGunCastRes.t, ccdToGunCastRes.t, ccdToGunCastRes.t))


    let (flyFrom, flyPos) = try_dash_through_obstacles(gunPos, gunDir, mainCastMatId, maxDst, walkRad)
    let valerieFlyPos = dash_valerie_style(gunPos, gunDir, maxDst, walkRad, game_effect__dashBufferDistance, game_effect__dashTraceBackwardOffset, castMatId)

    var dashLn = distance(flyPos, flyFrom)
    var success = false
    var wishPos : float3
    let potentialImprovement = max(.0, dashLn - distance(valerieFlyPos, gunPos))
    let attemptStep = max(1.5, potentialImprovement / 5.01)
    var tm = IDENT_TM
    location_toTM(curState.location, tm)
    let torsoHeight = lerp(phys.crouchHeight, phys.standingHeight, saturate(curState.height)) - phys.collRad
    let colShift = tm[1] * (torsoHeight * 0.5 + phys.collRad)
    let torsoPos = float3(0.f, torsoHeight * 0.5f + phys.collRad, 0.f)
    var firstPass = true
    while dashLn > attemptStep && dashLn > potentialImprovement || (firstPass && potentialImprovement > 0.1)
      firstPass = false
      wishPos = flyFrom + gunDir * dashLn
      let newGravity = get_grav_dir(wishPos)
      var t = maxDst
      var norm : float3
      traceray_normalized(wishPos, newGravity, t, norm)
      //Terrible hack. But it makes things more reliable and intuitive. TODO
      //If we blink into altered gravity, then out current capsule orientation is used.
      //Which is necessary because blinking doesn't rotate our orientation
      //But this can make the capsule dig into the ground too much
      //As the result, blinking often fails.
      // -0.5 allows us to move away from the obstacle a little
      if t > 0.5
        t -= 0.5
      wishPos += newGravity * t
      tm[3] = wishPos
      tm[3] = tm * torsoPos
      if adjust_entity_spawn_position(tm, phys.collRad, torsoHeight * 0.5, castMatId, 8, 0.01)
        print("[Dash ability] collision check success at {tm}")
        success = true
        wishPos = tm[3] - colShift
        break
      dashLn -= attemptStep

    if !success
      if gunPos == valerieFlyPos
        return //Fail
      wishPos = land_valerie_pos(valerieFlyPos, ccdPos, gunTM[3], localCcdPos,
                                  walkRad, maxDst, human_net_phys, castMatId,
                                  game_effect__dashMaxWaterElevation, game_effect__dashMaxElevation)

    let traceFrom = float3(curState.location.P) + curState.vertDirection
    let traceTo = wishPos + curState.vertDirection
    let traceVec = traceTo - traceFrom
    let traceVecLen = length(traceVec)
    if traceVecLen > 1e-1
      let traceDir = traceVec / traceVecLen
      let rightDir = cross(curState.vertDirection, traceDir)

      using() <| $(var intersections : IntersectedEntities)
        var tHumans = traceVecLen
        let humansGridHash = ecs_hash("humans")

        let traceGap = 0.15
        for traceIndex in range(1, 4)
          let traceFromR = traceFrom + rightDir * traceGap * float(traceIndex)
          let traceFromL = traceFrom - rightDir * traceGap * float(traceIndex)
          trace_entities_in_grid(humansGridHash, traceFromR, traceDir, tHumans, game_effect__attachedTo, intersections, SortIntersections.NO)
          trace_entities_in_grid(humansGridHash, traceFromL, traceDir, tHumans, game_effect__attachedTo, intersections, SortIntersections.NO)
        trace_entities_in_grid(humansGridHash, traceFrom, traceDir, tHumans, game_effect__attachedTo, intersections, SortIntersections.YES)

        for isect in intersections
          var enemyFound = false
          query(isect.eid) <| $ [es] (team aka target_team : int)
            let friendly = is_teams_friendly(target_team, my_team) && !is_personal_enemy(personal_enemies__enemies, game_effect__attachedTo)
            enemyFound = !friendly

            wishPos = isect.pos - traceDir * 0.5 - curState.vertDirection * 0.5

            let pushVel = traceDir * game_effect__dashTargetPushVelocity + curState.vertDirection
            sendEvent(isect.eid,
                      CmdPushPhys(vel = pushVel, push_immunity = 0.0))

            query(isect.eid) <| $ [es] (var human_aim_punch__queuedEvents : Point3List)
              let dir = TWOPI * gfrnd()
              let punchTime = get_sync_time() + 1e-1
              let strength = game_effect__dashTargetAimPunchStrength
              human_aim_punch__queuedEvents |> push(float3(punchTime, cos(dir) * strength, sin(dir) * strength))

          if enemyFound
            break

    dash__stamina -= dash__staminaConsumption
    send_net_event(game_effect__attachedTo, EventProcessDash(atTime = atTime, wishPos = wishPos))


[es]
def human_process_dash(evt : EventProcessDash;
                       eid : EntityId;
                       game_effect__dashVelImmunityAmount : float = 2.f;
                       var human_net_phys : HumanActor)
  assume curState = human_net_phys.phys.currentState
  assume phys = human_net_phys.phys

  let prevPos = curState.location.P
  curState.location.P = DPoint3(evt.wishPos)
  curState.lastDashTime = evt.atTime
  curState.deltaVelIgnoreAmount += game_effect__dashVelImmunityAmount

  sendEvent(human_net_phys.eid, EventOnPlayerDash(from = float3(prevPos), to = evt.wishPos))
  sendEvent(eid, CmdDetachAttachedGun())


def try_dash_through_obstacles(gunPos, gunDir : float3; mainCastMatId : int; maxDst, walkRad : float)
  var norm : float3
  var matId = PHYSMAT_INVALID
  var riDesc = RendInstDesc()
  let offsets = fixed_array(float2(), float2(0.1, 0.1), float2(-0.1, 0.1), float2(0.1, -0.1), float2(-0.1, -0.1))
  let ax1 = get_normal(gunDir)
  let ax2 = cross(gunDir, ax1)
  let significantAdv = walkRad * 2.0
  var bestFrom = gunPos
  var bestT = -FLT_MAX
  var besti = -1
  //To avoid bumping into a random metal bar, cast several traces and use teh best one.
  for offset, i in offsets, iter_range(offsets)
    let from = gunPos + ax1 * offset.x + ax2 * offset.y
    var t = maxDst
    traceray_normalized(from, gunDir, t, matId, norm, ETF_ALL & ~ETF_LMESH, riDesc, mainCastMatId)
    t = max(.0, t - 0.1) //Don't go under surface, back off slightly
    if t - significantAdv > bestT
      besti = i
      bestT = t
      bestFrom = from
      if maxDst - bestT < significantAdv
        break
  return bestFrom, bestFrom + gunDir * bestT


def dash_valerie_style(gunPos, gunDir : float3;
                       maxDst, walkRad,
                       game_effect__dashBufferDistance, game_effect__dashTraceBackwardOffset : float;
                       castMatId : int)
  var sphereCastRes = ShapeQueryOutput()
  let traceTo = gunPos + gunDir * maxDst
  sphere_cast(gunPos, traceTo, walkRad, sphereCastRes, castMatId)
  let wishPos = lerp(gunPos, traceTo, float3(sphereCastRes.t, sphereCastRes.t, sphereCastRes.t))
  if length_sq(wishPos - gunPos) > square(walkRad + game_effect__dashTraceBackwardOffset)
    return wishPos - (game_effect__dashBufferDistance * gunDir)
  return gunPos // Don't blink


def land_valerie_pos(pos, ccdPos, gunTMPos, localCcdPos : float3; walkRad, maxDst : float;
                     human_net_phys : HumanActor; castMatId : int;
                     game_effect__dashMaxWaterElevation, game_effect__dashMaxElevation : float)
  assume curState = human_net_phys.phys.currentState
  var wishPos = pos
  let newGravity = get_grav_dir(wishPos)
  let oldGravity = human_net_phys.phys.currentState.gravDirection

  // cast from wishPos to ~ccdPos
  let gunToCcdOld = ccdPos - gunTMPos
  let gunToCcd = rotate_vec_to_new_zone(gunToCcdOld, oldGravity, newGravity)

  let backwardToCcd = wishPos + gunToCcd
  var backwardToCcdCastRes = ShapeQueryOutput()
  sphere_cast(wishPos, backwardToCcd, walkRad, backwardToCcdCastRes, castMatId)
  wishPos = lerp(wishPos, backwardToCcd, float3(backwardToCcdCastRes.t, backwardToCcdCastRes.t, backwardToCcdCastRes.t))

  // cast from ccd to location pos
  if length_sq(localCcdPos) > 1e-6 //-V1051 It's possible that the 'wishPos' should be used inside 'length_sq' function.
    let newLocalCcdPos = rotate_vec_to_new_zone(localCcdPos, oldGravity, newGravity)
    let traceToLocation = wishPos - newLocalCcdPos
    var traceToLocationRes = ShapeQueryOutput()
    sphere_cast(wishPos, traceToLocation, walkRad, traceToLocationRes, castMatId)
    wishPos = lerp(wishPos, traceToLocation, float3(traceToLocationRes.t, traceToLocationRes.t, traceToLocationRes.t))

  // cast from wishPos down
  if human_phys_state_get_is_underwater(curState) || human_phys_state_get_is_swimming(curState)
    var landHeight = 1000.f
    tracedown_normalized(wishPos, landHeight, ETF_DEFAULT)
    landHeight = wishPos.y - landHeight
    var waterLevel : float
    let hasWater = traceht_water(wishPos, waterLevel)
    if hasWater && waterLevel > landHeight
      if wishPos.y > waterLevel + game_effect__dashMaxWaterElevation
        wishPos.y = waterLevel + game_effect__dashMaxWaterElevation
  else
    let newGravity2 = get_grav_dir(wishPos)
    let traceDownTo = wishPos + newGravity2 * maxDst
    var downCastRes = ShapeQueryOutput()
    sphere_cast(wishPos, traceDownTo, walkRad, downCastRes, castMatId)
    let landPos = lerp(wishPos, traceDownTo, float3(downCastRes.t, downCastRes.t, downCastRes.t))
    if length_sq(landPos - wishPos) > square(game_effect__dashMaxElevation)
      wishPos = landPos
  if length_sq(localCcdPos) > 1e-6
    var newLocationTM : float3x4
    location_toTM(curState.location, newLocationTM)
    newLocationTM[3] = wishPos
    let newCcdPos = newLocationTM * localCcdPos

    // cast from wishPos to newCcdPos
    var fixCcdCastRes = ShapeQueryOutput()
    if sphere_cast(wishPos, newCcdPos, walkRad, fixCcdCastRes, castMatId)
      let penetration = (newCcdPos - wishPos) * (1.0f - fixCcdCastRes.t)
      wishPos -= penetration
  return wishPos

[es(on_appear)]
def init_dash_main_ray_mai_id(evt : Event; var game_effect__mainDashMatId : int&; game_effect__mainDashMatName : string)
  if game_effect__mainDashMatId == PHYSMAT_INVALID
    game_effect__mainDashMatId = get_material_id(game_effect__mainDashMatName)


[es(tag=server)]
def dash_ability_effect_in_es(evt : EventOnPlayerDash; transform : float3x4;
                              eid : EntityId;
                              game_effect__dashTrailInTemplate : string;
                              game_effect__dashTrailInTtl = 2.0)
  createEntity(game_effect__dashTrailInTemplate) <| $(var init : ComponentsInitializer)
    var tm : float3x4 = transform
    tm[3] = evt.from
    set(init, "transform", tm)
    set(init, "game_effect__attachedTo", eid)
    set(init, "game_effect__destroyAt", get_sync_time() + game_effect__dashTrailInTtl)

[es(tag=server)]
def dash_ability_effect_es(evt : EventOnPlayerDash; transform : float3x4;
                           eid : EntityId;
                           game_effect__dashTrailTemplate : string;
                           game_effect__dashTrailOffset = float3(0.0, 1.0, 0.0);
                           game_effect__dashTrailTtl = 2.0)
  createEntity(game_effect__dashTrailTemplate) <| $(var init : ComponentsInitializer)
    let dir = (evt.to - evt.from)
    var tm : float3x4
    tm = transform
    tm[2] = normalize(cross(tm[1], dir))
    tm[1] = dir
    tm[0] = normalize(cross(tm[1], tm[2]))
    tm[3] = evt.from + game_effect__dashTrailOffset + dir * 0.5
    if length_sq(tm[3]) > 1e12
      logerr_once("invalid dash effect pos {tm[3]} move from {evt.from} to {evt.to} offset {game_effect__dashTrailOffset}")
    set(init, "transform", tm)
    set(init, "game_effect__attachedTo", eid)
    set(init, "game_effect__destroyAt", get_sync_time() + game_effect__dashTrailTtl)


[es(tag=gameClient, REQUIRE=hero)]
def dash_ability_store_failed_use_time(evt : RqUseAbility; var hero_dash_ability__lastFailedUseTime : float&; am_storage__value : int; hero_ability__abilities : Array)
  let index = evt.idx
  if index < 0 || index >= length(hero_ability__abilities)
    return
  let desc = hero_ability__abilities[index] |> get_ecs_object()
  if get_string(desc, "name", "") != DASH_ABILITY_NAME
    return
  let price = get_int(desc, "activeMatterPrice") ?? 0
  if price > am_storage__value
    hero_dash_ability__lastFailedUseTime = get_sync_time()


[es(tag=gameClient, on_appear, REQUIRE=hero)]
def dash_ability_store_spawn_time(evt : Event; var hero_dash_ability__spawnTime : float&)
  hero_dash_ability__spawnTime = get_sync_time()


[es(tag=gameClient, track=hero_ability__abilities, REQUIRE=hero)]
def dash_ability_update_spawn_time(evt : Event; var hero_dash_ability__spawnTime : float&; hero_ability__abilities : Array)
  if hero_dash_ability__spawnTime == .0
    for item in hero_ability__abilities
      let itemObj = get_ecs_object(item)
      let abilityName = get_string(itemObj, "name", "")
      if abilityName == DASH_ABILITY_NAME
        hero_dash_ability__spawnTime = get_sync_time()


[es]
def dash_ability_set_tick(evt : CmdSetAbilityParam;
                          human_net_phys : HumanActor;
                          game_effect__dashTickInputDelay : int;
                          var game_effect__dashAtTick : int&)
  assume physTick = human_net_phys.phys.currentState.atTick
  if physTick > game_effect__dashAtTick && evt.name == DASH_ABILITY_NAME
    let tickWithDelay = evt.physTick + game_effect__dashTickInputDelay
    //Better late than never
    game_effect__dashAtTick = physTick >= tickWithDelay ? physTick + 1 : tickWithDelay