require ecs
require ecs.common
require math.base
require DagorMath
require DagorRandom
require danetlibs.renderer.includes.pufd_events


[es(tag=gameClient, no_order)]
def update_map_zone_approximate_pos(act : ParallelUpdateFrameDelayed;
                                    eid : EntityId;
                                    transform : float3x4 const?;
                                    item__containerOwnerEid : EntityId = INVALID_ENTITY_ID;
                                    item__humanOwnerEid : EntityId = INVALID_ENTITY_ID;
                                    map_object__show : bool;
                                    map_object_zone__radius : float;
                                    map_object_zone__noiseSpeed : float = 0.2;
                                    map_object_zone__interval : float = 8.0;
                                    var map_object_zone__prevOffset : float3&;
                                    var map_object_zone__updateAt : float&;
                                    var map_object_zone__overridePos : float3&)
  if map_object_zone__updateAt < act.curTime && map_object__show
    let dt = act.curTime - map_object_zone__updateAt + map_object_zone__interval
    map_object_zone__updateAt = act.curTime + map_object_zone__interval

    var pos : float3
    var success = false
    if transform != null
      pos = (*transform)[3]
      success = true
    else
      query(item__containerOwnerEid) <| $ [es] (transform : float3x4)
        pos = transform[3]
        success = true
      if !success
        query(item__humanOwnerEid) <| $ [es] (transform : float3x4)
          pos = transform[3]
          success = true

    if success
      var seed = int(eid_frnd(eid) * 10000.0 + act.curTime) //because pufd
      let radius = map_object_zone__radius * 0.9 // 0.9 because it will be shrinked in UI
      var attempts = 20
      while attempts-- > 0
        // Randomly walk around circle.
        // If the next step takes us outside the circle - discard it and try again.
        var s, c : float
        sincos(_rnd_float(seed, .0, PI * 2.0), s, c)
        let r = _rnd_float(seed, .0, min(radius, dt * map_object_zone__noiseSpeed))
        let offset = map_object_zone__prevOffset + float3(c, .0, s) * r
        if length_sq(offset) < square(radius)
          map_object_zone__prevOffset = offset
          break


      map_object_zone__overridePos = pos + map_object_zone__prevOffset