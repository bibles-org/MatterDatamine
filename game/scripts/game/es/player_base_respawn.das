require ecs
require game.events.events_game
require game.utils.team
require DngNet
require game.es.item_equip_common
require game.events.events_active_matter


[es(REQUIRE=hero, on_event=EventEntityDied)]
def on_died_on_player_base(evt : Event; eid : EntityId)
  if (find_query() <| $ [es(REQUIRE=player_base_ecs_inventory)] () => true)
    createEntity("player_base_afterdeath_respawn") <| $(var init)
      init |> set("player_base_afterdeath_respawn__heroEid", eid)


[es(on_disappear)]
def respawn_on_player_base(evt : Event; player_base_afterdeath_respawn__heroEid : EntityId)
  if (find_query() <| $ [es(REQUIRE=player_base_ecs_inventory)] () => true)
    hero_clean_all_equipment_and_gun_slots(player_base_afterdeath_respawn__heroEid)
    find_query() <| $ [es] (var possessed : EntityId&)
      if possessed != player_base_afterdeath_respawn__heroEid
        return false
      possessed = INVALID_ENTITY_ID
      return true
    destroyEntity(player_base_afterdeath_respawn__heroEid)
    broadcastEvent(EventProfileLoaded())
    find_query() <| $ [es] (var player_profile__disableTransaction : bool&)
      player_profile__disableTransaction = true
      return true
