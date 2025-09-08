require ecs
require pathfinder
require DngBehTree // required for ECS_DECLARE_BOXED_TYPE(dtPathCorridor);


[es(tag=server, on_appear, REQUIRE=corridorWalker, no_order)]
def init_corridor_walker(evt : Event; var path_corridor : dtPathCorridor)
  path_corridor |> init_path_corridor()
