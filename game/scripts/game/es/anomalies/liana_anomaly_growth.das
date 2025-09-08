require app
require ecs
require ecs.common
require math.base
require DagorSystem
require DagorMath
require DagorRandom
require Dacoll
require RendInst
require DngNet
require game.events.events_game
require game.events.events_active_matter
require active_matter.game.es.anomalies.liana_anomaly_common
require active_matter.game.es.surface_crawler_common
require game.es.riextra_damage_common

[es(no_order)]
def on_liana_growth_vis_update(act : UpdateStageInfoAct;
                               liana_growth__shadowPoints : Point3List;
                               liana_growth__shadowStamps : FloatList;
                               surface_crawler__active : bool;
                               liana_growth__maxPoints : int;
                               liana_growth__radius : float;
                               liana_growth__dstBetweenPoints : float;
                               var spline_gen_geometry__radius : float3&;
                               var spline_gen_geometry__request_active : bool&;
                               var spline_gen_geometry__points : Point3List)
  //assumes length(liana_growth__shadowStamps) == length(liana_growth__shadowPoints) and liana_growth__shadowStamps are increasing
  var curLength = length(spline_gen_geometry__points)
  if curLength <= length(liana_growth__shadowStamps) && act.curTime >= liana_growth__shadowStamps[curLength - 1]
    spline_gen_geometry__points[curLength - 1] = liana_growth__shadowPoints[curLength - 1]
  while curLength < length(liana_growth__shadowStamps) && liana_growth__shadowStamps[curLength] < act.curTime
    spline_gen_geometry__points |> push(liana_growth__shadowPoints[curLength])
    curLength++
  if act.curTime > liana_growth__shadowStamps[curLength - 1] && length(liana_growth__shadowPoints) > curLength
    spline_gen_geometry__points |> push(float3())
    curLength++
  if liana_growth__shadowStamps[curLength - 1] > act.curTime
    let from = liana_growth__shadowPoints[curLength - 2]
    let to = liana_growth__shadowPoints[curLength - 1]
    let t = safediv(act.curTime - liana_growth__shadowStamps[curLength - 2],
                    liana_growth__shadowStamps[curLength - 1] - liana_growth__shadowStamps[curLength - 2])
    spline_gen_geometry__points[curLength - 1] = lerp(from, to, float3(t))

  let legDst = distance(spline_gen_geometry__points[curLength - 1],
                        spline_gen_geometry__points[curLength - 2])
  if legDst > 0.01
    let prevIdxRatio = float(curLength)     / float(liana_growth__maxPoints)
    let nextIdxRatio = float(curLength + 1) / float(liana_growth__maxPoints)
    let thisRatio = lerp(prevIdxRatio, nextIdxRatio, min(1.0, legDst / liana_growth__dstBetweenPoints))
    spline_gen_geometry__radius.x = lerp(spline_gen_geometry__radius.y, liana_growth__radius, thisRatio)

  elif !surface_crawler__active
    spline_gen_geometry__request_active = false


[es(tag=netClient)]
def add_liana_point_from_server(evt : CmdAddSplineGeomPoint;
                                var liana_growth__shadowPoints : Point3List;
                                var liana_growth__shadowStamps : FloatList)
  liana_growth__shadowPoints |> push(evt.point)
  liana_growth__shadowStamps |> push(evt.timeStamp)


[es(tag=server, no_order)]
def on_liana_growth_phys_update(act : UpdateStageInfoAct;
                                eid : EntityId;
                                liana__anomalyEid : EntityId;
                                liana_growth__dstBetweenPoints : float;
                                liana_growth__physToVisDelay : float;
                                liana_growth__maxPoints : int;
                                liana_growth__radius : float;
                                spline_gen_geometry__radius : float3;
                                liana_growth__lookDown : float3 = float3(0.02, 0.025, 0.035);
                                liana_growth__timeStep : float = 0.033;
                                var liana_growth__shadowPoints : Point3List;
                                var liana_growth__shadowStamps : FloatList;
                                var liana_growth__stamp : float&;
                                //surface_crawler:
                                surface_crawler__lookAhead : float2 = float2(0.15, 0.4);
                                surface_crawler__curvePerSecond : float = 4.0;
                                surface_crawler__curvePerSecondRnd : float = 1.0;
                                surface_crawler__rndInfluence : float = 10.0;
                                surface_crawler__speed : float = 1.0;
                                surface_crawler__maxFrustration : int = 10;
                                var surface_crawler__frustration : int&;
                                var surface_crawler__seed : int&;
                                var surface_crawler__head : float3&;
                                var surface_crawler__dir : float3&;
                                var surface_crawler__norm : float3&;
                                var surface_crawler__active : bool&)
  if !surface_crawler__active
    if act.curTime > liana_growth__stamp + liana_growth__physToVisDelay + 1.0
      query(liana__anomalyEid) <| $ [es] (liana_anomaly__growTempl : string)
        remote_remove_sub_template(eid, liana_anomaly__growTempl)
    return
  if length(liana_growth__shadowPoints) < 2
    logerr("liana_growth__shadowPoints.len < 2")
    surface_crawler__active = false
    return
  var maxUpdatesAtOnce = 5
  while maxUpdatesAtOnce-- > 0 && liana_growth__stamp < act.curTime
    liana_growth__stamp += liana_growth__timeStep

    let ratio = float(length(liana_growth__shadowPoints)) / float(liana_growth__maxPoints)
    let radiusAtThisPoint = lerp(liana_growth__radius, spline_gen_geometry__radius.y, ratio)
    let ridusAwareLookDown = liana_growth__lookDown + float3(radiusAtThisPoint)
    var matid : int

    surface_crawler_update(liana_growth__timeStep,
                            surface_crawler__lookAhead,
                            ridusAwareLookDown,
                            surface_crawler__curvePerSecond,
                            surface_crawler__curvePerSecondRnd,
                            surface_crawler__rndInfluence,
                            surface_crawler__speed,
                            surface_crawler__maxFrustration,
                            surface_crawler__frustration,
                            surface_crawler__seed,
                            surface_crawler__head,
                            surface_crawler__dir,
                            surface_crawler__norm,
                            matid,
                            surface_crawler__active) <| $(riDesc : RendInstDesc)
      let riEid = find_ri_extra_eid(riDesc.riExtraHandle)
      query(riEid) <| $ [es(REQUIRE=isDoor)] ()
        sendEvent(riEid, CmdRendinstDamage(handle = riDesc.riExtraHandle,
                                              damage = 100.0,
                                              pos = surface_crawler__head,
                                              impulse = float3(),
                                              time = get_sync_time()))

    let preLastPoint = liana_growth__shadowPoints[length(liana_growth__shadowPoints) - 1]
    if distance_sq(surface_crawler__head, preLastPoint) > square(liana_growth__dstBetweenPoints)
      liana_growth__shadowPoints |> push(surface_crawler__head)
      liana_growth__shadowStamps |> push(get_sync_time() + liana_growth__physToVisDelay)
      send_net_event(eid, CmdAddSplineGeomPoint(point = surface_crawler__head, timeStamp = get_sync_time() + liana_growth__physToVisDelay))
      if liana_growth__maxPoints <= length(liana_growth__shadowPoints)
        surface_crawler__active = false
        break