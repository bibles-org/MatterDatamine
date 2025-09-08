require ecs
require game.events.events_active_matter
require game.es.player_profile_common
require DagorSystem


[es(tag=gameClient, on_appear, REQUIRE=skeleton_attach__attachedTo, REQUIRE_NOT=watchedPlayerItem)]
def skeleton_attachable_animchar_appear_client(evt : Event;
                                               eid aka item_eid : EntityId;
                                               skeleton_attach__attachedTo : EntityId)
  query() <| $ [es(REQUIRE=watchedByPlr)] (eid aka player_eid : EntityId)
    if skeleton_attach__attachedTo == player_eid
      addSubTemplate(item_eid, "watched_by_player_item")


[es(tag=gameClient, on_appear, REQUIRE=watchedByPlr)]
def watched_by_player_track_attachable_items_controller_appear(evt : Event; eid aka player_eid : EntityId)
  query() <| $ [es(REQUIRE_NOT=watchedPlayerItem)] (eid aka item_eid : EntityId; skeleton_attach__attachedTo : EntityId)
    if skeleton_attach__attachedTo == player_eid
      addSubTemplate(item_eid, "watched_by_player_item")


[es(tag=gameClient, on_disappear, REQUIRE=watchedByPlr)]
def watched_by_player_track_attachable_items_controller_disappear(evt : Event;
                                                                  attachable_suit_controller__attachedAnimcharEids : Object)
  for item in attachable_suit_controller__attachedAnimcharEids
    let itemEid = get_Eid(item.value) ?? INVALID_ENTITY_ID
    removeSubTemplate(itemEid, "watched_by_player_item")
