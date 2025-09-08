require ecs
require ecs.common
require game.events.events
require player
require game.events.events_active_matter


[es]
def toggle_visibility_map_object_for_player(evt : CmdToggleMapObject;
                                            var map_object__show : bool&)
  map_object__show = evt.value


[es(REQUIRE=showMapObjectOnQuestTargetAssignition)]
def show_map_object_on_quest_target_assignition(evt : EventQuestStaticTargetAssigned;
                                                var map_object__show : bool&)
  if get_local_player_eid() == evt.playerEid
    map_object__show = true


[es(on_appear, track=item__containerOwnerEid)]
def map_object_item_track_container(evt : Event;
                                    item__containerOwnerEid : EntityId;
                                    var map_object__parentContainerEid : EntityId&)
  map_object__parentContainerEid = item__containerOwnerEid


[es(tag=gameClient, on_appear, on_disappear, REQUIRE=item_in_world)]
def map_object_track_item_in_world_changed(evt : Event;
                                           eid : EntityId)
  sendEvent(eid, EventMapObjectStateChanged())


[es(tag=gameClient, on_appear, track=map_object__parentContainerEid, REQUIRE=quest_item_in_container_marker)]
def quest_item_in_container_marker_update_show(evt : Event;
                                               map_object__parentContainerEid : EntityId;
                                               quest_item__playerEid : EntityId;
                                               var map_object__show : bool&)
  var show = false

  query(map_object__parentContainerEid) <| $ [es(REQUIRE=container_target__generatedForPlayers)] ()
    show = (quest_item__playerEid == get_local_player_eid())

  map_object__show = show