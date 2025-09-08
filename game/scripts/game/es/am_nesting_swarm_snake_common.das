module am_nesting_swarm_snake_common shared
require ecs

enum NestingSwarmSnakeState
  None
  Nest
  Fly
  Attack