require app // get_sync_time
require ecs
require ecs.safe
require ecs.common
require dm
require math.base
require math.random
require DngNet
require DngCamera
require DagorMath
require DagorSystem
require danetlibs.weaponry_hit_fx.main.weaponry_hit_fx_forward_events
require danetlibs.weapons.shell_events
require danetlibs.weaponry_hit_fx.main.shell_fx_common
require danetlibs.weaponry_hit_fx.main.weaponry_fx_common
require danetlibs.weaponry_hit_fx.render.weaponry_fx_render_common
require danetlibs.damage_decals.damage_decals_events
require DngWeapon
require DngWeaponRender
require DngDm
require DaWeaponProps
require Dacoll
require DngPhysObj
require strings
require level
require PhysMat
require BallisticsProps

def spawn_effect_aux(pos : float3;
                     fx_name : string;
                     riex_handle : riex_handle_t = RIEX_HANDLE_NULL;
                     norm : float3 = float3(0, 1, 0))
  let isPaintFxOnHit = riex_isRiGenExtraValid(riex_handle) ? riex_isPaintFxOnHit(riex_handle) : true
  spawn_hit_effect(norm, pos, fx_name, isPaintFxOnHit)

def spawn_effect(fx_info_eid : EntityId; pos : float3; is_under_water : bool)
  var riExtraHandle : riex_handle_t
  let fxName = get_fx_name_based_on_floor(pos, fx_info_eid, is_under_water, riExtraHandle)
  spawn_effect_aux(pos, fxName, riExtraHandle)

def random_direction_in_sphere(axis_dir : float3; theta_range : float2 = float2(-0.5 * PI, 0.5 * PI))
  let phi = rnd_float(0.f, 2.f * PI)
  var sin_phi = 0.0
  var cos_phi = 0.0
  sincos(phi, sin_phi, cos_phi)
  let sin_theta = rnd_float(sin(theta_range.x), sin(theta_range.y))
  let cos_theta = sqrt(1.0 - square(sin_theta))
  var tm = float3x3()
  tm[0] = normalize(axis_dir)
  tm[1] = normalize_default(cross(tm[0], float3(1, 0, 0)), float3(0, 1, 0))
  tm[2] = normalize(cross(tm[0], tm[1]))
  let dir = tm * float3(sin_theta, cos_theta * cos_phi, cos_theta * sin_phi)
  return dir

def get_id_from_name(arr : Array; name : string)
  for id, elem in iter_range(arr), arr
    let curName = (elem as Object)?.name ?as string
    if curName == null
      return -1
    if name == *curName
      return id
  return -1

[es(tag=render, on_appear, after=global_hit_fx_init_es)]
def shatter_fx_init_es(evt : Event;
                       global_hit_fx__effectGroups : Array;
                       global_shatter_fx__effectGroups : StringList;
                       var global_shatter_fx__effectDescriptors : IntList&)
  for effectGroup in global_shatter_fx__effectGroups
    let effectDescriptor = get_id_from_name(global_hit_fx__effectGroups, string(effectGroup)) + 1
    if effectDescriptor <= 0
      logerr("shatter_fx_init_es: effect group name {effectGroup} in global_shatter_fx__effectGroups does not exist in global_hit_fx__effectGroups")
    global_shatter_fx__effectDescriptors |> push(effectDescriptor)

[es(tag=render, on_event=ParallelUpdateFrameDelayed, after=after_net_phys_sync)]
def shatter_fx_es(evt : Event;
                  eid : EntityId;
                  shatter_fx__traceCountPerFrame : int;
                  shatter_fx__explosionOffsettedPos : float3;
                  shatter_fx__effectDescriptor : int;
                  shatter_fx__explosionNorm : float3;
                  shatter_fx__belowExplosionProbability : float;
                  shatter_fx__belowExplosionMinTheta : float;
                  shatter_fx__belowExplosionMaxTheta : float;
                  shatter_fx__minRadius : float;
                  shatter_fx__radius : float;
                  var shatter_fx__traceCount : int&)
  if shatter_fx__traceCount <= 0
    destroyEntity(eid)
    return

  let traceCountThisFrame = (shatter_fx__traceCount > shatter_fx__traceCountPerFrame ?
    shatter_fx__traceCountPerFrame : shatter_fx__traceCount)
  shatter_fx__traceCount -= traceCountThisFrame

  let explosionNorm = length_sq(shatter_fx__explosionNorm) > 0.001 ? shatter_fx__explosionNorm : float3(1, 0, 0)
  let isExplNearSurface = shatter_fx__belowExplosionMinTheta > -0.5 * PI + 0.01

  find_query() <| $ [es] (global_hit_fx__effectGroups : Array)
    let effectGroup = global_hit_fx__effectGroups[shatter_fx__effectDescriptor - 1] as Object
    if effectGroup == null
      return true
    for _ in range(traceCountThisFrame)
      // If the explosion occured close to a surface, we don't want to make traces with theta < minTheta
      // (traceray distance would probably be less than shatter_fx__minRadius),
      // and we split theta values into 2 intervals: [minTheta, maxTheta] and [maxTheta, 0.5*PI].
      // Using values from 1st interval is very likely to result in tracerays hitting something,
      // while using values from 2nd interval will result in a lot of failed tracerays (many of them going to the sky).
      // For this reason, we choose one of those two intervals with configured probability shatter_fx__belowExplosionProbability.
      // This will ensure we won't waste too many tracerays and we'll see enough shatter fxs on the ground
      // while also seeing some on the nearby walls/ceiling.
      // However, if the explosion occured in the air, we send tracerays uniformly with theta from -0.5*PI to 0.5*PI.
      let dir = random_direction_in_sphere(explosionNorm,
        (isExplNearSurface && rnd_float(0.0, 1.0) < shatter_fx__belowExplosionProbability) ?
        float2(shatter_fx__belowExplosionMinTheta, shatter_fx__belowExplosionMaxTheta) :
        float2(shatter_fx__belowExplosionMaxTheta, 0.5 * PI))
      var pmid = -1
      var norm = float3()
      var t = shatter_fx__radius
      var riDesc = RendInstDesc()
      traceray_normalized(shatter_fx__explosionOffsettedPos, dir, t, pmid, norm, ETF_LMESH | ETF_HEIGHTMAP | ETF_FRT | ETF_RI | ETF_STRUCTURES, riDesc, -1)
      if t < shatter_fx__minRadius
        continue
      var pos = shatter_fx__explosionOffsettedPos + dir * t
      let isWaterHit = traceray_water_at_time(shatter_fx__explosionOffsettedPos, pos, get_sync_time(), t)
      if t < shatter_fx__minRadius || t >= shatter_fx__radius
        continue
      broadcastEvent(CmdRendinstShatterDecal(pos = pos, norm = norm, pmid = pmid, riexHandle = riDesc.riExtraHandle))
      if isWaterHit
        pmid = get_material_id("water3d")
      pos = shatter_fx__explosionOffsettedPos + dir * t
      let impactResult = isWaterHit ? EffectImpactResult.Penetration : EffectImpactResult.Stop
      let fxName = get_projectile_fx_name_from_effect_group(*effectGroup, pmid, impactResult)
      spawn_effect_aux(pos, fxName, riDesc.riExtraHandle, norm)
    return true

def spawn_shatters(expl_pos : float3; offs_expl_pos : float3; shell_mass : float; shell_id : ShellPropIds)
  using() <| $(var shatterParams : SyntheticShattersParams#)
    shatterParams = calc_synthetic_shatter_params(int(shell_id.damageId), shell_mass, false)
    if shatterParams.count <= 0.0
      return

    find_query() <| $ [es] (global_hit_fx__effectGroups : Array;
                            global_shatter_fx__countToTraceCount : float4;
                            global_shatter_fx__radiusToTraceRadius : float4;
                            global_shatter_fx__minRadiusRatio : float;
                            global_shatter_fx__maxDistance : float;
                            global_shatter_fx__maxShellMasses : FloatList;
                            global_shatter_fx__effectDescriptors : IntList)
      let traceCount = int(cvt(shatterParams.count,
                               global_shatter_fx__countToTraceCount.x,
                               global_shatter_fx__countToTraceCount.y,
                               global_shatter_fx__countToTraceCount.z,
                               global_shatter_fx__countToTraceCount.w))
      if traceCount <= 0
        return true

      let camTm = get_cur_cam_entity() |> get_TMatrix("transform")
      if camTm == null
        return true
      let distSqToCam = length_sq(offs_expl_pos - (*camTm)[3])
      if distSqToCam > square(global_shatter_fx__maxDistance)
        return true

      // Shatter fxs will occur at distances in range [minRadius; radius] from the explosion.
      // We need minRadius because without it some shatter fxs would spawn too close to the explosion
      // and be hidden by the explosion fx.
      // We need radius because we don't want shatter fxs to spawn too far from the explosion.
      let shatterRadius = max(shatterParams.radius,
        get_shell_max_radius(int(shell_id.shellId), int(shell_id.damageId), int(shell_id.ballisticsId)))
      let radius = cvt(shatterRadius,
                       global_shatter_fx__radiusToTraceRadius.x,
                       global_shatter_fx__radiusToTraceRadius.y,
                       global_shatter_fx__radiusToTraceRadius.z,
                       global_shatter_fx__radiusToTraceRadius.w)

      let posInCamCs = inverse(*camTm) * offs_expl_pos
      if posInCamCs.z < 0.0 && distSqToCam > square(radius)
        return true

      let minRadius = global_shatter_fx__minRadiusRatio * radius

      var descriptor = 0
      for maxShellMass, effectDescriptor in global_shatter_fx__maxShellMasses, global_shatter_fx__effectDescriptors
        if shell_mass < maxShellMass
          descriptor = effectDescriptor
          break
      if descriptor <= 0 || descriptor > length(global_hit_fx__effectGroups)
        return true

      let offset = expl_pos - offs_expl_pos
      var t = length(offset)
      var norm = float3()
      var minTheta = -0.5 * PI
      var maxTheta = -0.5 * PI
      if t > 0.001
        let dir = offset / t
        t += 0.05
        var pmid = -1
        var riDesc = RendInstDesc()
        if traceray_normalized(offs_expl_pos, dir, t, pmid, norm, ETF_LMESH | ETF_HEIGHTMAP | ETF_FRT | ETF_RI | ETF_STRUCTURES, riDesc, -1)
          let distanceToSurface = abs(dot(offset, norm))
          if minRadius > distanceToSurface
            minTheta = -asin(distanceToSurface / minRadius)
            maxTheta = -asin(distanceToSurface / radius)

      createEntity("shatter_fx") <| $(var init : ComponentsInitializer)
        set(init, "shatter_fx__traceCount", traceCount)
        set(init, "shatter_fx__explosionOffsettedPos", offs_expl_pos)
        set(init, "shatter_fx__effectDescriptor", descriptor)
        set(init, "shatter_fx__explosionNorm", norm)
        set(init, "shatter_fx__belowExplosionMinTheta", minTheta)
        set(init, "shatter_fx__belowExplosionMaxTheta", maxTheta)
        set(init, "shatter_fx__minRadius", minRadius)
        set(init, "shatter_fx__radius", radius)
      return true


[es(tag=gameClient, REQUIRE=msg_sink)]
def shell_explode_es(shellExpl : CmdShellExplodeClient)
  detonate_shell_client(shellExpl.shellId, shellExpl.pos, shellExpl.offsetedPos,
                        shellExpl.explVictim, shellExpl.explDamageAndFatal)

  var isUnderWater = false
  let posAdjusted = get_adjusted_pos_for_effect(shellExpl.pos, isUnderWater)

  if shellExpl.fxInfoEid != INVALID_ENTITY_ID
    spawn_effect(shellExpl.fxInfoEid, posAdjusted, isUnderWater)

  if !isUnderWater
    let projectileProps = projectile_try_get_props(int(shellExpl.shellId.shellId))
    if projectileProps != null
      spawn_shatters(shellExpl.pos, shellExpl.offsetedPos, projectileProps.mass, shellExpl.shellId)
    elif is_level_loaded()
      logerr("Projectile props not found for shellId={shellExpl.shellId.shellId}!
offender=<{shellExpl.offender}> ({getEntityTemplateName(shellExpl.offender)})
explPos={shellExpl.pos}
fxInfoEid=<{shellExpl.fxInfoEid}> ({getEntityTemplateName(shellExpl.fxInfoEid)})
curTime={get_sync_time()}")

  find_query() <| $ [es(REQUIRE=msg_sink)] (eid : EntityId)
    sendEventImmediate(
      eid,
      EventOnShellExploded(
        explPos = shellExpl.pos,
        shellId = shellExpl.shellId.shellId,
        damageId = shellExpl.shellId.damageId,
        ballisticsId = shellExpl.shellId.ballisticsId,
        gunPropsId = shellExpl.gunPropsId,
        owner = shellExpl.offender))
    return true

[es(tag=render, track=shell__isUnderwater)]
def shell_water_splash_es(evt : Event;
                          phys_obj_net_phys : PhysObjActor;
                          shell__isUnderwater : bool;
                          shell__waterImpactFx : string;
                          shell__waterImpactFxSpeedSqLimit = 0.01)
  if shell__isUnderwater
    let vel = phys_obj_net_phys.phys.currentState.velocity
    if length_sq(vel) > shell__waterImpactFxSpeedSqLimit //to avoid multiple triggers on shallow water
                                                         //or if the water surface is dynamic
      spawn_effect_aux(float3(phys_obj_net_phys.phys.currentState.location.P), shell__waterImpactFx)

[es(tag=gameClient, REQUIRE=msg_sink)]
def client_set_hit_dir_from_shell_explosion(shellExpl : CmdShellExplodeClient)
  for eid in shellExpl.explVictim
    query(eid) <| $ [es] (transform : float3x4; var hitpoints__lastShellHitDir : float3&)
      hitpoints__lastShellHitDir = normalize(transform[3] - shellExpl.pos)