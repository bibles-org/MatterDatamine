module states_common shared
require ecs

def has_state_by_counter(state_counter : int)
  return state_counter > 0
