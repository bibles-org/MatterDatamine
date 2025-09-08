require ecs
require app
require math.random
require DagorRandom
require game.events.events_active_matter


[es(tag=server, on_appear)]
def init_polen_cloud(evt : Event;
                     polen_cloud__expandDelay : float2;
                     var polen_cloud__expandAt : float&)
  polen_cloud__expandAt = get_sync_time() + rnd_float(polen_cloud__expandDelay)

let expansionDirs  = fixed_array(
        float3(1, 0, 0),
        float3(1, 1, 0),
        float3(1, 0, 1),
        float3(1, -1, 0),
        float3(1, 0, -1),
        float3(1, 1, -1),
        float3(1, -1, 1),
        float3(1, -1, -1),
        float3(1, 1, 1),

        float3(0, 1, 0),
        float3(0, 0, 1),
        float3(0, -1, 0),
        float3(0, 0, -1),
        float3(0, 1, -1),
        float3(0, -1, 1),
        float3(0, -1, -1),
        float3(0, 1, 1),

        float3(-1, 0, 0),
        float3(-1, 1, 0),
        float3(-1, 0, 1),
        float3(-1, -1, 0),
        float3(-1, 0, -1),
        float3(-1, 1, -1),
        float3(-1, -1, 1),
        float3(-1, -1, -1),
        float3(-1, 1, 1)
        )

[es(tag=server, no_order)]
def polen_cloud_update(act : ParallelUpdateFrameDelayed;
                       polen_cloud__ownerEid : EntityId;
                       polen_cloud__expandAt : float;
                       sphere_zone__radius : float;
                       polen_cloud__voxelIdx : int3;
                       polen_cloud__expansionStagesLeft : int;
                       transform : float3x4;
                       polen_cloud__expansionProbability : float;
                       var polen_cloud__expansionCharges : int&)
  if polen_cloud__expansionStagesLeft > 0 && polen_cloud__expansionCharges > 0 && polen_cloud__expandAt < act.curTime
    query(polen_cloud__ownerEid) <| $ [es] (polen_storm__tm : float3x4;
                                            polen_storm__focus : float3;
                                            polen_storm__duration : float2;
                                            polen_storm__cloudTemplate : string;
                                            var polen_storm__registry : IPoint3List)
      let startingCharges = polen_cloud__expansionCharges
      var j = 0
      while polen_cloud__expansionCharges > 0 && j < length(expansionDirs)
        if polen_cloud__expansionProbability < gfrnd()
          continue
        let thisIdx = polen_cloud__voxelIdx + int3(int(expansionDirs[j].x), int(expansionDirs[j].y), int(expansionDirs[j].z))
        var hasValue = false
        for idx in polen_storm__registry
          if idx == thisIdx
            hasValue = true
            break
        if !hasValue
          polen_storm__registry |> push(thisIdx)
          var tm := transform
          tm[3] += polen_storm__tm[0] * expansionDirs[j].x * sphere_zone__radius * 1.2
          tm[3] += polen_storm__tm[1] * expansionDirs[j].y * sphere_zone__radius * 1.2
          tm[3] += polen_storm__tm[2] * expansionDirs[j].z * sphere_zone__radius * 1.2
          let aligment = dot(normalize(polen_storm__focus - transform[3]), normalize(tm[3] - transform[3]))
          var price = 3
          if aligment > 0.5
            price = 1
          elif aligment > 0.0
            price = 2
          polen_cloud__expansionCharges--
          createEntity(polen_storm__cloudTemplate) <| $(init)
            init |> set("polen_cloud__expansionStagesLeft", polen_cloud__expansionStagesLeft - price)
            init |> set("polen_cloud__ownerEid", polen_cloud__ownerEid)
            init |> set("polen_cloud__voxelIdx", thisIdx)
            init |> set("polen_cloud__expansionCharges", max(1, startingCharges - (aligment < 0.5 ? 1 : 0)))
            init |> set("transform", tm)
            init |> set("game_effect__destroyAt", get_sync_time() + rnd_float(polen_storm__duration))
        j++
      polen_cloud__expansionCharges = 0