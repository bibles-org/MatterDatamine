require ecs
require pathfinder
require math.base
require app
require net
require math.random


[es(tag=gameClient, on_appear)]
def init_decor_around(evt : Event;
                      eid : EntityId;
                      transform : float3x4;
                      spawn_client_decorations_around__minMaxRadius : float2;
                      spawn_client_decorations_around__minMaxCount : int2;
                      spawn_client_decorations_around__decoration : string;
                      var spawn_client_decorations_around__finished : bool&)
  if spawn_client_decorations_around__finished
    return
  spawn_client_decorations_around__finished = true

  var seed = int(get_session_id() + uint64(uint(eid)))
  let count = _rnd_int(seed, spawn_client_decorations_around__minMaxCount)
  for _ in range(count)
    let localPos = rnd_point_on_ring(seed, spawn_client_decorations_around__minMaxRadius)
    var pos = transform * float3(localPos.x, 0.0, localPos.y)
    project_to_nearest_navmesh_point(pos, 1.0)
    createEntity(spawn_client_decorations_around__decoration) <| $(var init)
      var tm = IDENT_TM
      tm[3] = pos
      set(init, "transform", tm)
