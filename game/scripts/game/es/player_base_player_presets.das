require ecs
require game.es.player_presets_common
require game.events.events_active_matter
require DagorSystem
require game.es.boxed_item_common


//Our equip system update slots sepparatly, in next frame after equipping item
//So, any next action with slot must be proceeded with delay
[es(tag=gameClient, no_order, REQUIRE_NOT=showroom_cam)]
def unequip_done_check(evt : UpdateStageInfoAct; eid : EntityId; player_preset__frameNumber : int; var player_preset__counted : bool&)
  if player_preset__frameNumber == int(get_dagor_frame_no()) || player_preset__counted
    return
  removeSubTemplate(eid, "player_preset_item_unequip_in_progress")
  player_preset__counted = true
  find_query() <| $ [es] (player_on_base__playerPreset : Object; var player_on_base__itemsToBeMoved : int&)
    player_on_base__itemsToBeMoved--
    if player_on_base__itemsToBeMoved <= 0
      find_query() <| $ [es] (itemContainer : EidList; inventory__name : string)
        if inventory__name != "stash"
          return false

        merge_boxed_items_in_container(itemContainer)
        return true

      equip_player_preset(player_on_base__playerPreset)
    return true


[es(on_disappear)]
def unequip_done_check_on_disappearing(evt : Event; var player_preset__counted : bool&)
  if player_preset__counted
    return
  player_preset__counted = true
  find_query() <| $ [es] (player_on_base__playerPreset : Object; var player_on_base__itemsToBeMoved : int&)
    if player_on_base__itemsToBeMoved == 0
      return true
    player_on_base__itemsToBeMoved--
    if player_on_base__itemsToBeMoved <= 0
      find_query() <| $ [es] (itemContainer : EidList; inventory__name : string)
        if inventory__name != "stash"
          return false

        merge_boxed_items_in_container(itemContainer)
        return true

      equip_player_preset(player_on_base__playerPreset)
    return true
