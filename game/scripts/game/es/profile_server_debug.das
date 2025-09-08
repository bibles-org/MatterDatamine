options no_aot
require ecs
require strings
require DagorConsole
require game.es.item_equip_common


[console_cmd(name="profile.get_item_info")]
def console_profile_give_item(item_id : string)
  let success = find_query() <| $ [es] (uniqueId : string; eid, item__containerOwnerEid : EntityId)
    if item_id == uniqueId
      console_print("<{eid}> {getEntityTemplateName(eid)}")
      query(item__containerOwnerEid) <| $ [es] (uniqueId aka owner_uniqueId : string)
        console_print("Owner: {owner_uniqueId}: <{item__containerOwnerEid}> {getEntityTemplateName(item__containerOwnerEid)}")
    return item_id == uniqueId
  if !success
    console_print("No such item")


[console_cmd(name="profile.print_all_items")]
def console_profile_print_all_items()
  find_query() <| $ [es] (player_profile__allItems : Array)
    for item in player_profile__allItems
      console_print("{item}")
    return true


[console_cmd(name="profile.print_all_hero_items")]
def console_profile_print_all_hero_items()
  query() <| $ [es(REQUIRE=hero)] (eid : EntityId)
    using() <| $(var items : Array)
      save_player_items(items, eid)
      for item in items
        console_print("{item}")