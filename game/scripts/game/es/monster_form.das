require ecs
require DngNet
require game.es.inventory_drop_common
require game.es.objectives.objective_common
require game.es.objectives_enums_common
require game.events.events_active_matter


[es(tag=server, on_appear, REQUIRE=game_effect__dropAllItemsOnGround)]
def game_effect_dtop_all_items_on_ground(evt : Event; game_effect__attachedTo : EntityId)
  query() <| $ [es(REQUIRE_NOT=(item__permanentItem, grenade_thrower, default_stub_item, suit_militant_attachable_animchar, suit__suitType))] (item__humanOwnerEid : EntityId; eid aka item_eid : EntityId)
    if item__humanOwnerEid == game_effect__attachedTo
      drop_item(item_eid, game_effect__attachedTo)


[es(tag=server, on_appear, REQUIRE=game_effect__destroyAllItems)]
def game_effect_destroy_all_items(evt : Event; game_effect__attachedTo : EntityId)
  query() <| $ [es(REQUIRE_NOT=(item__permanentItem, grenade_thrower, default_stub_item, suit_militant_attachable_animchar, suit__suitType))] (item__humanOwnerEid : EntityId; eid aka item_eid : EntityId)
    if item__humanOwnerEid == game_effect__attachedTo
      destroyEntity(item_eid)


[es(tag=gameClient, REQUIRE=(player_controlled_monster, hero), on_appear)]
def assistant_comment_on_monster_transformation(evt : Event;
                                                possessedByPlr : EntityId)
  sendEvent(possessedByPlr, CmdStartAssistantSpeak(scriptName = "monster_transformation", skipBeepSound = true))
