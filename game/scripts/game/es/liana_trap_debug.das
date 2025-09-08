options no_aot
require ecs
require DagorConsole
require DagorMath
require DagorDebug3D

[es(tag=gameClient, after=net_phys_update_es, REQUIRE=liana_tentacle__aliveAt1)]
def liana_vis(info : UpdateStageInfoAct;
              spline_gen_geometry__points : Point3List;
              liana_tentacle__fallTargets : Point3List;
              liana_tentacle__aliveAt : float;
              spline_gen_geometry__request_active : bool;
              liana_tentacle__isAttached : bool)
  var color = liana_tentacle__aliveAt > info.curTime ? E3DCOLOR(0xFFFF0000) : E3DCOLOR(0xFFFFFF00)
  let offset = float3(1.0, 1.0, 1.0)
  let radius = 0.12
  if liana_tentacle__isAttached
    color = E3DCOLOR(0xFF00FF00)
  if !spline_gen_geometry__request_active
    color = E3DCOLOR(0xFFFF00FF)
  for p in spline_gen_geometry__points
    draw_debug_box_buffered(BBox3(p + offset, radius), color, 1)
  for p in liana_tentacle__fallTargets
    draw_debug_box_buffered(BBox3(p + offset, radius * 0.7), E3DCOLOR(0xFF00FFFF), 1)
  for i in iter_range(liana_tentacle__fallTargets)
    draw_debug_line_buffered(liana_tentacle__fallTargets[i] + offset, spline_gen_geometry__points[i] + offset, E3DCOLOR(0xFFFFFFFF), 1)