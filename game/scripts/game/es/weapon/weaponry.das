require ecs
require ecs.safe
require ecs.common
require app
require math.base
require game.utils.team
require game.events.events
require game.events.events_game
require game.es.trace_common
require game.events.events_active_matter
require dm
require DaWeapons
require DaWeaponProps
require Dacoll
require DagorSystem
require DagorRandom
require DagorMath
require DagorMathUtils
require DngHuman
require DngWeapon
require DngNet
require DngActor
require DngPhysObj
require DngPhys
require DngDm
require WeaponDm
require Ballistics
require BallisticsProps
require GeomNodeTree
require GridCollision
require CollisionTraces
require PhysObj
require PhysMat
require AnimV20
require game.es.grenade_thrower_common
require game.es.human.human_gun_common
require danetlibs.damage_decals.damage_decals_events
require danetlibs.weapons.melee_events
require danetlibs.wounds.wounds_events
require game.es.damage_systems.damage_model_common


// When the client throws the grenade, the action starts immediately.
// But the throw action on the server is delayed proportionaly to the client-server RTT.
// To compensate the delay, the server "moves the grenade to the future".
// Moving the grenade to the future by N ms is the same as pretending the grenade was actually thrown N ms ago.
// Compensation should be caped by the maximum allowed ping (around 750 ms by the time of the change).
[es(tag=server, tag=net, on_appear)]
def compensate_shell_throw_lag_es(evt : Event;
                                  shell__launchAtTime : float;
                                  shell__owner : EntityId;
                                  var phys_obj_net_phys : PhysObjActor)
  if shell__launchAtTime > 0.0
    let dt = base_phys_actor_getDefTimeStepByTickrateType(PhysTickRateType.Normal)

    let maxTickDelta = int(ceil(PHYS_MAX_CONTROLS_TICKS_DELTA_SEC / dt))
    var tickDelta = 0
    query(shell__owner) <| $ [es] (possessedByPlr : EntityId)
      query(possessedByPlr) <| $ [es] (var player : Player)
        tickDelta = player |> calcControlsTickDelta(PhysTickRateType.Normal, /*interp*/ false)
    tickDelta = clamp(tickDelta, PHYS_MIN_INTERP_DELAY_TICKS, maxTickDelta)
    // TODO: reconsider, explain and maybe abstract away the compensation formula
    // the server compensates the controls lag and forward-compensates the AAS lag, hence the times 2 part
    var tickCompensation = tickDelta * 2

    while tickCompensation > 0 && !phys_obj_net_phys.phys.currentState.hadContact
      let atTime = shell__launchAtTime - float(tickCompensation) * dt
      phys_obj_net_phys.phys |> updatePhys(atTime, dt, true)
      --tickCompensation


[es]
def launch_shell_es(evt : CmdLaunchShell;// e.g. grenade
                    eid : EntityId;
                    animchar : AnimcharBaseComponent;
                    trajectory__startNodeIdx : int;
                    human_weap__throwMode : bool;
                    human_net_phys : HumanActor const?;
                    var human_weap__localProjectileEid : EntityId?;
                    var human_weap__lastShotGunEid : EntityId?;
                    var human_weap__lastShotAtTime : float?)
  assume launchDesc = evt.launchDesc
  let gunEid = evt.gunEid
  shell_entity_get_props(int(launchDesc.shellId.shellId)) <| $(entProps : ShellEntityTypeProps)
    let entPropsPhysTemplName = entProps.physTemplName

    let projectileEntity = obtain_owned_projectile_entity(eid, HUWeaponSlots.EWS_NUM)
    if human_weap__lastShotAtTime != null
      *human_weap__lastShotAtTime = get_sync_time()
    if human_weap__lastShotGunEid != null
      *human_weap__lastShotGunEid = gunEid

    var explTime = 0.f
    var grenadeOwner = eid
    var grenadeRethrower = INVALID_ENTITY_ID

    // projectileEntity contains the server-side projectile, only the server can destroy it
    if projectileEntity != INVALID_ENTITY_ID
      query(projectileEntity) <| $ [es] (shell__owner : EntityId const?;
                                         shell__rethrower : EntityId const?;
                                         shell__explTime : float const?)
        if shell__owner != null
          grenadeOwner = *shell__owner
        if shell__rethrower != null
          grenadeRethrower = *shell__rethrower
        if shell__explTime != null
          explTime = *shell__explTime

      if is_server()
        destroyEntity(projectileEntity)
      elif human_weap__localProjectileEid != null
        destroyEntity(*human_weap__localProjectileEid)
        *human_weap__localProjectileEid = INVALID_ENTITY_ID

    var launchTm = launchDesc.tm

    if human_weap__throwMode && human_net_phys != null
      assume curState = human_net_phys.phys.currentState
      let throwPoint = human_net_phys.phys |> human_phys_calcGunPos(PrecomputedPresetMode.FPV,
                                                                    curState.location |> location_makeTM(),
                                                                    curState.gunAngles.y,
                                                                    curState.leanPosition,
                                                                    curState.height)

      let inBodyPoint = *animchar.nodeTree |> geomtree_getNodeWpos(trajectory__startNodeIdx)

      let throwPointOffset = throwPoint - inBodyPoint
      var offsetLength = length(throwPointOffset)
      let throwDir = throwPointOffset * safeinv(offsetLength)
      // Expand the collision detection vector forward by 10cm
      offsetLength += 0.1
      var norm = float3()
      traceray_normalized(inBodyPoint, throwDir, offsetLength, norm, ETF_RI)
      // Then, shrink it by 10cm. If there is a collision, the collision point moves 10cm closer to the inBodyPoint
      // If there no collision point, nothing changes.
      offsetLength -= 0.1

      launchTm[3] = inBodyPoint + throwDir * offsetLength

    if is_server()
      if explTime == 0.f
        // this logic is coupled with the launcher_add_timer_es, which adds explTimeAdd to some shells, like flares, rifle grenades or else
        explTime = launchDesc.atTime

      create_shell_entity(entPropsPhysTemplName, launchTm, launchDesc.vel, grenadeOwner, launchDesc.shellId, int(launchDesc.gunPropsId),
                          launchDesc.atTime, explTime, /*active*/ true, /*visible*/ true, /*clientSide*/ false, grenadeRethrower)
    // Only doing client-side prediction for localy-controlled player
    // A projectile without a phys_obj_net_phys currently can't be lag-compensated on the server, so it's not client-side predicted
    else
      let physTemp = getTemplateByName(entPropsPhysTemplName)
      if (human_net_phys != null && human_net_phys.isLocalControl &&
          physTemp != null && templateHasComponent(*physTemp, "phys_obj_net_phys"))
        // The owner stores the eid of local projectile. If the owner doesn't exist, skip projectile client-side prediction (for simplicity)
        query(grenadeOwner) <| $ [es] (var human_weap__localProjectilePhysEid : EntityId&)
          // The human_weap__localProjectilePhysEid is properly destroyed and not overwritten by the new value
          destroyEntity(human_weap__localProjectilePhysEid)

          // explTime may not have valid value on the client yet. Setting 1s, so the grenade won't disappear immediately.
          if explTime == 0.f
            explTime = launchDesc.atTime + 1.f

          if explTime > launchDesc.atTime
            human_weap__localProjectilePhysEid = create_shell_entity(entPropsPhysTemplName, launchTm, launchDesc.vel,
                                                                    grenadeOwner, launchDesc.shellId, int(launchDesc.gunPropsId),
                                                                    launchDesc.atTime, explTime, /*active*/ true, /*visible*/ true,
                                                                    /*clientSide*/ true, grenadeRethrower)
          else
            human_weap__localProjectilePhysEid = INVALID_ENTITY_ID

[es(tag=netClient, on_appear)]
def destroy_client_side_projectile_es(evt : Event;
                                      eid : EntityId;
                                      shell__owner : EntityId;
                                      var phys_obj_net_phys aka server_phys_obj_net_phys : PhysObjActor)
  let serverProjectileEid = eid
  // The local and the server projectiles must have the same owner
  query(shell__owner) <| $ [es] (var human_weap__localProjectilePhysEid : EntityId&)
    // If there are two projectiles (local and server's) with the same owner, the local should be destroyed
    if human_weap__localProjectilePhysEid != INVALID_ENTITY_ID && serverProjectileEid != human_weap__localProjectilePhysEid

      query(human_weap__localProjectilePhysEid) <| $ [es] (phys_obj_net_phys : PhysObjActor)
        // This makes the transition from local to the server projectile a bit smoother for the first few frames
        server_phys_obj_net_phys.phys.previousState.location = phys_obj_net_phys.phys.previousState.location
        server_phys_obj_net_phys.phys.previousState.velocity = phys_obj_net_phys.phys.previousState.velocity
        server_phys_obj_net_phys.phys.currentState.location = phys_obj_net_phys.phys.currentState.location
        server_phys_obj_net_phys.phys.currentState.velocity = phys_obj_net_phys.phys.currentState.velocity

      destroyEntity(human_weap__localProjectilePhysEid)
      human_weap__localProjectilePhysEid = INVALID_ENTITY_ID


[es(tag=netClient, on_disappear)]
def destroy_orphaned_projectile_es_event_handler(evt : Event;
                                                 var human_weap__localProjectilePhysEid : EntityId&)
  // Destroying the grenade, when the human_weap is destroyed
  destroyEntity(human_weap__localProjectilePhysEid)
  human_weap__localProjectilePhysEid = INVALID_ENTITY_ID


[es(tag=(server, net), no_order, REQUIRE=projectile__inactive)]
def destroy_inactive_projectile_by_deadline(info : ParallelUpdateFrameDelayed; eid : EntityId; var projectile__timeToDestroy : float&)
  // After being stopped, the projectiles still lives for a little while, so the projectile state can be used to verify client-side shot
  projectile__timeToDestroy -= info.dt
  if projectile__timeToDestroy <= 0.f
    destroyEntity(eid)


[es]
def launch_projectile_es(evt : CmdLaunchProjectile;
                         eid : EntityId;
                         var human_weap__lastShotGunEid : EntityId?;
                         var human_weap__lastShotAtTime : float?)
  assume launchDesc = evt.launchDesc
  let gunEid = evt.gunEid
  query(gunEid) <| $ [es] (gun__projectileTemplate : string;
                           gun__projectileDebugTemplate : string = "";
                           gun__projectileDebug : bool = false;
                           gun__chokeSpread : float = 1.0;
                           gun__parallelProjectiles : Array const?;
                           var gun__ammo : int&;
                           gun__projectileRayMatId : int = -1;
                           gun_hit_fx__fleshPresetIndex : int = -1)
    let projectileTemplate = gun__projectileDebug ? gun__projectileDebugTemplate : gun__projectileTemplate
    let spawnProps = shell_spawn_try_get_props(int(launchDesc.shellId.shellId))
    if human_weap__lastShotAtTime != null
      *human_weap__lastShotAtTime = get_sync_time()
    if human_weap__lastShotGunEid != null
      *human_weap__lastShotGunEid = gunEid
    if spawnProps == null
      createEntity(projectileTemplate) <| $(var init : ComponentsInitializer)
        init |> set("ownerEid", eid)
        init |> set("gunEid", gunEid)
        init |> set("launch_desc", launchDesc)
        init |> set("shell__shell_id__shell_id", int(launchDesc.shellId.shellId))
        init |> set("shell__shell_id__damage_id", int(launchDesc.shellId.damageId))
        init |> set("shell__shell_id__ballistics_id", int(launchDesc.shellId.ballisticsId))
        init |> set("projectile__traceRayMatId", gun__projectileRayMatId)
        init |> set("projectile_hit_fx__fleshPresetIndex", gun_hit_fx__fleshPresetIndex)
      if gun__parallelProjectiles != null
        for it in *gun__parallelProjectiles
          if gun__ammo == 0
            break
          let projectileOffset = it ?? float2()
          using() <| $(var ldesc : LaunchDesc#)
            ldesc.shellId = launchDesc.shellId
            ldesc.gunPropsId = launchDesc.gunPropsId
            ldesc.atTime = launchDesc.atTime
            ldesc.initialLifeTime = launchDesc.initialLifeTime
            ldesc.tm = launchDesc.tm
            ldesc.tm[3] += float3(0.f, projectileOffset.x, projectileOffset.y)
            ldesc.vel = launchDesc.vel
            ldesc.firingMode = launchDesc.firingMode
            ldesc.bombBayHeight = launchDesc.bombBayHeight
            createEntity(projectileTemplate) <| $(var init : ComponentsInitializer)
              init |> set("ownerEid", eid)
              init |> set("gunEid", gunEid)
              init |> set("launch_desc", ldesc)
              init |> set("shell__shell_id__shell_id", int(launchDesc.shellId.shellId))
              init |> set("shell__shell_id__damage_id", int(launchDesc.shellId.damageId))
              init |> set("shell__shell_id__ballistics_id", int(launchDesc.shellId.ballisticsId))
              init |> set("projectile__traceRayMatId", gun__projectileRayMatId)
              init |> set("projectile_hit_fx__fleshPresetIndex", gun_hit_fx__fleshPresetIndex)
          --gun__ammo
    else
      let localVel = float3(
        dot(launchDesc.tm[0], launchDesc.vel),
        dot(launchDesc.tm[1], launchDesc.vel),
        dot(launchDesc.tm[2], launchDesc.vel))

      var seed = phys_time_to_seed(launchDesc.atTime)
      let count = _rnd_int(seed, spawnProps.minCount, spawnProps.maxCount)
      let chokeSpread = deg_to_rad(gun__chokeSpread)
      for _ in range(count)
        var sin = 0.0
        var cos = 0.0
        sincos(chokeSpread * _gauss_rnd(seed, 0), sin, cos)
        var newVel = float3(localVel.x * cos - localVel.y * sin, localVel.x * sin + localVel.y * cos, localVel.z)
        sincos(chokeSpread * _gauss_rnd(seed, 0), sin, cos)
        newVel = float3(newVel.x * cos + newVel.z * sin, newVel.y, -newVel.x * sin + newVel.z * cos)

        let vel = rotate(launchDesc.tm, newVel)
        using() <| $(var ldesc : LaunchDesc#)
          ldesc.shellId = launchDesc.shellId
          ldesc.gunPropsId = launchDesc.gunPropsId
          ldesc.atTime = launchDesc.atTime
          ldesc.initialLifeTime = launchDesc.initialLifeTime
          ldesc.tm = launchDesc.tm
          ldesc.vel = vel
          ldesc.firingMode = 0u
          ldesc.bombBayHeight = 0.0

          createEntity(projectileTemplate) <| $(var init : ComponentsInitializer)
            init |> set("ownerEid", eid)
            init |> set("gunEid", gunEid)
            init |> set("launch_desc", ldesc)
            init |> set("shell__shell_id__shell_id", int(launchDesc.shellId.shellId))
            init |> set("shell__shell_id__damage_id", int(launchDesc.shellId.damageId))
            init |> set("shell__shell_id__ballistics_id", int(launchDesc.shellId.ballisticsId))
            init |> set("projectile__traceRayMatId", gun__projectileRayMatId)
            init |> set("projectile_hit_fx__fleshPresetIndex", gun_hit_fx__fleshPresetIndex)


def projectile_trace_scene(eid : EntityId;
                           bullet_mat_id : int;
                           prev_pos : float3;
                           dir : float3;
                           cur_time : float;
                           var ri_desc : RendInstDesc#;
                           var len : float&;
                           var pmid : int&;
                           var norm : float3&;
                           var water_len : float&)
  if bullet_mat_id < 0
    logerr("{eid}<{getEntityTemplateName(eid)}>: bullet traceRayMatId is not set!")
    return false
  var sceneIntersected = traceray_normalized(prev_pos, dir, len, pmid, norm,
                                             ETF_ALL, ri_desc, bullet_mat_id)
  water_len = len
  let traceEnd = prev_pos + dir * len
  if traceray_water_at_time(prev_pos, traceEnd, cur_time, water_len)
    if !sceneIntersected
      // try additional len
      len += 10.0
      traceray_normalized(prev_pos, dir, len, pmid, norm,
                          ETF_ALL, ri_desc, bullet_mat_id)
    pmid = get_material_id("water3d") // TODO: move it to dacoll, as it could really be different materials
    norm = float3(0.0, 1.0, 0.0)
    sceneIntersected = true
  return sceneIntersected


[es(after=update_projectile_es, parallel_for=1, REQUIRE_NOT=projectile__inactive)]
def trace_scene_after_update_projectile_es(info : UpdateStageInfoAct;
                                           eid : EntityId;
                                           projectile__traceRayMatId : int;
                                           projectile__stopped : bool;
                                           projectile__prevPos : float3;
                                           dm_projectile_state : ProjectileState;
                                           projectile_ballistics : ProjectileBallistics;
                                           var projectile_trace_info__sceneIntersected : bool&;
                                           var projectile_trace_info__pmid : int&;
                                           var projectile_trace_info__dir : float3&;
                                           var projectile_trace_info__norm : float3&;
                                           var projectile_trace_info__prevProjectileDistance : float&;
                                           var projectile_trace_info__waterLen : float&;
                                           var projectile_trace_info__len : float&;
                                           var projectile_trace_info__riDescCellIdx : int&;
                                           var projectile_trace_info__riDescIdx : int&;
                                           var projectile_trace_info__riDescPool : int&;
                                           var projectile_trace_info__riDescOffs : uint&;
                                           var projectile_trace_info__riDescLayer : int&)
  if !projectile__stopped
    let prevPos = projectile__prevPos
    let offset = projectile_ballistics.state.pos - prevPos
    projectile_trace_info__len = length(offset)
    if projectile_trace_info__len < FLT_EPSILON
      return
    projectile_trace_info__dir = offset / projectile_trace_info__len
    projectile_trace_info__prevProjectileDistance = dm_projectile_state.distance - projectile_trace_info__len

    using() <| $(var riDesc : RendInstDesc#)
      projectile_trace_info__sceneIntersected = projectile_trace_scene(eid, projectile__traceRayMatId,
                                                                       prevPos, projectile_trace_info__dir,
                                                                       info.curTime, riDesc,
                                                                       projectile_trace_info__len,
                                                                       projectile_trace_info__pmid,
                                                                       projectile_trace_info__norm,
                                                                       projectile_trace_info__waterLen)
      projectile_trace_info__riDescCellIdx = riDesc.cellIdx
      projectile_trace_info__riDescIdx = riDesc.idx
      projectile_trace_info__riDescPool = riDesc.pool
      projectile_trace_info__riDescOffs = riDesc.offs
      projectile_trace_info__riDescLayer = riDesc.layer


def is_ri_extra_can_be_damaged_by_team(ri_handle : uint64;
                                       owner_team : int)
  if owner_team == TEAM_UNASSIGNED
    return true

  var isFriendly = false
  find_query() <| $ [es(REQUIRE=undestroyableByOwningTeam)] (ri_extra : RiExtraComponent;
                                                             team : int)
    if ri_handle != ri_extra.handle
      return false
    isFriendly = (team == owner_team)
    return true

  return !isFriendly


struct ProjectileHitSceneRes
  shouldStop : bool
  smokeTracerStop : bool
  ricochetAngle : float


def projectile_on_hit_scene(pos : float3;
                            pmid : int;
                            norm : float3;
                            hit_water : bool;
                            ldesc : LaunchDesc;
                            ballistics_proj_props : ProjectileProps;
                            scene_hit_ricochet_stability : float;
                            armor_power_mult : float;
                            var ballistics : ProjectileBallistics;
                            var proj_state : ProjectileState;
                            var vis_pos : float3&;
                            var is_underwater : bool&)
  var result = ProjectileHitSceneRes(shouldStop = true, smokeTracerStop = false, ricochetAngle = 0.0)

  if pmid < 0
    return result

  phys_mat_damage_model_get_props(pmid) <| $(dmPhysProps : PhysMatDamageModelProps)
    let projectileSpeedThreshold = 10.0
    let angleThreshold = 0.25 //~15 degrees
    let derivationShift = 0.7 //0.5 - without derivation

    var prevSpeed = length(ballistics.state.vel)
    let prevDir = ballistics.state.vel * safeinv(prevSpeed)

    var exit = false
    kinetic_get_props(int(ldesc.shellId.shellId)) <| $(kineticProps : KineticProps)
      if dmPhysProps.armorThickness != 0.0
        let armorPower = armor_power_mult * kineticProps.tbl |> interpolate_tab_float_interpolate(proj_state.penetrationDistance)
        if armorPower >= dmPhysProps.armorThickness
          proj_state.piercingShift = calc_penetration_shift(kineticProps.tbl,
                                                            armorPower - dmPhysProps.armorThickness,
                                                            proj_state.distance,
                                                            /*scale*/ 1.0, proj_state.piercingShift)
          ballistics.state.pos = pos + (prevDir * 0.001)
          if hit_water
            is_underwater = !is_underwater
            let density = is_underwater ? water_density() : atmosphere_density(pos.y)
            let curTick = ballistics.state.atTick
            ballistics |> projectile_ballistics_setupWithKV(ballistics_proj_props, pos, ballistics.state.vel, 1.0f, density)
            ballistics.state.atTick = curTick + 1
          result.shouldStop = false
          result.smokeTracerStop = true
          exit = true
          return
    if exit
      return

    if dmPhysProps.ricochetAngleMult != 0.0 && !is_underwater
      prevSpeed = length(ballistics.state.vel)
      var seed = get_positional_seed(pos, 10.0) ^ phys_time_to_seed(ldesc.atTime)
      let sini = -dot(prevDir, norm)
      let angleMult = dmPhysProps.ricochetAngleMult
      let sinr = sini * (1.0 + (_frnd(seed) * angleMult))
      let newSpeed = (1.0 - sinr) * prevSpeed
      let speedToBroken = sini < angleThreshold ? (prevSpeed - newSpeed) : newSpeed * angleMult

      let bulletBrokenProbability = (speedToBroken / dmPhysProps.bulletBrokenThreshold)
      if (_frnd(seed) > bulletBrokenProbability
          && newSpeed > projectileSpeedThreshold
          && sini > 0.0
          && _frnd(seed) > scene_hit_ricochet_stability)
        let shiftPower = ((_frnd(seed) - derivationShift) * square(sinr))
        let sideShift = normalize(cross(prevDir, norm)) * shiftPower
        let newDir = normalize(prevDir + (norm * (sinr * 2.0)) + sideShift)
        vis_pos = pos
        let curTick = ballistics.state.atTick
        let inPos = pos - (prevDir * 0.001)
        let inVel = newDir * newSpeed
        let density = atmosphere_density(inPos.y)
        ballistics |> projectile_ballistics_setupWithKV(ballistics_proj_props, inPos, inVel, 1.0f, density)
        ballistics.state.atTick = curTick + 1

        result.shouldStop = false
        result.smokeTracerStop = angleMult > 1.0
        result.ricochetAngle = cvt(sinr, 0.0, 1.0, 90.0, 0.0)
        return

    if hit_water
      is_underwater = !is_underwater
      let newPos = pos + (prevDir * 0.01)
      let density = is_underwater ? water_density() : atmosphere_density(newPos.y)
      let curTick = ballistics.state.atTick
      ballistics |> projectile_ballistics_setupWithKV(ballistics_proj_props, newPos, ballistics.state.vel, 1.0f, density)
      ballistics.state.atTick = curTick + 1
      result.shouldStop = false
      result.smokeTracerStop = true
      return

  return result


def on_projectile_hit_scene(projectile_eid : EntityId;
                            ri_desc : RendInstDesc#;
                            pmid : int;
                            norm : float3;
                            prev_pos : float3;
                            dir : float3;
                            len : float;
                            water_len : float;
                            projectile_dist : float;
                            allow_detonation : bool;
                            scene_intersections_count : int;
                            max_allowed_scene_intersections_for_fx : int;
                            add_bullet_hole : bool;
                            var last_damaged_riex_handle : uint64&;
                            var is_underwater : bool&)
  var shouldStop = false
  query(projectile_eid) <| $ [es] (ownerEid : EntityId;
                                   gunEid : EntityId;
                                   launch_desc : LaunchDesc;
                                   projectile_ballistics_props : ProjectileProps;
                                   projectile__prevPos : float3;
                                   projectile__sceneHitRicochetStability : float = 0.0;
                                   var dm_projectile_state : ProjectileState;
                                   var projectile_ballistics : ProjectileBallistics;
                                   var projectile__visualPos : float3&;
                                   var projectile__exploded : bool&;
                                   var projectile__pierceShiftOnStartPenetration : float&)
    var startSpeed = 0.0
    shell_start_get_props(int(launch_desc.shellId.shellId)) <| $(shellStartProps : ShellStartProps)
      startSpeed = shellStartProps.speed
    var damage = calc_kinetic_damage(int(launch_desc.shellId.shellId), projectile_dist, startSpeed)
    damage *= get_float(gunEid, "gun__kineticDamageMult") ?? 1.0

    let pos = prev_pos + dir * water_len
    let riHandle = ri_desc.riExtraHandle
    if ri_desc.isValid

      let ownerTeam = get_int(ownerEid, "team") ?? TEAM_UNASSIGNED
      if riHandle != last_damaged_riex_handle

        let impulse = dir * 50.0

        let riEid = find_ri_extra_eid(riHandle)
        if riEid != INVALID_ENTITY_ID
          sendEvent(riEid, EventRendinstOnProjectileHit(projectile_eid = projectile_eid, pos = pos, impulse = impulse, time = get_sync_time()))

        if is_ri_extra_can_be_damaged_by_team(riHandle, ownerTeam)
          projectile__pierceShiftOnStartPenetration = dm_projectile_state.piercingShift
          last_damaged_riex_handle = riHandle
          sendEvent(ownerEid, CmdRendinstDamage(handle = riHandle, damage = damage, pos = pos, impulse = impulse, time = get_sync_time()))
      else
        phys_mat_damage_model_get_props(pmid) <| $(dmPhysProps : PhysMatDamageModelProps)
          let multiplier = 1.0 + dmPhysProps.armorThickness
          let currentPierce = dm_projectile_state.piercingShift - projectile__pierceShiftOnStartPenetration
          dm_projectile_state.piercingShift = projectile__pierceShiftOnStartPenetration + currentPierce * multiplier


    if add_bullet_hole
      sendEvent(
        projectile_eid,
        CmdRendinstBulletHole(
          riHandle = riHandle, pos = pos, dir = dir,
          norm = norm, pmid = pmid))

    broadcastEvent(ProjectileHitShake(position = pos, damage = damage))

    let hitWater = water_len < len
    let armorPowerMult = get_float(gunEid, "gun__armorPowerMult") ?? 1.0
    let res = projectile_on_hit_scene(pos, pmid, norm, hitWater, launch_desc,
                                      projectile_ballistics_props,
                                      projectile__sceneHitRicochetStability, armorPowerMult,
                                      projectile_ballistics, dm_projectile_state,
                                      projectile__visualPos, is_underwater)

    if res.shouldStop
      if allow_detonation
        detonate_shell_server(projectile_eid, launch_desc.shellId, int(launch_desc.gunPropsId), pos, ownerEid,
                              projectile__prevPos, projectile_ballistics.state.vel, INVALID_ENTITY_ID, norm,
                              /*alternative_offender*/ INVALID_ENTITY_ID)
        projectile__exploded = true
      projectile_ballistics.state.pos = prev_pos + dir * water_len

    let sceneIntersectionsExceeded = scene_intersections_count >= max_allowed_scene_intersections_for_fx

    sendEventImmediate(
      projectile_eid,
      EventProjectileHitScene(
        pos = pos,
        shouldStop = res.shouldStop,
        ricochetAngle = res.ricochetAngle,
        smokeTracerStop = res.smokeTracerStop,
        rendinstCellIdx = ri_desc.cellIdx,
        rendinstIdx = ri_desc.idx,
        rendinstPool = ri_desc.pool,
        rendinstOffs = ri_desc.offs,
        rendinstLayer = ri_desc.layer,
        matId = pmid,
        norm = norm,
        allowDetonation = allow_detonation,
        sceneIntersectionsExceeded = sceneIntersectionsExceeded,
        collType = -1,
        riexHandle = riHandle))

    shouldStop = res.shouldStop
  return shouldStop


def trace_shootable_objects(from, dir : float3; len : float; ignore_human, ignore_vehicle : EntityId; cb : block<(intersections : IntersectedEntities) : void>)
  using() <| $(var intersections : IntersectedEntities)
    var t1 = len; var t2 = len; var t3 = len; var t4 = len; var t5 = len; var t6 = len
    trace_traceable_spheres_in_grid(from, dir, t1, intersections)
    trace_entities_in_grid(ecs_hash("am_cores"), from, dir, t2, INVALID_ENTITY_ID, intersections, SortIntersections.NO)
    trace_entities_in_grid(ecs_hash("humans"), from, dir, t3, ignore_human, intersections, SortIntersections.NO)
    trace_entities_in_grid(ecs_hash("creatures"), from, dir, t4, ignore_human, intersections, SortIntersections.NO)
    trace_entities_in_grid(ecs_hash("vehicles"), from, dir, t5, ignore_vehicle, intersections, SortIntersections.NO)
    trace_entities_in_grid(ecs_hash("interactable"), from, dir, t6, INVALID_ENTITY_ID, intersections, SortIntersections.YES)
    invoke(cb, intersections)


def process_projectile_trace(projectile_eid : EntityId;
                             from : float3;
                             dir : float3;
                             len : float;
                             ownerEid : EntityId;
                             projectile__lifeTime : float;
                             projectile__minLifeTime : float;
                             projectile_ballistics : ProjectileBallistics;
                             projectile_trace_info__waterLen : float;
                             projectile_trace_info__prevProjectileDistance : float;
                             var projectile__stopped : bool&;
                             var projectile__exploded : bool&;
                             var projectile__penetratedEids : EidList;
                             var hit_result : ProjectileHitResult&;
                             var entities_intersected : bool&)
  let allowDetonation = (projectile__lifeTime >= projectile__minLifeTime)

  let vehicleEid = get_Eid(ownerEid, "human_anim__vehicleSelected") ?? INVALID_ENTITY_ID
  let projectileOwnerTeam = get_int(ownerEid, "team") ?? TEAM_UNASSIGNED

  trace_shootable_objects(from, dir, len, ownerEid, vehicleEid) <| $(sortedIntersectedList : IntersectedEntities)
    if length(sortedIntersectedList) > 0
      for isect in sortedIntersectedList
        // other systems can stop projectile on immediate events
        if projectile__stopped
          break
        let i = projectile__penetratedEids |> find_index(isect.eid)
        if i >= 0
          continue
        hit_result = projectile_on_hit_entity(projectile_eid, isect, projectileOwnerTeam,
                                          projectile_ballistics.state.vel, from,
                                          dir, projectile_trace_info__waterLen,
                                          get_sync_time(), projectile_trace_info__prevProjectileDistance,
                                          sortedIntersectedList,
                                          allowDetonation, true)
        if hit_result == ProjectileHitResult.Ignore
          continue
        entities_intersected = true
        if hit_result == ProjectileHitResult.HitAndContinue
          projectile__penetratedEids |> push(isect.eid)
          sendEventImmediate(projectile_eid, EventProjectileIntersectEntityWithHp(victim = isect.eid, offender = ownerEid, pos = isect.pos, collNodeId = isect.collNodeId))
        else // HitAndDestroyProjectile
          projectile__stopped = true
          if allowDetonation
            projectile__exploded = true
          sendEventImmediate(projectile_eid, EventProjectileIntersectEntityWithHp(victim = isect.eid, offender = ownerEid, pos = isect.pos, collNodeId = isect.collNodeId))
          break


[es(on_appear)]
def projectile_on_appear(evt : Event;
                         eid aka projectile_eid : EntityId;
                         ownerEid : EntityId;
                         gunEid : EntityId;
                         launch_desc : LaunchDesc;
                         projectile__lifeTime : float;
                         projectile__minLifeTime : float;
                         projectile_ballistics : ProjectileBallistics;
                         projectile_trace_info__waterLen : float;
                         projectile_trace_info__prevProjectileDistance : float;
                         var projectile__exploded : bool&;
                         var projectile__stopped : bool&;
                         var projectile__penetratedEids : EidList)
  query(gunEid) <| $ [es] (gun__length : float = 0.65)
    let shootPos = launch_desc.tm[3]
    let shootDir = normalize(launch_desc.vel)
    let startPos = shootPos - shootDir * gun__length

    var entitiesIntersected = false
    var hitResult = ProjectileHitResult.Ignore

    // Trace "enemy x barrel" intersection
    process_projectile_trace(projectile_eid, startPos, shootDir, gun__length, ownerEid, projectile__lifeTime, projectile__minLifeTime,
                            projectile_ballistics, projectile_trace_info__waterLen, projectile_trace_info__prevProjectileDistance,
                            projectile__stopped, projectile__exploded, projectile__penetratedEids, hitResult, entitiesIntersected)


[es(after=trace_scene_after_update_projectile_es, REQUIRE_NOT=projectile__inactive)]
def after_update_projectile_es(info : UpdateStageInfoAct;
                               eid : EntityId;
                               ownerEid : EntityId;
                               projectile__lifeTime : float;
                               projectile__minLifeTime : float;
                               projectile__maxLifeTime : float;
                               projectile__maxAllowedSceneIntersectionsForFx : int;
                               projectile_ballistics : ProjectileBallistics;
                               dm_projectile_state : ProjectileState;
                               projectile__prevPos : float3;
                               projectile_trace_info__dir : float3;
                               projectile_trace_info__norm : float3;
                               projectile_trace_info__waterLen : float;
                               projectile_trace_info__len : float;
                               projectile_trace_info__prevProjectileDistance : float;
                               projectile_trace_info__sceneIntersected : bool;
                               projectile_trace_info__pmid : int;
                               projectile_trace_info__riDescCellIdx : int;
                               projectile_trace_info__riDescIdx : int;
                               projectile_trace_info__riDescPool : int;
                               projectile_trace_info__riDescOffs : uint;
                               projectile_trace_info__riDescLayer : int;
                               projectile__addBulletHole : bool = true;
                               var projectile__exploded : bool&;
                               var projectile__stopped : bool&;
                               var projectile__penetratedEids : EidList;
                               var projectile__lastDamagedRiexHandle : uint64&;
                               var projectile__isUnderwater : bool&;
                               var scene_hit_place__pos : float3&;
                               var scene_hit_place__norm : float3&;
                               var scene_hit_place__matId : int&;
                               var projectile__intersectionCount : int&)
  if projectile__stopped || projectile_trace_info__len < FLT_EPSILON
    return

  let allowDetonation = (projectile__lifeTime > projectile__minLifeTime)
  let prevPos = projectile__prevPos
  let dir = projectile_trace_info__dir
  let norm = projectile_trace_info__norm
  let pmid = projectile_trace_info__pmid
  let len = projectile_trace_info__len
  var entitiesIntersected = false
  var hitResult = ProjectileHitResult.Ignore

  process_projectile_trace(eid, prevPos, dir, len, ownerEid, projectile__lifeTime, projectile__minLifeTime,
                           projectile_ballistics, projectile_trace_info__waterLen, projectile_trace_info__prevProjectileDistance,
                           projectile__stopped, projectile__exploded, projectile__penetratedEids, hitResult, entitiesIntersected)


  // Actually correct would be iterate over until we got closest hit. However, we will be using simplified version.
  let maxLen = min(projectile_trace_info__waterLen, len)
  let isLocalOwner = ownerEid |> has("hero")
  broadcastEventImmediate(EventProjectileFlight(prevPos = prevPos, normalizedDir = dir, dist = maxLen, isLocalOwner = isLocalOwner))

  if projectile_trace_info__sceneIntersected && !entitiesIntersected && !projectile__stopped
    using(projectile_trace_info__riDescCellIdx,
          projectile_trace_info__riDescIdx,
          projectile_trace_info__riDescPool,
          projectile_trace_info__riDescOffs,
          projectile_trace_info__riDescLayer) <| $(var riDesc : RendInstDesc#)
      projectile__intersectionCount += 1
      let projectileDist = projectile_trace_info__prevProjectileDistance + projectile_trace_info__waterLen + dm_projectile_state.piercingShift
      let shouldStop = on_projectile_hit_scene(eid, riDesc, pmid, norm, prevPos, dir,
                                               projectile_trace_info__len, projectile_trace_info__waterLen,
                                               projectileDist, allowDetonation, projectile__intersectionCount,
                                               projectile__maxAllowedSceneIntersectionsForFx,
                                               projectile__addBulletHole, projectile__lastDamagedRiexHandle,
                                               projectile__isUnderwater)
      if shouldStop
        projectile__stopped = true
        if allowDetonation
          if !projectile__exploded
            logerr("{eid}<{getEntityTemplateName(eid)}>: projectile__exploded should be set inside on_projectile_hit_scene")

  if projectile__stopped
    scene_hit_place__pos = prevPos + dir * projectile_trace_info__waterLen
    if projectile_trace_info__sceneIntersected && !entitiesIntersected
      scene_hit_place__norm = norm
      scene_hit_place__matId = pmid
    else
      scene_hit_place__matId = -1

  // Actually, it is better to check lengthSq(ballistics.state.vel) > threshold
  if projectile__lifeTime > projectile__maxLifeTime || projectile__exploded
    if is_true_net_server()
      // net server needs projectile for client-side shot verification, so the projectile destruction is slightly delayed
      addSubTemplate(eid, "projectile_inactive")
    else
      destroyEntity(eid)


[es(after=update_projectile_es, REQUIRE_NOT=projectile__inactive)]
def after_update_stopped_projectile_es(info : UpdateStageInfoAct;
                                       eid : EntityId;
                                       ownerEid : EntityId;
                                       launch_desc : LaunchDesc;
                                       projectile__lifeTime : float;
                                       projectile__minLifeTime : float;
                                       projectile__maxLifeTime : float;
                                       projectile__prevPos : float3;
                                       projectile_ballistics : ProjectileBallistics;
                                       scene_hit_place__norm : float3;
                                       projectile__stopped : bool;
                                       var projectile__exploded : bool&)
  if projectile__stopped
    if !projectile__exploded && projectile__lifeTime > projectile__minLifeTime
      detonate_shell_server(eid, launch_desc.shellId, int(launch_desc.gunPropsId),
                            projectile_ballistics.state.pos, ownerEid,
                            projectile__prevPos, projectile_ballistics.state.vel,
                            INVALID_ENTITY_ID, scene_hit_place__norm,
                            /*alternative_offender*/ INVALID_ENTITY_ID)

      sendEventImmediate(eid, CmdShellExplosionFx())
      projectile__exploded = true

    // Actually, it is better to check lengthSq(ballistics.state.vel) > threshold
    if projectile__lifeTime > projectile__maxLifeTime || projectile__exploded
      if is_true_net_server()
        // net server needs projectile for client-side shot verification, so the projectile destruction is slightly delayed
        addSubTemplate(eid, "projectile_inactive")
      else
        destroyEntity(eid)


[es(before=process_projectile_on_hit_entity_with_hp)]
def remember_weapon_on_hit_entity_with_hp(evt : ProjectileOnHitEntityWithHp)
  query(evt.victim) <| $ [es] (var hitpoints__lastOffenderWeapon : EntityId&)
    hitpoints__lastOffenderWeapon = evt.gun_eid


[es(tag=server)]
def remember_melee_weapon_on_hit_entity_with_hp(evt : EventMeleeAttackHit; human_weap__currentGunEid : EntityId)
  query(evt.targetEid) <| $ [es] (var hitpoints__lastOffenderWeapon : EntityId&)
    hitpoints__lastOffenderWeapon = human_weap__currentGunEid


[es]
def process_projectile_on_hit_entity_with_hp(var evt : ProjectileOnHitEntityWithHp&)
  let projectile_eid = evt.projectile_eid
  let victim = evt.victim
  assume isect = evt.isect
  assume launch_desc = evt.launch_desc
  let vel = evt.vel
  let dir = evt.dir
  let waterLen = evt.waterLen
  let curTime = evt.curTime
  let offender = evt.offender
  let prev_projectile_dist = evt.prev_projectile_dist
  let piercing_shift = evt.piercing_shift
  let allow_detonation = evt.allow_detonation
  let gun_eid = evt.gun_eid
  let sceneHitRicochetStability = evt.sceneHitRicochetStability
  let trace_ray_mat_id = evt.trace_ray_mat_id
  let check_if_should_apply_damage = evt.check_if_should_apply_damage
  assume result = evt.result

  assume shellId = launch_desc.shellId
  let ballProjProps = projectile_try_get_props(int(shellId.shellId))
  if ballProjProps == null
    result = ProjectileHitResult.HitAndDestroyProjectile
    return

  let projectileDist = prev_projectile_dist + isect.t
  let invul = check_shell_invulnerability(victim, projectileDist, dir, isect.pos, curTime)

  let damageType = int(DamageType.DM_PROJECTILE)

  //Variables for onHitFxApply
  let shellIdShellId = int(shellId.shellId)
  let isectPos = isect.pos
  let isectNorm = isect.norm
  let isectCollNodeId = isect.collNodeId
  let onHitFxApply <- @ <| (hitpoints_hp : float; spawn_blood_vfx : bool; damage : float; entity_pmid : int; stopped : bool) : void
    var bloodSplash = HitBloodType.NONE
    var protectionFxRequired = false

    query(victim) <| $ [es] (human_damage_model__protectionKoefForProtectionFx : float;
                             var human_damage_model__parts : Object)
      var totalParts : array<BodyPart>
      make_array_of_body_parts(human_damage_model__parts, totalParts)
      for part in totalParts
        if has_value(*part.nodesIds, isectCollNodeId)

          if part.protection != null && damageType < length(*part.protection)
            let protectionKoef = saturate((*part.protection)[damageType])

            if protectionKoef >= human_damage_model__protectionKoefForProtectionFx
              protectionFxRequired = true
          break

    if spawn_blood_vfx && !invul.haveDeflectedShell && !protectionFxRequired
      bloodSplash = HitBloodType.ONE_SIDE

    let pmid = (invul.haveDeflectedShell || protectionFxRequired) ? get_material_id("steel") : entity_pmid
    broadcastEvent(OnShellHitEntityFx(shellId = shellIdShellId, pos = isectPos, dir = dir, pmid = pmid,
                     norm = isectNorm, bloodSplash = bloodSplash, nodeCollId = isectCollNodeId, victimEid = victim,
                     directHit = true, stopped = stopped, projectileEid = projectile_eid))
    var caliberFactor = 0.33 // in case of querry  fail will spawn standart size of wounds 0.15
    query() <| $ [es] (projectile_ballistics_props : ProjectileProps;
                       bullet_holes__shellCaliberThreshold : float = 0.020)
      let caliber = projectile_ballistics_props.caliber
      if caliber < bullet_holes__shellCaliberThreshold
        caliberFactor = clamp((caliber / bullet_holes__shellCaliberThreshold), 0.25, 1.0)
      else
        caliberFactor = 1.0
    sendEvent(victim, EventOnApplyWounds(pos = isectPos, normal = isectNorm, hitDir = dir, coll_node = isectCollNodeId, explosion = false, damage = damage, caliberFactor = caliberFactor))


  if invul.isInvulnerable
    query(victim) <| $ [es] (material : das_string const?; needsBlood = false; hitpoints__hp = 0.0)
      var entityPmid = -1
      if !invul.haveDeflectedShell
        entityPmid = get_material_id(material ?? "flesh")
      onHitFxApply |> invoke(hitpoints__hp, needsBlood, 0.0/*damage*/, entityPmid, true)
    sendEvent(victim, ProjectileHitInvulnerableNotification(hitPos = isect.pos, hitDir = dir))
    result = ProjectileHitResult.HitAndDestroyProjectile // as invulnerable entitities too
    return

  if invul.haveDeflectedShell && (!is_server() || get_hitdet_type() == HitDetectionType.ServerSide || !check_if_should_apply_damage)
    set_deflect_shell(victim, invul, curTime)

  result = ProjectileHitResult.Ignore
  query(victim) <| $ [es] (dm_parts__bulletTransparent : BoolList const?;
                           dm_parts__dmgMult : FloatList const?;
                           dm_parts__partsArmor : FloatList const?;
                           hitpoints__penetrationStopPower : float const?;
                           material : das_string const?;
                           var hitpoints__bulletInvulnerableCurDamageMult : float?;
                           var hitpoints__invulnerableTimeTo : float?;
                           isAlive = true;
                           needsBlood : bool const?;
                           hitpoints__bulletInvulnerableNextDamageMult = 2.0;
                           hitpoints__maxDamageReductionMult = 0.1;
                           hitpoints__maxPartArmorForBloodFx = 0.0;
                           entity_mods__lessStoppingPower = 0.0;
                           hitpoints__hp = 1.0)
    assume newHitPos = isect.pos

    var entityPmid = -1
    if !invul.haveDeflectedShell
      entityPmid = get_material_id(material ?? ((needsBlood ?? false) ? "flesh" : "default"))
      sendEvent(victim, EventOnProjectileHit(hitPos = newHitPos, norm = isect.norm, shellId = int(shellId.shellId),
                          physMatId = entityPmid, collNodeId = isect.collNodeId, projectileEid = projectile_eid))

    if dm_parts__bulletTransparent == null || dm_parts__dmgMult == null || dm_parts__partsArmor == null
      if needsBlood ?? false
        onHitFxApply |> invoke(hitpoints__hp, true, 0.0/*damage*/, entityPmid, true)
      return

    if (*dm_parts__bulletTransparent)?[isect.collNodeId] ?? false
      return

    let kineticDamageMult = get_float(gun_eid, "gun__kineticDamageMult") ?? 1.f
    let partDmgMult = kineticDamageMult * ((*dm_parts__dmgMult)?[isect.collNodeId] ?? 1.f)
    let waterArmor = max(0.f, isect.t - waterLen) * get_damage_model_params().waterArmorThicknessEquivalent
    let partArmorRaw = (*dm_parts__partsArmor)?[isect.collNodeId] ?? 0.f
    let partArmor = max(invul.haveDeflectedShell ? invul.deflArmor : 0.f, partArmorRaw)

    let totalProjectileDist = projectileDist + piercing_shift
    var projectileStartSpeed = 0.0
    shell_start_get_props(int(shellId.shellId)) <| $(shellStartProps : ShellStartProps)
      projectileStartSpeed = shellStartProps.speed
    let kineticDamage = calc_kinetic_damage(int(shellId.shellId), totalProjectileDist, projectileStartSpeed)

    let totalPartArmor = waterArmor + partArmor

    let armorPowerMult = get_float(gun_eid, "gun__armorPowerMult") ?? 1.f
    let penetration = armorPowerMult * calc_armor_penetration(int(shellId.shellId), int(shellId.damageId), *ballProjProps,
                                               totalProjectileDist, projectileStartSpeed)
    let reductionMult = cvt(totalPartArmor, 0.f, penetration, 1.f, hitpoints__maxDamageReductionMult)
    let damageMult = partDmgMult * reductionMult

    var damage = kineticDamage * damageMult
    var stoppingPower = calc_stopping_power(entity_mods__lessStoppingPower, int(shellId.shellId), partDmgMult)
    let isDamageReduced = invul.isDamageReduced && is_server()
    if isDamageReduced && hitpoints__bulletInvulnerableCurDamageMult != null
      assume curDamageMult = *hitpoints__bulletInvulnerableCurDamageMult
      damage *= curDamageMult
      stoppingPower *= curDamageMult
      curDamageMult *= hitpoints__bulletInvulnerableNextDamageMult
      if curDamageMult >= 1.0 && hitpoints__invulnerableTimeTo != null
        *hitpoints__invulnerableTimeTo = curTime


    query(gun_eid) <| $ [es] (gun_entity_mods__damageMult : float = 1.0)
      damage *= gun_entity_mods__damageMult

    if is_server()
      let dd = DamageDesc(DamageType.DM_PROJECTILE, damage, newHitPos, dir, isect.norm, int(shellId.shellId),
                          int(launch_desc.gunPropsId), int(isect.collNodeId), stoppingPower, /*actionPropsId*/ -1,
                          damageMult, reductionMult, penetration)
      if (check_if_should_apply_damage)
        damage_entity(victim, offender, dd)
      else
        apply_damage(victim, offender, dd)
    else
      let proj_hit_info = ProjectileHitInfo(isect = isect, vel = vel, dir = dir, waterLen = waterLen,
        prevProjDist = prev_projectile_dist, piercingShift = piercing_shift, timeOfHit = curTime, allowDetonation = allow_detonation)
      notify_server_about_projectile_hit(victim, offender, gun_eid, launch_desc, proj_hit_info,
        sceneHitRicochetStability, trace_ray_mat_id)

    sendEvent(victim, EventOnPhysImpulse(atTime = get_sync_time(), nodeId = isect.collNodeId, pos = newHitPos,
                        impulse = vel * (*ballProjProps).mass))

    if allow_detonation
      detonate_shell_server(projectile_eid, shellId, int(launch_desc.gunPropsId), newHitPos, offender,
                            INVALID_ENTITY_ID, isect.norm, INVALID_ENTITY_ID)

    broadcastEvent(ProjectileHitShake(position = newHitPos, damage = damage))

    let updatePiercingShift = projectile_eid != INVALID_ENTITY_ID
    let canPierceRes = can_projectile_pierce_hp_entity(gun_eid, int(launch_desc.shellId.shellId), int(shellId.damageId),
                                                       damage, projectileStartSpeed, projectileDist, piercing_shift, armorPowerMult,
                                                       updatePiercingShift, hitpoints__penetrationStopPower)
    if updatePiercingShift
      query(projectile_eid) <| $ [es] (var dm_projectile_state : ProjectileState&)
        dm_projectile_state.piercingShift = canPierceRes.newPiercingShift

    result = ((isAlive && !canPierceRes.canPierce) ? ProjectileHitResult.HitAndDestroyProjectile :
                                                     ProjectileHitResult.HitAndContinue) // Until dead bodies (ragdolls) are synced it shouldn't influence projectiles

    let spawnBloodVfx = (needsBlood ?? true) && partArmor <= hitpoints__maxPartArmorForBloodFx
    onHitFxApply |> invoke(hitpoints__hp, spawnBloodVfx, damage, entityPmid, result == ProjectileHitResult.HitAndDestroyProjectile)


[es]
def melee_attack_hit_time(evt : EventMeleeAttackHit;
                          team aka attacker_team : int = TEAM_UNASSIGNED;
                          var human_weap__lastMeleeAttackAtTime : float&)
  query(evt.targetEid) <| $ [es] (team aka target_team : int = TEAM_UNASSIGNED)
    if attacker_team != target_team
      human_weap__lastMeleeAttackAtTime = get_sync_time()