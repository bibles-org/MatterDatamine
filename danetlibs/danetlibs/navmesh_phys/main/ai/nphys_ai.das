require ecs
require DagorMath
require walkerai
require pathfinder
require DngWalkerai
require DngBehTree // required for ECS_DECLARE_BOXED_TYPE(dtPathCorridor);


[es(tag=server, no_order, REQUIRE=navmeshPhys, REQUIRE_NOT=nphys__disabled)]
def update_navmesh_ai_pos_dir(act : UpdateStageInfoAct; transform : float3x4;
                              navmesh_phys__wishLookDir : float3 const?;
                              walker_agent__standShootLocalPos : float3;
                              var agent_dangers__standShootPos : float3&;
                              var agent_dangers__standShootDir : float3&)
  agent_dangers__standShootPos = transform * walker_agent__standShootLocalPos
  agent_dangers__standShootDir = navmesh_phys__wishLookDir ?? transform[3]
