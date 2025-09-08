options no_aot
require ecs
require DagorDebug3D
require pathfinder
require DngBehTree // required for ECS_DECLARE_BOXED_TYPE(dtPathCorridor);
require DagorConsole


[es(tag=render, no_order, REQUIRE=corridorWalkerDebug)]
def debug_draw_corridor_walker(evt : UpdateStageInfoRenderDebug; transform : float3x4; path_corridor : dtPathCorridor)
  begin_draw_cached_debug_lines(true, true, false)
  draw_cached_debug_sphere(transform[3], 0.5, E3DCOLOR(0xFFFFFFFF), 20)
  let forward = transform[3] + transform[0]
  draw_cached_debug_line(transform[3], forward, E3DCOLOR(0xFFFF0000))
  let up = transform[3] + transform[2]
  draw_cached_debug_line(transform[3], up, E3DCOLOR(0xFF0000FF))
  let left = transform[3] + transform[1]
  draw_cached_debug_line(transform[3], left, E3DCOLOR(0xFF00FF00))
  end_draw_cached_debug_lines()
  draw_corridor_path(path_corridor)
  // if navmesh_phys__currentWalkVelocity != null
  //   add_debug_text_mark(transform[3], "{length(*navmesh_phys__currentWalkVelocity)}", -1, 0f, E3DCOLOR(0xFF0000FF))


[es(tag=server, no_order, REQUIRE=corridorWalkerDebug)]
def update_corridor_walker(act : UpdateStageInfoAct; transform : float3x4;
                           var path_corridor : dtPathCorridor;
                           var navmesh_phys__wishWalkSpeed : float&;
                           var navmesh_phys__wishLookDir : float3&;
                           var navmesh_phys__wishWalkDir : float3&)
  let currentPos = transform[3]
  path_corridor |> set_corridor_agent_position(currentPos, null)

  find_corridor_corners(path_corridor, 5) <| $(corners)
    if length(corners) == 0
      navmesh_phys__wishWalkDir = float3(0)
      return

    let targetCorner = corners[0]
    navmesh_phys__wishWalkDir = normalize(targetCorner - currentPos)
    let dirToTarget = path_corridor |> corridor_getTarget() - currentPos
    navmesh_phys__wishWalkSpeed = saturate(length(dirToTarget) / 5f)
    navmesh_phys__wishLookDir = float3(dirToTarget.x, 0f, dirToTarget.z)


[console_cmd(name="corridor_walker.set_target")]
def navmesh_walker_set_target()
  find_query() <| $ [es(REQUIRE=hero)] (transform : float3x4)
    let target = transform[3]
    find_query() <| $ [es(REQUIRE=corridorWalkerDebug)] (transform : float3x4; var path_corridor : dtPathCorridor; navmesh_phys__currentPoly : int64 const?)
      let pos = transform[3]
      let extents = float3(.5, FLT_MAX, .5)
      using(pos, target, extents) <| $(var inp : CorridorInput#)
        inp.startPoly = dtPolyRef(navmesh_phys__currentPoly ?? int64(INVALID_POLY_REF))
        set_path_corridor(path_corridor, inp, null)

      path_corridor |> corridor_getPath() <| $(polys)
        print("corridor_walker: path {length(polys)} {polys}")
      return true

    return true
