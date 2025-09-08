options no_aot
require ecs
require DagorConsole
require game.events.events_active_matter


[console_cmd(name="loot.regenerate", hint="destroy current loot on level and generate new one")]
def regenerate_loot()
  query() <| $[es] (var loot_drop_system_delayed_loot_generation__generated : bool&;
                    var itemContainer : EidList&)
    for eid in itemContainer
      destroyEntity(eid)
    itemContainer |> clear()
    loot_drop_system_delayed_loot_generation__generated = false
  query() <| $[es] (var openable_ri__isOpened : bool&)
    openable_ri__isOpened = false

  // We add a rendinstanses template so that after the not preload instanses
  // is destroyed, the models do not remain in place. And they remain because
  // lootable rendinstanses do not have components for destruction.
  query() <| $ [es(REQUIRE=(item_generated, ri_extra))] (eid : EntityId)
    addSubTemplate(eid, "rendinst_base")

  query() <| $ [es(REQUIRE=item_generated)] (eid : EntityId)
    destroyEntity(eid)
  query() <| $ [es(REQUIRE=generated_monster)] (eid : EntityId)
    destroyEntity(eid)
  query() <| $ [es] (var custom_game_object__occuped : bool&)
    custom_game_object__occuped = false
  query() <| $ [es] (var used_game_objects__map : BoolList&)
    for map_i in used_game_objects__map
      map_i = false

  query() <| $[es] (eid : EntityId;
                    var loot_generator__finished : bool&)
    loot_generator__finished = false
    sendEvent(eid, EventRetriggerEntity())