require ecs
require ecs.common
require app
require net
require strings
require math.base
require math.random
require DagorMath
require DagorSystem
require Grid
require DngNet
require pathfinder
require math.maybe_pos
require game.es.grav_zones_common
require game.es.ai.agent_position_mapping_common

struct GeyserTrackedData
  eid : EntityId;
  pos : float3;
  velocity : float3;
  charge : float;
  scheduledAt : float;
  fireAt : float;
  lastIdx : int;


[es(tag=server, no_order)]
def geyser_anomaly_update(act : UpdateStageInfoAct;//uses grnd()
                          eid : EntityId;
                          transform : float3x4;
                          geyser_anomaly__instanceTemplate : string;
                          geyser_anomaly__maxCharge : float;
                          geyser_anomaly__damagingCharge : float;
                          geyser_anomaly__fade : float;
                          geyser_anomaly__fadeOnHitMult : float;
                          geyser_anomaly__chargePerHumanMeter : float;
                          geyser_anomaly__chargePerVehicleMeter : float;
                          sphere_zone__radius : float;
                          geyser_anomaly__safetyRadius : float;
                          geyser_anomaly__maxRadius : float;
                          geyser_anomaly__interval : float;
                          geyser_anomaly__maxFrequency : float;
                          geyser_anomaly__minFrontSectorDot : float;
                          var geyser_anomaly__updateAt : float&;
                          var geyser_anomaly__trackedPos : Point3List&;
                          var geyser_anomaly__trackedVelocity : Point3List&;
                          var geyser_anomaly__trackedCharge : FloatList&;
                          var geyser_anomaly__trackedScheduled : FloatList&;
                          var geyser_anomaly__trackedFire : FloatList&;
                          var geyser_anomaly__trackedEid : EidList&)
  if act.curTime > geyser_anomaly__updateAt
    let dt = act.curTime - geyser_anomaly__updateAt + geyser_anomaly__interval
    geyser_anomaly__updateAt = act.curTime + geyser_anomaly__interval
    for charge in geyser_anomaly__trackedCharge
      charge = max(.0, charge - dt * geyser_anomaly__fade)

    let sphere = BSphere3(transform[3], sphere_zone__radius)
    var affected : array<GeyserTrackedData>
    for_each_entity_in_grid(ecs_hash("humans"), sphere, GridEntCheck.POS) <| $(human_eid : EntityId)
      charge_from(human_eid,
                  transform[3],
                  geyser_anomaly__chargePerHumanMeter,
                  sphere_zone__radius,
                  affected,
                  geyser_anomaly__trackedPos,
                  geyser_anomaly__trackedVelocity,
                  geyser_anomaly__trackedCharge,
                  geyser_anomaly__trackedEid)
    for_each_entity_in_grid(ecs_hash("vehicles"), sphere, GridEntCheck.POS) <| $(vehicle_eid : EntityId)
      charge_from(vehicle_eid,
                  transform[3],
                  geyser_anomaly__chargePerVehicleMeter,
                  sphere_zone__radius,
                  affected,
                  geyser_anomaly__trackedPos,
                  geyser_anomaly__trackedVelocity,
                  geyser_anomaly__trackedCharge,
                  geyser_anomaly__trackedEid)
    var fireIdxes : array<int>
    for a, i in affected, iter_range(affected)
      if a.lastIdx >= 0
        a.scheduledAt = geyser_anomaly__trackedScheduled[a.lastIdx]
        a.fireAt = geyser_anomaly__trackedFire[a.lastIdx]
      a.charge = min(a.charge, geyser_anomaly__maxCharge)

      let freq = cvt(a.charge, .0, geyser_anomaly__maxCharge, 0.0, geyser_anomaly__maxFrequency)
      let period = freq > 0.001 ? 1.0 / freq : FLT_MAX
      if a.fireAt - a.scheduledAt > period
        a.fireAt = a.scheduledAt + period

      if act.curTime > a.fireAt
        a.fireAt = act.curTime + period
        a.scheduledAt = act.curTime
        fireIdxes |> push(i)

    for fIdx in fireIdxes
      assume data = affected[fIdx]
      let damage = data.charge >= geyser_anomaly__damagingCharge
      var firePos : MaybePos
      if damage
        firePos = find_damaging_fire_pos(data.pos, transform[3], geyser_anomaly__safetyRadius)
        data.charge *= geyser_anomaly__fadeOnHitMult // Or else it is impossible to put out the fire
      else
        let r = cvt(data.charge, .0, geyser_anomaly__damagingCharge, geyser_anomaly__maxRadius, geyser_anomaly__safetyRadius)
        firePos = find_best_fire_pos(data.pos,
                                      transform[3],
                                      data.velocity,
                                      r,
                                      sphere_zone__radius,
                                      geyser_anomaly__safetyRadius,
                                      geyser_anomaly__minFrontSectorDot)
      if firePos is pos
        createEntity(geyser_anomaly__instanceTemplate) <| $(init)
          var tm = IDENT_TM
          tm[3] = firePos as pos
          init |> set("transform", tm)
          init |> set("dmgzone__burningOffender", eid)
          init |> set("fire_source__fullForceTime", 1.0)

    clear(geyser_anomaly__trackedPos)
    clear(geyser_anomaly__trackedVelocity)
    clear(geyser_anomaly__trackedCharge)
    clear(geyser_anomaly__trackedScheduled)
    clear(geyser_anomaly__trackedFire)
    clear(geyser_anomaly__trackedEid)
    for a in affected
      geyser_anomaly__trackedPos |> push(a.pos)
      geyser_anomaly__trackedVelocity |> push(a.velocity)
      geyser_anomaly__trackedCharge |> push(a.charge)
      geyser_anomaly__trackedScheduled |> push(a.scheduledAt)
      geyser_anomaly__trackedFire |> push(a.fireAt)
      geyser_anomaly__trackedEid |> push(a.eid)


def find_damaging_fire_pos(pos, anomaly_pos : float3; radius : float)
  let grav = get_grav_dir(anomaly_pos)
  let ax1 = get_normal(grav)
  let ax2 = cross(grav, ax1)
  let p2d = rnd_point_on_disk(radius)
  return MaybePos(pos + ax1 * p2d.x + ax2 * p2d.y)


def find_best_fire_pos(pos, anomaly_pos, velocity : float3;
                       desired_radius, anomaly_radius, safety_radius, min_dot : float)
  let step = 2.0

  let grav = get_grav_dir(anomaly_pos)
  let ax1 = get_normal(grav)
  let ax2 = cross(grav, ax1)
  let vecToCenter = anomaly_pos - pos
  // Project onto the plane's basis vectors
  let centerPos2d = float2(dot(vecToCenter, ax1), dot(vecToCenter, ax2))
  let (fromAngle, toAngle) = calculate_intersection_angles_2d(desired_radius, centerPos2d, anomaly_radius)

  var samplePoints = sample_points(pos, desired_radius, ax1, ax2, fromAngle, toAngle, step)

  project_points_to_navmesh(samplePoints, safety_radius)


  var weights : array<float>
  let velNorm = normalize(velocity)
  for p in samplePoints
    let rawWeight = dot(velNorm, normalize(p - pos))
    weights |> push(rawWeight > min_dot ? square(rawWeight) : .0)

  return length(samplePoints) > 0 ? MaybePos(samplePoints[choose_weight(weights)]) : MaybePos()


def project_points_to_navmesh(var points : array<float3>; hor_radius : float)
  var i = length(points)
  while i-- > 0
    assume p = points[i]
    let mappingZone = navmesh_mapping_find_best_zone_for_position(p)
    var navPos = navmesh_map_position_in_zone(p, mappingZone)
    if project_to_nearest_navmesh_point(navPos, float3(hor_radius, 10.0, hor_radius))
      p = navmesh_unmap_position_in_zone(navPos, mappingZone)
    else
      erase(points, i)


def sample_points(pos : float3; arc_radius : float; ax1, ax2 : float3; from_angle, to_angle, step : float)
  var res : array<float3>
  if arc_radius <= 0.01
    return <- res
  if step <= 0.01
    return <- res

  let angleRange = to_angle - from_angle
  let angularStep = step / arc_radius
  if angleRange <= angularStep //small range, only a single point exists
    var s, c : float
    sincos((from_angle + to_angle) * 0.5, s, c)
    res |> push(pos + ax1 * c * arc_radius + ax2 * s * arc_radius)
    return <- res

  let numIntervals = int(floor(angleRange / angularStep))
  for i in range(numIntervals + 1)
    let angle = from_angle + float(i) * angularStep
    var s, c : float
    sincos(angle, s, c)
    res |> push(pos + ax1 * c * arc_radius + ax2 * s * arc_radius)
  return <- res


// Assumes the origin is at 0, 0
def calculate_intersection_angles_2d(radius : float; center : float2; limiting_circle_radius : float)
  let dstSq = length_sq(center) // Distance from origin (0,0) to center squared
  let dst = sqrt(dstSq)

  // Concentric
  if dst < FLT_EPSILON
    if radius <= limiting_circle_radius + FLT_EPSILON
      return (0.0, 2.0 * PI)
    else
      return (0.0, 0.0)

  // Circles are too far apart
  if dst > radius + limiting_circle_radius - FLT_EPSILON
    return (0.0, 0.0)

  // One circle contains the other
  if dst < abs(radius - limiting_circle_radius) + FLT_EPSILON
    if radius > limiting_circle_radius + dst // clipping circle is fully inside sampling circle
      return (0.0, 0.0)
    else // sampling circle is fully inside clipping circle
      return (0.0, 2.0 * PI)

  // Two intersection points
  let cosAlphaNumerator = radius * radius + dstSq - limiting_circle_radius * limiting_circle_radius
  let cosAlphaDenominator = 2.0 * radius * dst
  var cosAlpha = cosAlphaNumerator / cosAlphaDenominator
  cosAlpha = clamp(cosAlpha, -1.0, 1.0)
  let alpha = acos(cosAlpha)
  let centerAngle = atan2(center.y, center.x)
  return (centerAngle - alpha, centerAngle + alpha)


def charge_from(eid : EntityId;
                anomaly_pos : float3;
                mult : float;
                anomaly_radius : float;
                var affected : array<GeyserTrackedData>;
                var geyser_anomaly__trackedPos : Point3List;
                var geyser_anomaly__trackedVelocity : Point3List;
                var geyser_anomaly__trackedCharge : FloatList;
                var geyser_anomaly__trackedEid : EidList)
  var lastIdx = -1
  query(eid) <| $ [es(REQUIRE=chargesgeyserAnomaly)] (transform : float3x4)
    var charge = .0
    var vel : float3
    for idx, trackedEid in iter_range(geyser_anomaly__trackedEid), geyser_anomaly__trackedEid
      if trackedEid == eid
        let prevPos = geyser_anomaly__trackedPos[idx]
        charge = geyser_anomaly__trackedCharge[idx]
        let dst = distance(transform[3], prevPos)
        charge += dst * mult
        lastIdx = idx
        vel = dst > .1 ? transform[3] - prevPos : geyser_anomaly__trackedVelocity[idx]
        break
    if lastIdx < 0
      let dstToCenter = distance(transform[3], anomaly_pos)
      charge += (anomaly_radius - dstToCenter) * mult
      vel = anomaly_pos - transform[3] //Too large but doesn't matter, it's going to be normalized
    affected |> emplace(GeyserTrackedData(eid = eid, pos = transform[3], velocity = vel, charge = charge, scheduledAt = .0, fireAt = FLT_MAX, lastIdx = lastIdx))