require ecs


[es(on_appear, track=item__containerOwnerEid, REQUIRE=game_effect__followInventory)]
def inventory_item_with_game_effect_es(evt : Event; var game_effect__attachedTo : EntityId&; item__containerOwnerEid : EntityId)
  game_effect__attachedTo = item__containerOwnerEid


[es(on_disappear, REQUIRE=item__containerOwnerEid, REQUIRE=game_effect__followInventory)]
def inventory_item_with_game_effect_detached_es(evt : Event; var game_effect__attachedTo : EntityId&)
  game_effect__attachedTo = INVALID_ENTITY_ID
