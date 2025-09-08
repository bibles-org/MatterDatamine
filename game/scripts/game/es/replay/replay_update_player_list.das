require ecs
require ecs.common
require DagorSystem


[es(tag=playingReplay, track=possessed, REQUIRE_NOT=playerIsBot)]
def add_new_player_to_list(evt : Event;
                           name : string;
                           possessed : EntityId)
  if possessed == INVALID_ENTITY_ID
    return
  query() <| $ [es] (var replay__players : Object&;
                     var replay__isUpdatedPlayersList : bool&)
    replay__players |> push_to_object(name) <| $(var init : Object)
      set(init, "humanEid", possessed)
      set(init, "humanName", name)
      replay__isUpdatedPlayersList = false


[es(tag=playingReplay, on_appear, REQUIRE=playerIsBot)]
def add_new_bot_player_to_list(evt : Event;
                               name : string;
                               possessed : EntityId)
  if possessed == INVALID_ENTITY_ID
    return
  query() <| $ [es] (var replay__players : Object&;
                     var replay__isUpdatedPlayersList : bool&)
    replay__players |> push_to_object(name) <| $(var init : Object)
      set(init, "humanEid", possessed)
      set(init, "humanName", name)
      replay__isUpdatedPlayersList = false


[es(tag=playingReplay, on_disappear)]
def delete_player_from_list(evt : Event;
                            possessedByPlr : EntityId)
  query() <| $ [es] (var replay__players : Object&;
                     var replay__isUpdatedPlayersList : bool&)
    query(possessedByPlr) <| $ [es] (name : string)
      replay__players |> erase(name)
      replay__isUpdatedPlayersList = false
