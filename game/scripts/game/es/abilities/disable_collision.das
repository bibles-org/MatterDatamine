require ecs
require GridCollision

[es(on_appear, REQUIRE=game_effect__disableCollision)]
def collision_disabled_set_es(evt : Event; game_effect__attachedTo : EntityId)
  ecs::query(game_effect__attachedTo) <| $ [es] (var grid_obj__hidden : int&)
    grid_obj__hidden |= int(GridHideFlag.EGH_GAME_EFFECT)

[es(on_event=EventEntityDestroyed, REQUIRE=game_effect__disableCollision)]
def collision_disabled_unset_es(evt : Event; game_effect__attachedTo : EntityId)
  ecs::query(game_effect__attachedTo) <| $ [es] (var grid_obj__hidden : int&)
    grid_obj__hidden &= ~int(GridHideFlag.EGH_GAME_EFFECT)
