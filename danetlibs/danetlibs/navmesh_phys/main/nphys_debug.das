options no_aot
require ecs
require app
require math.base
require pathfinder
require DagorConsole
require DngWalkerai
require danetlibs.navmesh_phys.main.nphys_find_obstacles_common


[console_cmd(name="nphys.drop_on_navmesh", hint="Drops all navmesh entities on navmesh")]
def do_nphys_drop()
  query() <| $ [es] (var navmesh_phys__currentPos : float3&)
    project_to_nearest_navmesh_point(navmesh_phys__currentPos, 1.0)

[console_cmd(name="nphys.recalc_obstacles")]
def console_nphys_recalc_obstacles()
  query() <| $ [es] (eid : EntityId;
                     obstacle_avoider__updateInterval : float;
                     navmesh_phys__prevPos : float3;
                     navmesh_phys__currentWalkVelocity : float3;
                     nphys_pushable__unlockMovementAt : float = 0.0;
                     var agent_obstacles : AgentObstacles)
    clear(agent_obstacles.obstacles)
    let destination = navmesh_phys__prevPos + x0z(navmesh_phys__currentWalkVelocity) * obstacle_avoider__updateInterval * 2.0
    find_obstacles(eid, nphys_pushable__unlockMovementAt < get_sync_time(), destination)