require app
require ecs
require ecs.common
require ecs.safe
require math.base
require GeomNodeTree
require DagorRandom
require Dacoll
require RendInst
require SmokeOccluder
require DngWalkerai
require game.es.ai.walker_common
require active_matter.game.es.ai.visual_attraction_common

[es(tag=server, on_appear)]
def on_visual_attract_update_created(evt : Event; eid : EntityId; visual_attract__updateInterval : float;
                                     var visual_attract__nextUpdate : float&)
  visual_attract__nextUpdate = get_sync_time() + visual_attract__updateInterval * eid_frnd(eid)

struct VisualAttractPoint
  pos : float3
  radius : float

[es(tag=server, no_order)]
def track_visual_attract_points(act : UpdateStageInfoAct)

  var points : table<uint; VisualAttractPoint>
  query() <| $ [es] (eid : EntityId; transform : float3x4; visual_attract_point__radius : float)
    if visual_attract_point__radius > 0f
      points.emplace(uint(eid), VisualAttractPoint(pos = transform[3], radius = visual_attract_point__radius))

  query() <| $ [es] (transform : float3x4;
                     visual_attract__maxDist : float;
                     entity_mods__visualAttractMaxDistMult : float = 1f;
                     visual_attract__nextUpdate : float;
                     var visual_attract__points : Array&)
    if act.curTime < visual_attract__nextUpdate
      return

    if length(points) == 0
      visual_attract__points |> clear()
      return

    let maxDistSq = square(visual_attract__maxDist * entity_mods__visualAttractMaxDistMult)
    let fromPos = transform[3]
    for uid, point in keys(points), values(points)

      let prevIdx = visual_attract__points |> each |> find_index_if <| $(it)
        return uint((it as Object)?.eid ?? INVALID_ENTITY_ID) == uid

      let distSq = distance_sq(fromPos, point.pos)
      if distSq > maxDistSq
        if prevIdx >= 0
          visual_attract__points |> erase(prevIdx)
        continue

      if prevIdx >= 0
        var rwData = visual_attract__points[prevIdx] |> getRW_ecs_object()
        if rwData != null
          *rwData |> set("dist", sqrt(distSq))
          *rwData |> set("radius", point.radius)
          *rwData |> set("pos", point.pos)
      else
        using() <| $(var obj : Object)
          obj |> set("eid", EntityId(uid))
          obj |> set("dist", sqrt(distSq))
          obj |> set("radius", point.radius)
          obj |> set("pos", point.pos)
          visual_attract__points |> push(obj)


[es(tag=server, after=track_visual_attract_points)]
def trace_visual_attract_points(act : UpdateStageInfoAct; transform : float3x4;
                                agent_dangers__standShootPos : float3;
                                visual_attract__updateInterval : float;
                                visual_attract__maxDist : float;
                                entity_mods__visualAttractMaxDistMult : float = 1f;
                                var visual_attract__nextUpdate : float&;
                                var visual_attract__points : Array&)
  if act.curTime < visual_attract__nextUpdate
    return
  visual_attract__nextUpdate = act.curTime + visual_attract__updateInterval

  if length(visual_attract__points) == 0
    return

  let fromPos = agent_dangers__standShootPos

  let flags = (ETF_ALL) & ~(ETF_LMESH | ETF_HEIGHTMAP)

  var maxRatio = 0f
  var maxRatioRadius = 0f
  var maxRatioIdx = -1
  for idx, pointData in iter_range(visual_attract__points), visual_attract__points
    let point = pointData as Object
    if point == null
      return
    let radius = (*point).radius ?? 0f
    let dist = (*point).dist ?? 0f
    let lastTraceTime = (*point).lastTraceTime ?? 0f

    let maxDist = visual_attract__maxDist * entity_mods__visualAttractMaxDistMult
    let ratio = calc_traceable_ratio(act.curTime, lastTraceTime, dist, maxDist, radius)
    if ratio > 2f && ratio > maxRatio
      maxRatio = ratio
      maxRatioIdx = idx
      maxRatioRadius = radius

  if maxRatioIdx < 0
    return

  let azimuth = gfrnd() * TWOPI
  let zenith = rnd_float(-HALF_PI, HALF_PI)
  var asin, acos : float
  sincos(azimuth, asin, acos)
  var zsin, zcos : float
  sincos(zenith, zsin, zcos)

  let offset = float3(acos * zcos, zsin, asin * zcos)
  let targetPos = transform[3] + offset * (gfrnd() * maxRatioRadius)
  var dir = targetPos - fromPos
  let traceDist = length(dir)
  var collides = false
  if traceDist > VERY_SMALL_NUMBER
    dir = dir / traceDist
    collides = (rayhit_normalized_lmesh(fromPos, dir, traceDist) ||
                rayhit_normalized(fromPos, dir, traceDist, flags, -1) ||
                traceTransparencyRayRIGenNormalized(fromPos, dir, traceDist, 0.01) ||
                rayhit_smoke_occluders(fromPos, targetPos))
  var pointRW = getRW_ecs_object(visual_attract__points[maxRatioIdx])
  if pointRW != null
    *pointRW |> set("lastTraceTime", act.curTime)
    *pointRW |> set("visible", !collides)
