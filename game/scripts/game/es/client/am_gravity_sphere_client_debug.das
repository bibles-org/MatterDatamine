options no_aot
require strings
require math.color
require ecs
require ecs.safe
require ecs.soa_template
require ecs.ecs_template
require game.utils.hero
require math.base
require gameObject
require DagorConsole
require DagorDebug3D
require DagorSystem


[ecs_template]
struct am_gravity_sphere_debug_draw
  am_gravity_sphere__debugDrawDist : float = 50.0
  am_gravity_sphere__debugDrawDistSq : float


[console_cmd(name="am.gravity_sphere_debug_draw")]
def am_gravity_sphere_debug_draw_cmd(dist = 50.0)
  let tmpl = "am_gravity_sphere_debug_draw"
  let exists = find_query() <| $ [es] (eid : EntityId;
                                       var am_gravity_sphere__debugDrawDist : float&;
                                       var am_gravity_sphere__debugDrawDistSq : float&)
    if am_gravity_sphere__debugDrawDist == dist
      destroyEntity(eid)
    else
      am_gravity_sphere__debugDrawDist = dist
      am_gravity_sphere__debugDrawDistSq = square(dist)
    return true

  if !exists
    createEntity(tmpl) <| $(init)
      init |> set("am_gravity_sphere__debugDrawDist", dist)
      init |> set("am_gravity_sphere__debugDrawDistSq", square(dist))


[es(tag=render, tag=dev, no_order)]
def am_gravity_sphere_debug_es(evt : UpdateStageInfoRenderDebug;
                               am_gravity_sphere__debugDrawDistSq : float)

  find_query() <| $ [es] (camera__active : bool;
                          transform aka camera_transform : float3x4)
    if !camera__active
      return false

    query() <| $ [es(REQUIRE=am_gravity_sphere)] (transform aka sphere_transform : float3x4;
                                                  sphere_zone__radius : float;
                                                  am_gravity_sphere__active : bool)
      let distSq = distance_sq(camera_transform[3], sphere_transform[3])
      if distSq > am_gravity_sphere__debugDrawDistSq
        return

      let color = am_gravity_sphere__active ? E3DCOLOR(0x7FB22BE7) : E3DCOLOR(0x7E4D4D4D)
      draw_debug_sphere_buffered(sphere_transform[3], sphere_zone__radius, color, 12, 1)
    return true

