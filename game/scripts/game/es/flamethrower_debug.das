options no_aot
require ecs
require math
require math.base
require game.utils.hero
require game.events.events
require Gun
require Dacoll
require AnimV20
require GeomNodeTree
require Grid
require GridCollision
require DagorDebug3D
require DagorMath
require DagorConsole
require game.events.events_game


def draw_debug_flame(gloc : GunLocation; start_offset, distance, radius, cloud_offset, cloud_radius : float)
  if gloc.gunPos == null
    return
  let gunPos = *(gloc.gunPos)
  let gunDir = gloc.gunDir
  let end = gunPos + gunDir * distance
  let start = gunPos + gunDir * start_offset
  let humanRadius = 0.4

  if (distance_sq(end, start) > 0.0)
    var out = ShapeQueryOutput()
    sphere_cast(start, end, radius, out)
    let hitPos = out.res
    let reachDist = distance * out.t
    let reachPos = start + gunDir * reachDist

    if out.t < 1.0
      draw_debug_line_buffered(start, hitPos, E3DCOLOR(0xFFFF0000), 1)
    draw_debug_line_buffered(start, reachPos, E3DCOLOR(0xFF00FF00), 1)
    draw_debug_capsule_buffered(start, reachPos, radius, E3DCOLOR(0xFFFF0000), 8, 1)

  let fireLen = max(0.0, distance - cloud_radius)
  let fireCloudStart = start + gunDir * cloud_offset
  let fireCloudEnd = start + gunDir * fireLen
  draw_debug_capsule_buffered(fireCloudStart, fireCloudEnd, cloud_radius, E3DCOLOR(0xFF00FF00), 8, 1)

  for_each_entity_in_grid(ecs_hash("humans"), fireCloudStart, gunDir, fireLen, cloud_radius, GridEntCheck.BOUNDING) <| $(humanEid : EntityId)
    query(humanEid) <| $ [es(REQUIRE=human)] (animchar : AnimcharBaseComponent;
                                              transform : float3x4;
                                              human_use_object__nodeId : int)
      let headPos = geomtree_getNodeWpos(*animchar.nodeTree, human_use_object__nodeId)
      let lowestPos = transform[3]
      draw_debug_capsule_buffered(lowestPos, headPos, humanRadius, E3DCOLOR(0xFFFFFFFF), 8, 1)

[es(tag=(gameClient, dev))]
def flamethrower_debug_phys(evt : CmdWeapPhysUpdate;
                            gun__ammo : int;
                            flamethrower__flameCurrentLength : float;
                            flamethrower__debug : bool;
                            flamethrower__flameStartOffset : float;
                            flamethrower__cloudStartOffset : float;
                            flamethrower__flameStreamRadius : float;
                            flamethrower__flameCloudRadius : float)
  if !flamethrower__debug || !evt.isForReal
    return

  if gun__ammo != 0 && evt.gctrl.shoot
    draw_debug_flame(evt.gloc, flamethrower__flameStartOffset, flamethrower__flameCurrentLength,
                     flamethrower__flameStreamRadius, flamethrower__cloudStartOffset, flamethrower__flameCloudRadius)


[console_cmd(name="flameThrower.debug")]
def switch_flamethrower_debug()
  let hero = get_controlled_hero()
  find_query() <| $ [es] (gun__owner : EntityId; var flamethrower__debug : bool&)
    if gun__owner == hero
      flamethrower__debug = !flamethrower__debug
      return true
    return false
  find_query() <| $ [es(REQUIRE=flamethrower__fireTemplate, REQUIRE_NOT=flamethrower__debug)] (eid : EntityId; gun__owner : EntityId)
    if gun__owner == hero
      addSubTemplate(eid, "flamethrower_debug")
      return true
    return false
