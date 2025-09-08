module ai_danger_common shared
require ecs
require app
require walkerai
require math
require math.base
require DagorMath
require DngWalkerai
require Grid
require CollRes
require AnimV20
require Dacoll
require RendInst
require SmokeOccluder
require DngHuman
require game.es.ai.walker_common
require game.es.entity_mods_common


def private logistic(x : float; k = 1.; max = 1.)
  return max / (1. + exp(-k * x))

def private logistic(x : float; coef : float3 /* k, max, x offset */)
  return logistic(x + coef.z, coef.x, coef.y)

def private inv(x : float; coef : float2)
  return coef.y * min(coef.x, safeinv(x))

def calc_target_alertness(dist : float; in_frustum : bool; frustum_cos : float;
                          target_stance : int; is_downed : bool;
                          agent_dangers__maxDangerDist : float;
                          dist_coef : float2 = float2(-0.03, 0.8);
                          in_frustum_coef : float2 = float2(1.8f, 0.25f);
                          frustum_coef : float3 = float3(5., 1f, 0.);
                          frustum_offset : float2 = float2(-0.1, 0.23);
                          crouch_coef : float = 0.85f;
                          crawl_coef : float = 0.5f;
                          downed_coef : float = 0.75f;
                          in_vehicle_coef : float = 1.f) : float
  var stanceK = 1.0f
  if is_downed
    stanceK = downed_coef
  elif target_stance == STANCE_CROUCH
    stanceK = crouch_coef
  elif target_stance == STANCE_CRAWL
    stanceK = crawl_coef
  let distK = logistic(dist, float3(dist_coef.x, dist_coef.y, -agent_dangers__maxDangerDist * stanceK * in_vehicle_coef))
  let frustumK = frustum_offset.y * (logistic(frustum_cos, frustum_coef) + frustum_offset.x) * (in_frustum ? in_frustum_coef.x : in_frustum_coef.y)
  return saturate(distK + frustumK)


def private time_to_dt(cur_time : float; time : float; defVal : float)
  return time < 0f ? defVal : cur_time - time


def calc_danger(cur_time, agent_dangers__maxDangerDist : float; danger : Danger | #; ai_target : Target | #; ai_target__noiseLevel : float; is_ai : bool;
                ai_coef : float2 = float2(1., 1.);
                avoid_bullets_near_time : float = 10f;
                last_shoot_coef : float2 = float2(1., 1.);
                noise_coef : float2 = float2(0.2, 1f);
                last_bullet_nearby_coef : float2 = float2(10f, 10f);
                attraction_mult = 1f) : float
  let aiK = is_ai ? ai_coef.x : ai_coef.y
  let distCutOffMult = danger.distance <= agent_dangers__maxDangerDist ? 1f : 0f
  let noiseK = noise_coef.x * ai_target__noiseLevel + noise_coef.y + inv(ai_target.lastShootTimer, last_shoot_coef)
  return (danger.alertness * distCutOffMult * noiseK * aiK * attraction_mult +
    inv(time_to_dt(cur_time, danger.lastBulletNearbyTime, 1e8), last_bullet_nearby_coef))


def calc_traceable_ratio(cur_time : float; dangerMeter : float; danger : Danger | #) : float
  let timeMult = min(5f, cur_time - danger.lastTraceTime)
  return dangerMeter * timeMult


def get_shoot_ray_mat(human_attached_gun__attachedGunEid, human_weap__currentGunEid : EntityId;
                      default_ray_mat_id : int = -1)
  var res = default_ray_mat_id
  let gunEid = human_attached_gun__attachedGunEid != INVALID_ENTITY_ID ? human_attached_gun__attachedGunEid : human_weap__currentGunEid
  query(gunEid) <| $ [es] (gun__aimRayMatId : int)
    res = gun__aimRayMatId
  return res


def trace_agent_dangers(eid : EntityId;
                        isAlive : bool;
                        var agent_dangers : AgentDangers;
                        agent_dangers__standShootPos : float3;
                        beh_tree__enabled : bool = true;
                        var agent_dangers__nextDangersTraceTime : float&;
                        danger_calc__aiCoef : float2;
                        danger_calc__avoidBulletsNearTime : float;
                        danger_calc__lastShootCoef : float2;
                        danger_calc__noiseCoef : float2;
                        danger_calc__lastBulletNearbyCoef : float2;
                        danger_calc__rayMatId : int;
                        danger_calc__useRayMatForce : bool;
                        danger_calc__tooNearDistance : float;
                        attract_point__eid : EntityId;
                        danger_calc__magnitudeTreshhold : float;
                        danger_calc__observeAngleCosTreshhold : float;
                        human_net_phys__aimDir : float3 const?;
                        navmesh_phys__currentLookDir : float3 const?;
                        agent_dangers__nextDangersTraceCheckTime : float = 0.1f;
                        var human_stat_tracking__targetTracesCount : int?;
                        agent_dangers__minTraceableRatio : float = 3.7;
                        agent_dangers__retraceTargetsTime : float = 30f;
                        agent_dangers__maxDangerDist : float = 100f;
                        agent_dangers_calc__dangerMeterMult : float = 1f;
                        agent_dangers__hmapTraceOffset : float3 = float3(0., 0., 0.);
                        human_attached_gun__attachedGunEid = INVALID_ENTITY_ID;
                        human_weap__currentGunEid = INVALID_ENTITY_ID;
                        var human_stat_tracking__totalDangers : float?)
  if !isAlive || !beh_tree__enabled || length(agent_dangers.dangers) == 0
    return

  let curTime = get_sync_time()

  agent_dangers__nextDangersTraceTime += agent_dangers__nextDangersTraceCheckTime

  let agentEid = eid
  let fromPos = agent_dangers__standShootPos
  let flags = (ETF_ALL) & ~(ETF_LMESH | ETF_HEIGHTMAP)
  var maxRatio = 0f
  var traceTo = INVALID_ENTITY_ID

  var targets : array<tuple<Target const?; float>>
  reserve(targets, length(agent_dangers.dangers))
  for danger in agent_dangers.dangers
    var found = false
    query(danger.eid) <| $ [es(REQUIRE=ai_target)] (ai_target : Target const?;
                                                    entity_mod_values : Object const?;
                                                    attraction__overrideAttractionMult : float const?;
                                                    ai_target__noiseLevel = 0.;
                                                    beh_tree__enabled : bool = false)
      found = true
      let attractionMult = (
        attraction__overrideAttractionMult != null ? *attraction__overrideAttractionMult :
        (entity_mod_values != null ? get_mod_value("attractionMult", *entity_mod_values, 1.0) : 1.0)
      )
      let potentialDangerMeter = calc_danger(curTime, agent_dangers__maxDangerDist, danger, *ai_target, ai_target__noiseLevel, beh_tree__enabled,
                                             danger_calc__aiCoef, danger_calc__avoidBulletsNearTime,
                                             danger_calc__lastShootCoef, danger_calc__noiseCoef, danger_calc__lastBulletNearbyCoef,
                                             attractionMult)
      targets |> emplace((ai_target, potentialDangerMeter))
      let ratio = calc_traceable_ratio(curTime, potentialDangerMeter, danger)
      if ratio > maxRatio
        maxRatio = ratio
        traceTo = danger.eid
    if !found
      targets |> emplace(tuple<Target const?; float>())

  var lookDir : float3
  if human_net_phys__aimDir != null
    lookDir = *human_net_phys__aimDir
  elif navmesh_phys__currentLookDir != null
    lookDir = *navmesh_phys__currentLookDir

  for i in iter_range(agent_dangers.dangers)
    assume danger = agent_dangers.dangers[i]
    query(danger.eid) <| $ [es] (ai_target__alwaysVisible : Tag const?)

      let ai_target = targets[i]._first
      let potentialDangerMeter = targets[i]._last

      let isAlwaysVisible = (ai_target__alwaysVisible != null)
      let isHidden = ai_target.isHidden && !isAlwaysVisible

      if ai_target == null || !ai_target.isAlive || isHidden
        danger.dangerMeter = 0f
        danger.noiseMeter = 0f
        return
      if danger.eid == traceTo && (maxRatio >= agent_dangers__minTraceableRatio || curTime - danger.lastTraceTime > agent_dangers__retraceTargetsTime)
        danger.lastTraceTime = curTime
        let dir = normalize(ai_target.targetPos - fromPos)
        let lmeshTracePos = fromPos + agent_dangers__hmapTraceOffset
        if human_stat_tracking__targetTracesCount != null
          (*human_stat_tracking__targetTracesCount)++
        let rayMatId = (danger_calc__useRayMatForce ?
                        danger_calc__rayMatId :
                        get_shoot_ray_mat(human_attached_gun__attachedGunEid, human_weap__currentGunEid, danger_calc__rayMatId))
        var targetIsVisible = false
        if isAlwaysVisible
          targetIsVisible = true
        else
          if distance_sq(fromPos, ai_target.targetPos) <= square(danger_calc__tooNearDistance)
            let shootMatId = get_shoot_ray_mat(human_attached_gun__attachedGunEid, human_weap__currentGunEid, danger_calc__rayMatId)
            targetIsVisible = !rayhit_normalized(fromPos, dir, danger.distance, flags, shootMatId)
          else
            query(attract_point__eid) <| $ [es] (attract_point__ownerEid : EntityId;
                                                 attract_point__magnitude : float)
              if (attract_point__ownerEid == danger.eid &&
                  attract_point__magnitude >= danger_calc__magnitudeTreshhold &&
                  dot(dir, lookDir) >= danger_calc__observeAngleCosTreshhold)
                targetIsVisible = true
          if !targetIsVisible
            targetIsVisible = !(rayhit_normalized_lmesh(lmeshTracePos, dir, danger.distance) ||
                                rayhit_normalized(fromPos, dir, danger.distance, flags, rayMatId) ||
                                traceTransparencyRayRIGenNormalized(fromPos, dir, danger.distance, 0.01, rayMatId) ||
                                rayhit_smoke_occluders(fromPos, ai_target.targetPos))

          if targetIsVisible
            let t = min(length(ai_target.targetPos - fromPos), danger.distance)
            find_entity_in_grid(fixed_array(ecs_hash("humans"), ecs_hash("vehicles")), fromPos, dir, t, 0.0, GridEntCheck.BOUNDING) <| $(objEid : EntityId)
              if objEid != danger.eid && objEid != agentEid && uint(objEid) != ai_target.useVehicle
                query(objEid) <| $ [es] (transform : float3x4; collres : CollisionResource; animchar : AnimcharBaseComponent)
                  targetIsVisible = !collres_rayhit(collres, transform, animchar.nodeTree, fromPos, dir, t)
              return !targetIsVisible // ray collides
        danger.traceable = targetIsVisible

      danger.dangerMeter = danger.traceable ? potentialDangerMeter : 0.
      danger.dangerMeter *= agent_dangers_calc__dangerMeterMult

      danger.noiseMeter = potentialDangerMeter

  if human_stat_tracking__totalDangers != null
    *human_stat_tracking__totalDangers += float(length(agent_dangers.dangers)) * agent_dangers__nextDangersTraceCheckTime