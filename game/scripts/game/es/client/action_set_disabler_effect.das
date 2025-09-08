require ecs
require DagorInput


[es(on_appear, tag=input)]
def effect_disable_action_sets(evt : Event;
                               game_effect__attachedTo : EntityId;
                               effect_disable_action_sets__actionSetList : StringList)
  if !has(game_effect__attachedTo, "hero")
    return
  for actionSetName in effect_disable_action_sets__actionSetList
    activate_action_set(get_action_set_handle(string(actionSetName)), false)


[es(on_appear, tag=input, REQUIRE=hero)]
def hero_appear_effect_disable_action_sets(evt : Event;
                                           eid aka hero_eid : EntityId)
  query() <| $ [es] (game_effect__attachedTo : EntityId;
                     effect_disable_action_sets__actionSetList : StringList)
    if game_effect__attachedTo != hero_eid
      return

    for actionSetName in effect_disable_action_sets__actionSetList
      activate_action_set(get_action_set_handle(string(actionSetName)), false)

    return


[es(on_disappear, tag=input)]
def effect_disable_action_sets_restore(evt : Event;
                                       game_effect__attachedTo : EntityId;
                                       effect_disable_action_sets__actionSetList : StringList)
  if !has(game_effect__attachedTo, "hero")
    return
  for actionSetName in effect_disable_action_sets__actionSetList
    activate_action_set(get_action_set_handle(string(actionSetName)), true)

[es(on_appear, tag=input)]
def effect_enable_action_sets(evt : Event;
                              game_effect__attachedTo : EntityId;
                              effect_enable_action_sets__actionSetList : StringList)
  if !has(game_effect__attachedTo, "hero")
    return
  for actionSetName in effect_enable_action_sets__actionSetList
    activate_action_set(get_action_set_handle(string(actionSetName)), true)


[es(on_appear, tag=input, REQUIRE=hero)]
def hero_appear_effect_enable_action_sets(evt : Event;
                                          eid aka hero_eid : EntityId)
  query() <| $ [es] (game_effect__attachedTo : EntityId;
                     effect_enable_action_sets__actionSetList : StringList)
    if game_effect__attachedTo != hero_eid
      return

    for actionSetName in effect_enable_action_sets__actionSetList
      activate_action_set(get_action_set_handle(string(actionSetName)), true)

    return


[es(on_disappear, tag=input)]
def effect_enable_action_sets_restore(evt : Event;
                                      game_effect__attachedTo : EntityId;
                                      effect_enable_action_sets__actionSetList : StringList)
  if !has(game_effect__attachedTo, "hero")
    return
  for actionSetName in effect_enable_action_sets__actionSetList
    activate_action_set(get_action_set_handle(string(actionSetName)), false)
