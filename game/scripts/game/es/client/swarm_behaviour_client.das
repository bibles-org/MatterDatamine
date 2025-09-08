require ecs
require DagorMath
require DagorDebug3D


[es(no_order, tag=render, tag=dev)]
def swarm_cluster_debug_bhv(info : UpdateStageInfoRenderDebug; transform : float3x4;
                            swarm_cluster__targetPos : float3;
                            swarm_cluster__contactPoints : Point4List;
                            swarm_cluster__debugDraw : bool = false)
  if !swarm_cluster__debugDraw
    return
  for pt in swarm_cluster__contactPoints
    let point = float3(pt.x, pt.y, pt.z)
    draw_debug_line_buffered(transform[3], point, E3DCOLOR(0xff00ff00), 2)
  draw_debug_line_buffered(transform[3], swarm_cluster__targetPos, E3DCOLOR(0xffffff00), 2)
