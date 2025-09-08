require app
require ecs
require ecs.common
require ecs.extra_set
require math.base
require DagorMath
require Dacoll
require DagorRandom
require PhysMat
require game.events.events_game
require active_matter.game.es.anomalies.liana_anomaly_common
require active_matter.game.es.surface_crawler_common

[es(tag=server, on_appear)]
def liana_spawner_crawler_init(evt : Event;
                               liana_anomaly__allowedMats : StringList;
                               var liana_anomaly__allowedMatIds : IntList;
                               var liana_crawler_spawner__createdAt : float&)
  liana_crawler_spawner__createdAt = get_sync_time()
  for m in liana_anomaly__allowedMats
    liana_anomaly__allowedMatIds |> push(get_material_id(string(m)))


[es(tag=server, no_order)]
def liana_crawler_spawner_update(act : UpdateStageInfoAct;
                                 eid : EntityId;
                                 liana__anomalyEid : EntityId;
                                 liana_crawler_spawner__createdAt : float;
                                 liana_crawler_spawner__delay : float;
                                 liana_crawler_spawner__maxLifetime : float;
                                 liana_anomaly__allowedMatIds : IntList;
                                 surface_crawler__lookAhead : float2;
                                 surface_crawler__lookDown : float3;
                                 surface_crawler__curvePerSecond : float;
                                 surface_crawler__curvePerSecondRnd : float;
                                 surface_crawler__rndInfluence : float;
                                 surface_crawler__speed : float;
                                 surface_crawler__maxFrustration : int;
                                 var surface_crawler__frustration : int&;
                                 var surface_crawler__seed : int&;
                                 var surface_crawler__head : float3&;
                                 var surface_crawler__dir : float3&;
                                 var surface_crawler__norm : float3&;
                                 var surface_crawler__matId : int&;
                                 var surface_crawler__active : bool&)
  surface_crawler_update(act.dt,
                          surface_crawler__lookAhead,
                          surface_crawler__lookDown,
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
                          surface_crawler__matId,
                          surface_crawler__active) <| $ [unused_argument(riDesc)] (riDesc : RendInstDesc) {}
  if act.curTime - liana_crawler_spawner__createdAt > liana_crawler_spawner__delay
    if liana_anomaly__allowedMatIds |> has_value(surface_crawler__matId)
      var t = surface_crawler__lookDown.z
      var norm : float3
      if traceray_normalized(surface_crawler__head, -surface_crawler__norm, t, norm)
        query(liana__anomalyEid) <| $ [es] (liana_anomaly__tentacleTempl, liana_anomaly__growTempl : string; liana_anomaly__tentacleLength : float2)
          let firstPoint = surface_crawler__head - surface_crawler__norm * t
          let secondPoint = firstPoint + surface_crawler__norm * 0.1
          createEntity("{liana_anomaly__tentacleTempl}+{liana_anomaly__growTempl}") <| $(init)

            let splinePoints <- [ firstPoint, secondPoint]
            let stamps <- [ 0f, 0f]
            init |> set("liana_growth__stamp", act.curTime)
            init |> set("liana_growth__shadowStamps", stamps)
            init |> set("spline_gen_geometry__points", splinePoints)
            init |> set("liana_growth__shadowPoints", splinePoints)
            init |> set("surface_crawler__head", secondPoint)
            init |> set("liana_growth__maxPoints", 128)
            let targetLength = rnd_float(liana_anomaly__tentacleLength.x, liana_anomaly__tentacleLength.y)
            init |> set("liana_growth__dstBetweenPoints", targetLength / 127.0)
            init |> set("surface_crawler__norm", surface_crawler__dir)
            init |> set("surface_crawler__dir", surface_crawler__norm)
            init |> set("surface_crawler__active", true)
            init |> set("surface_crawler__seed", grnd())
            init |> set("liana__anomalyEid", liana__anomalyEid)
        destroyEntity(eid)
  if act.curTime - liana_crawler_spawner__createdAt > liana_crawler_spawner__maxLifetime
    destroyEntity(eid)