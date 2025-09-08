options no_aot
require ecs
require DagorConsole
require game.es.net_console_macro
require game.events.events_game
require game.es.objectives.objective_common
require player
require daslib/strings_boost


[console_cmd(name="objectives.reset_all")]
def reset_progress_for_all_objectives()
  for_each_player_objective(get_local_player_eid()) <| $(objective_eid : EntityId)
    reset_progress_for_objective(objective_eid)
  console_print("All objectives reset")


[console_cmd(name="objectives.reset", hint="idx - objectives order, top to bottom")]
def reset_progress_for_objective(idx = 1)
  var curIdx = 0
  for_each_player_objective(get_local_player_eid()) <| $(objective_eid : EntityId)
    if ++curIdx != idx
      return
    reset_progress_for_objective(objective_eid)
    console_print("Objective {split(getEntityTemplateName(objective_eid), "+")[0]} reset")


[net_console_cmd(name="objective.create_quest_item")]
def console_objective_create_quest_item(item_template : string;
                                        @net_hero hero_eid : EntityId)
  query(hero_eid) <| $ [es] (possessedByPlr : EntityId)
    var objectiveEids : array<EntityId>
    objectiveEids |> push(hero_eid)
    create_quest_item_in_container(item_template, hero_eid, possessedByPlr, objectiveEids)


[es(tag=server, on_appear)]
def test_objective_zone_appear(evt : Event;
                               transform : float3x4;
                               test_objective_zone__fxTemplate : string;
                               test_objective_zone__fxOffset : float3;
                               test_objective_zone__helpSignTemplate : string;
                               test_objective_zone__helpSignOffset : float3;
                               test_objective_zone__helpSignTitle : string;
                               var test_objective_zone__fxEid : EntityId&;
                               var test_objective_zone__helpSignEid : EntityId&)
  test_objective_zone__fxEid = createEntity(test_objective_zone__fxTemplate) <| $(var init : ComponentsInitializer)
    var tm : float3x4 = transform
    tm[3] = transform * test_objective_zone__fxOffset
    init |> set("transform", tm)

  test_objective_zone__helpSignEid = createEntity(test_objective_zone__helpSignTemplate) <| $(var init : ComponentsInitializer)
    var tm : float3x4 = transform
    tm[3] = transform * test_objective_zone__helpSignOffset
    init |> set("transform", tm)
    init |> set("help__title", test_objective_zone__helpSignTitle)


[es(tag=server, on_disappear)]
def test_objective_zone_disappear(evt : Event;
                                  test_objective_zone__fxEid : EntityId;
                                  test_objective_zone__helpSignEid : EntityId)
  destroyEntity(test_objective_zone__fxEid)
  destroyEntity(test_objective_zone__helpSignEid)


[es(tag=server)]
def test_objective_zone_trigger(evt : EventZoneEnter;
                                eid aka eid_test_objective_zone : EntityId;
                                test_objective_zone__objectiveTemplate : string;
                                test_objective_zone__objectiveParams : Object;
                                test_objective_zone__questItems : StringList;
                                test_objective_zone__staticTargetTags : StringList)
  query(evt.visitorEid) <| $ [es(REQUIRE=heroForPlayer)] (possessedByPlr : EntityId)
    destroyEntity(eid_test_objective_zone)

    var objectiveEid : EntityId
    using() <| $(var objective_params : Object)
      objective_params := test_objective_zone__objectiveParams
      objective_params |> set("handledByGameTemplate", test_objective_zone__objectiveTemplate)

      objectiveEid = make_objective_entity(objective_params, possessedByPlr) <| $(var init : ComponentsInitializer)

        if !empty(test_objective_zone__staticTargetTags)
          var staticTargetTags : array<string>
          for tag in test_objective_zone__staticTargetTags
            staticTargetTags |> push(string(tag))

          var staticTargetsInfo : table<string; array<EntityId>>
          collect_all_static_targets_with_tag(staticTargetTags, staticTargetsInfo)

          using() <| $(var staticTargetsList : EidList)
            for targetEids in values(staticTargetsInfo)
              for targetEid in targetEids
                staticTargetsList |> push(targetEid)
            init |> set("objective__staticTargetsList", staticTargetsList)

    for item_template in test_objective_zone__questItems
      create_quest_item_in_container(string(item_template), evt.visitorEid, possessedByPlr, [ objectiveEid])
