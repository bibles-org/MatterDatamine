require app
require ecs
require ecs.common
require math.base
require DagorRandom
require DagorMath
require GridCollision
require DngHuman
require game.events.events


[es(tag=server, on_appear)]
def generate_darkness_anomaly(evt : Event;
                              movable_anomaly_config__templateName : string;
                              movable_anomaly_config__filling : float;
                              movable_anomaly_config__zLength : float2)
  if movable_anomaly_config__filling <= 0f
    return

  query() <| $ [es(REQUIRE=darknessAnomalySpot)] (eid : EntityId; transform : float3x4)
    if gfrnd() < movable_anomaly_config__filling
      createEntity(movable_anomaly_config__templateName) <| $(init)
        init |> set("darkness_anomaly__spotEid", eid)
        var tm = transform
        var zoneLen = rnd_float(movable_anomaly_config__zLength.x, movable_anomaly_config__zLength.y)
        let tm2Len = length(tm[2])
        zoneLen = min(tm2Len, zoneLen)
        tm[2] = normalize(tm[2]) * zoneLen
        init |> set("darkness_anomaly__maxZOffset", (tm2Len - zoneLen) * 0.5)
        init |> set("transform", tm)
        if zoneLen < tm2Len
          init |> set("darkness_anomaly__moveZDir", gfrnd() >= 0.5 ? 1 : -1)


[es(tag=server, before=box_anomaly_update)]
def darkness_anomaly_move(act : UpdateStageInfoAct;
                          box_anomaly__nextUpdateAt, box_anomaly__nextUpdateInterval : float;
                          darkness_anomaly__maxZOffset : float;
                          darkness_anomaly__moveZSpeed : float2;
                          darkness_anomaly__spotEid : EntityId;
                          box_anomaly__targetEids : EidList&;
                          var darkness_anomaly__currentMoveZSpeed : float&;
                          var darkness_anomaly__moveZDir : int&;
                          var transform aka anomaly_transform : float3x4&)
  if act.curTime < box_anomaly__nextUpdateAt // TODO: add separate timer for movement
    return
  if length(box_anomaly__targetEids) == 0 && darkness_anomaly__maxZOffset > 0f
    query(darkness_anomaly__spotEid) <| $ [es] (transform : float3x4)
      let dt = box_anomaly__nextUpdateAt > 0f ? box_anomaly__nextUpdateInterval : 0f
      let newOffset = float(darkness_anomaly__moveZDir) * darkness_anomaly__currentMoveZSpeed * dt
      anomaly_transform[3] += normalize(anomaly_transform[2]) * newOffset

      let distanceToCenterSq = distance_sq(anomaly_transform[3], transform[3])
      if darkness_anomaly__moveZDir > 0 && distanceToCenterSq > square(darkness_anomaly__maxZOffset)
        darkness_anomaly__moveZDir = -darkness_anomaly__moveZDir
        darkness_anomaly__currentMoveZSpeed = rnd_float(darkness_anomaly__moveZSpeed.x, darkness_anomaly__moveZSpeed.y)
      elif darkness_anomaly__moveZDir < 0 && distanceToCenterSq > square(darkness_anomaly__maxZOffset)
        darkness_anomaly__moveZDir = -darkness_anomaly__moveZDir
        darkness_anomaly__currentMoveZSpeed = rnd_float(darkness_anomaly__moveZSpeed.x, darkness_anomaly__moveZSpeed.y)
