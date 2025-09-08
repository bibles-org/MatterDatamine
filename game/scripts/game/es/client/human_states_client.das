require ecs
require DagorInput
require game.es.states_common


[es(tag=gameClient, on_appear, REQUIRE=state__deactivateInput)]
def deactivate_input_appear_client(evt : Event;
                                   game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es(REQUIRE=hero)] (var state_counter__deactivateInput : int&)
    state_counter__deactivateInput += 1
    activate_action_set(get_action_set_handle("Human"), false)


[es(tag=gameClient, on_disappear, REQUIRE=state__deactivateInput)]
def deactivate_input_disappear_client(evt : Event;
                                      game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es(REQUIRE=hero)] (var state_counter__deactivateInput : int&)
    state_counter__deactivateInput -= 1
    if !has_state_by_counter(state_counter__deactivateInput)
      activate_action_set(get_action_set_handle("Human"), true)


[es(tag=gameClient, on_appear, REQUIRE=state__disableMovementInAir)]
def disable_movement_appear(evt : Event;
                            game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es(REQUIRE=hero)] (var state_counter__disableMovementInAir : int&)
    state_counter__disableMovementInAir += 1


[es(tag=gameClient, on_disappear, REQUIRE=state__disableMovementInAir)]
def disable_movement_disappear(evt : Event;
                               game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es(REQUIRE=hero)] (var state_counter__disableMovementInAir : int&)
    state_counter__disableMovementInAir -= 1