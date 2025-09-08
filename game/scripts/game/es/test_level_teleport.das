require ecs
require game.es.teleport_common
require game.events.events_game


[es(on_appear)]
def test_level_teleport_appear(evt : Event;
                               transform : float3x4;
                               test_level_teleport__name : string;
                               var test_level_teleport__marker : EntityId&)
  test_level_teleport__marker = createEntity("test_level_teleport_marker") <| $(var init)
    init |> set("transform", transform)
    init |> set("interactable__name", test_level_teleport__name)


[es(on_disappear)]
def test_level_teleport_disappear(evt : Event;
                                  test_level_teleport__marker : EntityId)
  destroyEntity(test_level_teleport__marker)


[es(tag=server)]
def test_level_teleport_enter(evt : EventZoneEnter;
                              test_level_teleport__toPos : float3)
  teleport_eid_to(evt.visitorEid, test_level_teleport__toPos, false)
