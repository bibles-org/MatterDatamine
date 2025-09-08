require ecs
require DagorRandom
require Grid
require DagorMath
require math.random
require math.base
require game.events.events_active_matter


struct RotOrientDesc
  angles : float3
  orient : int3


def private change_zone_pos(places : Array;
                            min_max_duration : float2;
                            visual_template : string;
                            var duration : float&;
                            var time_left : float&;
                            var zone_transform : float3x4&;
                            var box_size : float3&;
                            var cur_place_idx : int&;
                            var visual_eid : EntityId&)
  if length(places) == 0
    return

  duration = rnd_float(min_max_duration.x, min_max_duration.y)
  time_left = duration

  var shuffledIndexes <- get_shuffled_indexes(places, length(places))
  let curPlaceIdx = find_index(shuffledIndexes, cur_place_idx)
  if curPlaceIdx != -1
    erase(shuffledIndexes, curPlaceIdx)
  cur_place_idx = shuffledIndexes[0]

  let obj = get_ecs_object(places[cur_place_idx])
  if obj == null
    return

  let orientTable = fixed_array(
    RotOrientDesc(angles = float3(HALF_PI, HALF_PI, 0f), orient = int3(1, 2, 0)),
    RotOrientDesc(angles = float3(HALF_PI, -HALF_PI, 0f), orient = int3(1, 2, 0)),
    RotOrientDesc(angles = float3(0f, HALF_PI, 0f), orient = int3(1, 0, 2)),
    RotOrientDesc(angles = float3(0f, -HALF_PI, 0f), orient = int3(1, 0, 2)),
    RotOrientDesc(angles = float3(0f, PI, 0f), orient = int3(0, 1, 2)))
  let orientTableIdx = rnd_int(0, length(orientTable) - 1)

  var rotQ : quat
  euler_to_quat(orientTable[orientTableIdx].angles.x, orientTable[orientTableIdx].angles.y, orientTable[orientTableIdx].angles.z, rotQ)

  var tm = obj |> get_TMatrix("tm") ?? IDENT_TM
  tm |> orthonormalize()
  let q = DagorMath::quat(tm) * rotQ
  make_tm(q, zone_transform)
  zone_transform[3] = tm[3]

  let boxSize = obj |> get_Point3("size") ?? float3(1f)
  for i in range(3)
    box_size[i] = boxSize[orientTable[orientTableIdx].orient[i]]

  let visualPos = obj |> get_Point3("visualPos") ?? zone_transform[3]
  var visualTm = IDENT_TM
  visualTm[3] = visualPos
  if visual_eid == INVALID_ENTITY_ID
    visual_eid = createEntity(visual_template) <| $(var init)
      set(init, "transform", visualTm)
  else
    query(visual_eid) <| $ [es] (var transform : float3x4&)
      transform[3] = visualTm[3]


[es(tag=server, on_appear)]
def init_indoor_grav_zone(evt : Event;
                          indoor_grav_zone__minMaxDuration : float2;
                          indoor_grav_zone_mgr__places : Array;
                          indoor_grav_zone__visualTempl : string;
                          var indoor_grav_zone__duration : float&;
                          var gravity_zone__boxSize : float3&;
                          var transform : float3x4&;
                          var indoor_grav_zone__timeLeft : float&;
                          var indoor_grav_zone__curPlaceIdx : int&;
                          var indoor_grav_zone__visualEid : EntityId&)

  change_zone_pos(indoor_grav_zone_mgr__places,
                  indoor_grav_zone__minMaxDuration,
                  indoor_grav_zone__visualTempl,
                  indoor_grav_zone__duration,
                  indoor_grav_zone__timeLeft,
                  transform,
                  gravity_zone__boxSize,
                  indoor_grav_zone__curPlaceIdx,
                  indoor_grav_zone__visualEid)


[es(tag=server, on_disappear)]
def unload_indoor_grav_zone(evt : Event;
                            indoor_grav_zone__visualEid : EntityId)
  destroyEntity(indoor_grav_zone__visualEid)


[es(tag=server, no_order)]
def indoor_grav_zone_act(info : ParallelUpdateFrameDelayed;
                         indoor_grav_zone__minMaxDuration : float2;
                         indoor_grav_zone_mgr__places : Array;
                         var indoor_grav_zone__visualEid : EntityId&;
                         var indoor_grav_zone__duration : float&;
                         var gravity_zone__boxSize : float3&;
                         var transform aka zone_transform : float3x4&;
                         var indoor_grav_zone__timeLeft : float&;
                         var indoor_grav_zone__curPlaceIdx : int&)
  indoor_grav_zone__timeLeft -= info.dt

  if indoor_grav_zone__timeLeft <= 0f
    change_zone_pos(indoor_grav_zone_mgr__places,
                    indoor_grav_zone__minMaxDuration,
                    "",
                    indoor_grav_zone__duration,
                    indoor_grav_zone__timeLeft,
                    transform,
                    gravity_zone__boxSize,
                    indoor_grav_zone__curPlaceIdx,
                    indoor_grav_zone__visualEid)


[es(tag=gameClient, no_order)]
def indoor_grav_zone_visual_act(info : ParallelUpdateFrameDelayed;
                                indoor_grav_zone__visualEid : EntityId;
                                indoor_grav_zone__timeLeft : float;
                                indoor_grav_zone__duration : float)
  assume timeLeft = indoor_grav_zone__timeLeft
  assume duration = indoor_grav_zone__duration
  assume durationOfScale = indoor_euclid_anomaly_visual__durationOfScale

  query(indoor_grav_zone__visualEid) <| $ [es] (indoor_euclid_anomaly_visual__durationOfScale : float;
                                                var transform : float3x4&)

    let isUpScale = duration - durationOfScale <= timeLeft
    let isDownScale = durationOfScale >= timeLeft
    if !isUpScale && !isDownScale
      return

    let scale = (isUpScale ? cvt(timeLeft, duration, duration - durationOfScale, 0.01f, 1f) :
                             cvt(timeLeft, durationOfScale, 0f, 1f, 0.01f))
    transform |> orthonormalize()
    let newTm = scale_tm(scale) * transform
    transform[0] = newTm[0]
    transform[1] = newTm[1]
    transform[2] = newTm[2]