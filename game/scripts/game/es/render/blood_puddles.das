require ecs
require BloodPuddles
require app
require danetlibs.blood_puddles.blood_puddles_events
require danetlibs.package_soldier.render.fx.footstep_events
require game.events.events_game
require DagorMath
require Dacoll
require GamePhys
require PhysMat
require DagorRandom
require game.es.grav_zones_common
require DngDacoll
require game.events.events_active_matter
require RendInst
require DngDm


[es(REQUIRE=blood_footprint_emitter)]
def on_bloody_footstep(evt : EventFootStep; eid : EntityId)
  sendEventImmediate(eid, EventBloodFootStep(pos = evt.pos, dir = evt.direction, nodeId = evt.nodeId))


def private trace_blood_hit(pos, dir : float3;
                            var place, norm : float3&;
                            var size : float&;
                            var ri_desc : RendInstDesc)
  let NUM_ITERATIONS = 5
  let dt = 0.2f
  let initialSpd = 10f
  var vel = dir * initialSpd
  var curPos = pos
  var distTraveled = 0f
  var pmid : int
  let aimRayMatId = PHYSMAT_INVALID
  for _ in range(NUM_ITERATIONS)
    var dist = length(vel)
    let curDir = vel * safeinv(dist)
    dist *= dt
    if !traceray_normalized(curPos, curDir, dist, pmid, norm, ETF_DEFAULT, ri_desc, aimRayMatId)
      vel += get_grav_dir(curPos) * gravity() * dt
      curPos += vel * dt
      distTraveled += dist
      continue
    distTraveled += dist
    place = curPos + curDir * dist
    let SIZE_MULT = 0.2f
    size = distTraveled * SIZE_MULT
    return true
  return false


def private sample_random_dir_from_cone(var dir : float3; cur_pos : float3; inner_radius, outer_radius : float) : float3
  dir = normalize(dir)
  let upRelativeGrav = -get_grav_dir(cur_pos)
  var right = (abs(dir.y) < 1.f - 1e-5f) ? cross(dir, upRelativeGrav) : cross(dir, cross(dir, upRelativeGrav))
  right = normalize(right)
  let up = cross(right, dir)
  let alphaSin = rnd_float(-1f, 1f)
  let alphaCos = sqrt(1f - alphaSin * alphaSin) * (rnd_int(0, 1) > 0 ? 1f : -1f)
  var resultDir = dir + (up * alphaSin + right * alphaCos) * rnd_float(inner_radius, outer_radius)
  resultDir = normalize(resultDir)
  return resultDir


[es(tag=render, on_event=ParallelUpdateFrameDelayed)]
def blood_puddles_resolver_es(evt : Event)
  var bloodPuddlesMgr = get_blood_puddles_mgr()
  if bloodPuddlesMgr == null
    return
  let maxSplashesPerFrame = (*bloodPuddlesMgr).maxSplashesPerFrame
  var splashesPerFrame = 0
  query() <| $ [es] (eid : EntityId;
                     blood_puddles__pos : float3;
                     blood_puddles__dir : float3;
                     var blood_puddles__active : bool&)
    if splashesPerFrame >= maxSplashesPerFrame
      destroyEntity(eid)
      return
    ++splashesPerFrame
    var decalPlace : float3
    var decalNormal : float3
    var size : float
    var riDesc = RendInstDesc()
    if trace_blood_hit(blood_puddles__pos, blood_puddles__dir, decalPlace, decalNormal, size, riDesc)
      if abs(decalNormal.y) < 0.5f
        broadcastEvent(BloodPuddlesLeakDecalEvent(pos = decalPlace, normal = decalNormal, size = size, ri_desc_handle = riDesc.riExtraHandle, hit_pos = blood_puddles__pos, projective = false))
      else
        let MAX_VERTICAL_THRESHOLD = 0.7f
        // projective only if normal is nearly vertical
        let projective = decalNormal.y >= MAX_VERTICAL_THRESHOLD
        broadcastEvent(BloodPuddlesSplashDecalEvent(pos = decalPlace, normal = decalNormal, size = size, ri_desc_handle = riDesc.riExtraHandle, hit_pos = blood_puddles__pos, projective = projective))
        let HIT_DIR_SPRAYS_COUNT = 5
        for _ in range(HIT_DIR_SPRAYS_COUNT)
          let randomDirFromCone = sample_random_dir_from_cone(blood_puddles__dir, blood_puddles__pos, 0.05, 0.1)
          if trace_blood_hit(blood_puddles__pos, randomDirFromCone, decalPlace, decalNormal, size, riDesc)
            broadcastEvent(BloodPuddlesSprayDecalEvent(pos = decalPlace, normal = decalNormal, size = size, ri_desc_handle = riDesc.riExtraHandle, hit_pos = blood_puddles__pos, projective = projective))
    let BOTTOM_SPRAYS_COUNT = 2
    for _ in range(BOTTOM_SPRAYS_COUNT)
      let randomDirFromCone = sample_random_dir_from_cone(get_grav_dir(blood_puddles__pos) - blood_puddles__dir, blood_puddles__pos, 0.15, 0.25)
      if trace_blood_hit(blood_puddles__pos, randomDirFromCone, decalPlace, decalNormal, size, riDesc)
        broadcastEvent(BloodPuddlesSplashEmmiterEvent(start_pos = blood_puddles__pos, target_pos = decalPlace, normal = decalNormal, dir = -blood_puddles__dir, size = size, ri_desc_handle = riDesc.riExtraHandle, grav = get_grav_dir(blood_puddles__pos) * gravity()))
    destroyEntity(eid)
    blood_puddles__active = false


[es(tag=render)]
def blood_puddle_emitter_es(info : ParallelUpdateFrameDelayed;
                            eid : EntityId;
                            blood_puddle_emitter__human : EntityId;
                            blood_puddle_emitter__offset : float3;
                            blood_puddle_emitter__collNodeId : int;
                            var blood_puddle_emitter__lastPos : float3&;
                            var blood_puddle_emitter__stableTime : float&)
  var bloodPuddlesMgr = get_blood_puddles_mgr()
  if bloodPuddlesMgr == null
    destroyEntity(eid)
    return
  var tm : float3x4
  var newPos : float3
  if get_collres_body_tm(blood_puddle_emitter__human, blood_puddle_emitter__collNodeId, tm, "blood_puddle_emitter_es")
    newPos = tm * blood_puddle_emitter__offset
  else
    newPos = blood_puddle_emitter__lastPos
  if length_sq(newPos - blood_puddle_emitter__lastPos) > 4e-4
    blood_puddle_emitter__lastPos = newPos
    blood_puddle_emitter__stableTime = 0f
  else
    blood_puddle_emitter__stableTime += info.dt
  if blood_puddle_emitter__stableTime >= 0.2f
    using() <| $(var pctx : PuddleCtx#)
      pctx.pos = newPos
      pctx.dir = get_grav_dir(newPos)
      if *bloodPuddlesMgr |> tryPlacePuddle(pctx)
        sendEvent(eid, CmdAddBloodPuddleAndDie(pos = pctx.pos, normal = pctx.normal, puddleDist = pctx.puddleDist, riEx = pctx.riEx))
      else
        destroyEntity(eid)


[es(tag=render)]
def add_blood_puddle_and_die_es_event_handler(evt : CmdAddBloodPuddleAndDie;
                                              eid : EntityId)
  var bloodPuddlesMgr = get_blood_puddles_mgr()
  if bloodPuddlesMgr != null
    using() <| $(var pctx : PuddleCtx#)
      pctx.pos = evt.pos
      pctx.normal = evt.normal
      pctx.puddleDist = evt.puddleDist
      pctx.riEx = evt.riEx
      *bloodPuddlesMgr |> addPuddleAt(pctx)
  destroyEntity(eid)


[es(tag=render, after=blood_puddle_emitter_es)]
def blood_splash_emitter_es(info : UpdateStageInfoAct;
                            eid : EntityId;
                            blood_splash_emitter__targetPos : float3;
                            blood_splash_emitter__gravity : float3;
                            blood_splash_emitter__normal : float3;
                            blood_splash_emitter__itm : float3x4;
                            blood_splash_emitter__matrix_id : int;
                            blood_splash_emitter__size : float;
                            var blood_splash_emitter__pos : float3&;
                            var blood_splash_emitter__velocity : float3&)
  var bloodPuddlesMgr = get_blood_puddles_mgr()
  if bloodPuddlesMgr == null
    destroyEntity(eid)
    return
  blood_splash_emitter__pos += blood_splash_emitter__velocity * info.dt
  blood_splash_emitter__velocity += blood_splash_emitter__gravity * info.dt
  // if dot is negative, then emitter is above targetPos relative blood_splash_emitter__gravity
  if dot(-normalize(blood_splash_emitter__gravity), normalize(blood_splash_emitter__targetPos - blood_splash_emitter__pos)) > 0f
    *bloodPuddlesMgr |> addSplash(blood_splash_emitter__targetPos, blood_splash_emitter__normal,
      blood_splash_emitter__itm, blood_splash_emitter__matrix_id, blood_splash_emitter__size)
    destroyEntity(eid)


[es(track=isAlive, REQUIRE=human)]
def create_blood_puddle_net_es_event_handler(evt : Event;
                                             isAlive : bool;
                                             eid : EntityId;
                                             hitpoints__lastHitNodeId : int)
  if !isAlive
    create_blood_puddle_emitter(eid, hitpoints__lastHitNodeId)


[es(REQUIRE=human)]
def blood_bleeding_on_hit_es(evt : EventOnEntityHit;
                             isAlive : bool;
                             eid : EntityId;
                             bleeding_state__bleedingPeriodSec : float;
                             bleeding_state__bleedingDurationSec : float;
                             var bleeding_state__nextBleedTime : float&;
                             var bleeding_state__bleedingEndTime : float&)
  let isBleedingDmg = evt.damageType == int(DamageType.DM_PROJECTILE) ||  evt.damageType == int(DamageType.DM_MELEE)

  if !isAlive || !isBleedingDmg || eid != evt.victim
    return

  let curTime = get_sync_time()
  bleeding_state__nextBleedTime = curTime + bleeding_state__bleedingPeriodSec
  bleeding_state__bleedingEndTime = curTime + bleeding_state__bleedingDurationSec


[es(tag=render, no_order, REQUIRE=human)]
def blood_bleeding_tick_controller_es(info : UpdateStageInfoAct;
                                      isAlive : bool;
                                      transform : float3x4&;
                                      bleeding_state__bleedingEndTime : float;
                                      var bleeding_state__nextBleedTime : float&;
                                      bleeding_state__bleedingPeriodSec : float)
  if !isAlive || info.curTime > bleeding_state__bleedingEndTime || info.curTime < bleeding_state__nextBleedTime
    return

  var bloodPuddlesMgr = get_blood_puddles_mgr()
  if bloodPuddlesMgr == null
    return
  using() <| $(var pctx : PuddleCtx#)
    pctx.pos = transform[3]
    if *bloodPuddlesMgr |> tryPlacePuddle(pctx)
      *bloodPuddlesMgr |> addPuddleAt(pctx, int(BloodPuddlesGroup.BLOOD_DECAL_GROUP_SPRAY))

  bleeding_state__nextBleedTime = info.curTime + bleeding_state__bleedingPeriodSec

def is_blood_enabled()
  var isEnabled = true
  find_query <| $ [es] (isBloodEnabled : bool)
    isEnabled = isBloodEnabled
    return true
  return isEnabled

[es(tag=gameClient)]
def create_blood_puddles_on_explosion(evt : EventEntityDied;
                                      hitpoints__lastShellHitDir : float3;
                                      transform : float3x4;
                                      needsBlood : bool = false)
  if !needsBlood || evt.damageType != int(DamageType.DM_EXPLOSION) || !is_blood_enabled()
    return
  var decalPlace : float3
  var decalNormal : float3
  var size : float
  var riDesc = RendInstDesc()
  let targetPos = transform[3] + float3(0, 0.5, 0)
  let blood_puddles__dir = hitpoints__lastShellHitDir
  let LEAKS_COUNT = 10
  if trace_blood_hit(targetPos + 0.5 * blood_puddles__dir, blood_puddles__dir, decalPlace, decalNormal, size, riDesc)
    for _ in range(LEAKS_COUNT)
      let randomDirFromCone = sample_random_dir_from_cone(blood_puddles__dir, targetPos, 0.05, 0.65)
      createEntity("explosion_blood_puddles_creator") <| $(var init)
        set(init, "explosion_blood_puddles__pos", targetPos)
        set(init, "explosion_blood_puddles__dir", randomDirFromCone)
  else
    for _ in range(LEAKS_COUNT)
      let randomDirFromCone = sample_random_dir_from_cone(float3(0f, -1f, 0f), targetPos, 0.35, 1.25)
      createEntity("explosion_blood_puddles_creator") <| $(var init)
        set(init, "explosion_blood_puddles__pos", targetPos + 0.5 * blood_puddles__dir)
        set(init, "explosion_blood_puddles__dir", randomDirFromCone)
        set(init, "explosion_blood_puddles__isSpray", true)

  let randomDirFromCone = sample_random_dir_from_cone(float3(0f, -1f, 0f), targetPos, 0.15, 0.15)
  createEntity("explosion_blood_puddles_creator") <| $(var init)
    set(init, "explosion_blood_puddles__pos", targetPos)
    set(init, "explosion_blood_puddles__dir", randomDirFromCone)


[es(tag=render)]
def blood_puddles_on_explosion_resolver(info : ParallelUpdateFrameDelayed;
                                        eid : EntityId;
                                        explosion_blood_puddles__pos : float3;
                                        explosion_blood_puddles__dir : float3;
                                        explosion_blood_puddles__isSpray : bool;
                                        var explosion_blood_puddles__active : bool&)
  if (!explosion_blood_puddles__active)
    return

  var decalPlace : float3
  var decalNormal : float3
  var size : float
  var riDesc = RendInstDesc()
  if trace_blood_hit(explosion_blood_puddles__pos, explosion_blood_puddles__dir, decalPlace, decalNormal, size, riDesc)
    if (!explosion_blood_puddles__isSpray)
      broadcastEvent(BloodPuddlesExplosionEmmiterEvent(pos = decalPlace, normal = decalNormal, size = size, ri_desc_handle = riDesc.riExtraHandle, hit_pos = explosion_blood_puddles__pos, projective = false))
    else
      broadcastEvent(BloodPuddlesSprayDecalEvent(pos = decalPlace, normal = decalNormal, size = size, ri_desc_handle = riDesc.riExtraHandle, hit_pos = explosion_blood_puddles__pos, projective = false))
  destroyEntity(eid)
  explosion_blood_puddles__active = false
