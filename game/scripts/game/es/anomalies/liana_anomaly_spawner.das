require app
require ecs
require math.base
require math.random
require DagorMath
require Dacoll
require DagorRandom
require PhysMat
require game.events.events_game
require active_matter.game.es.anomalies.liana_anomaly_common

[es(tag=server, REQUIRE=lianaAnomaly)]
def liana_anomaly_zone_enter(evt : EventZoneEnter;
                             eid : EntityId;
                             liana_anomaly__spawnerTempl : string;
                             liana_anomaly__tentacleCount : int;
                             liana_anomaly__spawnerDelayRange : float2;
                             var liana_anomaly__triggered : bool&)
  if liana_anomaly__triggered
    return
  liana_anomaly__triggered = true

  query(evt.visitorEid) <| $ [es] (transform : float3x4)
    let pos = transform[3] + float3(.0, 0.1, .0)
    for i in range(liana_anomaly__tentacleCount)
      let angle = PI * 2.0 * float(i) / float(liana_anomaly__tentacleCount)
      var s, c : float
      sincos(angle, s, c)
      createEntity(liana_anomaly__spawnerTempl) <| $(init)
        init |> set("surface_crawler__dir", float3(s, .0, c))
        init |> set("surface_crawler__norm", float3(0, 1, 0))
        init |> set("surface_crawler__head", pos)
        init |> set("surface_crawler__active", true)
        init |> set("surface_crawler__seed", grnd())
        init |> set("liana_crawler_spawner__delay", rnd_float(liana_anomaly__spawnerDelayRange))
        init |> set("liana__anomalyEid", eid)