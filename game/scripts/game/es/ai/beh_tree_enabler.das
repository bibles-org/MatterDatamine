require ecs

[es(tag=server, on_appear, REQUIRE=behTreeEnabler)]
def beh_tree_enabler_appear(evt : Event; var beh_tree__enabled : bool&)
  beh_tree__enabled = true

[es(tag=server, on_disappear, REQUIRE=behTreeEnabler)]
def beh_tree_enabler_disappear(evt : Event; var beh_tree__enabled : bool&)
  beh_tree__enabled = false

[es(tag=server, on_appear, REQUIRE=behTreeDisabler)]
def beh_tree_disabler_appear(evt : Event; var beh_tree__enabled : bool&)
  beh_tree__enabled = false

[es(tag=server, on_disappear, REQUIRE=behTreeDisabler)]
def beh_tree_disabler_disappear(evt : Event; var beh_tree__enabled : bool&)
  beh_tree__enabled = true


[es(on_appear)]
def disable_beh_tree_effect_on_appear(evt : Event;
                                      game_effect__attachedTo : EntityId;
                                      beh_tree_effect__newEnabled : bool;
                                      var beh_tree_effect__prevEnabled : bool&)
  query(game_effect__attachedTo) <| $ [es] (var beh_tree__enabled : bool&)
    beh_tree_effect__prevEnabled = beh_tree__enabled
    beh_tree__enabled = beh_tree_effect__newEnabled


[es(on_disappear)]
def disable_beh_tree_effect_on_disappear(evt : Event;
                                         game_effect__attachedTo : EntityId;
                                         beh_tree_effect__prevEnabled :  bool)
  query(game_effect__attachedTo) <| $ [es] (var beh_tree__enabled : bool&)
    beh_tree__enabled = beh_tree_effect__prevEnabled