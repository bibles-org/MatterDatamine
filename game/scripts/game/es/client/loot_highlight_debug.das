options no_aot
require ecs
require DagorConsole


[console_cmd(name="loot.highlight", hint="highlight generated loot")]
def loot_highlight_activate()
  let execute = find_query() <| $[es(REQUIRE=loot_debug__highlightTempl)] (eid : EntityId)
    destroyEntity(eid)
    return true
  if !execute
    createEntity("loot_highlight_debug")


[es(tag=dev, on_disappear)]
def highlight_loot_on_disappear_create_es(evt : Event;
                                          loot_debug__highlightTempl : string)
  query() <| $[es(REQUIRE=item_generated)] (eid : EntityId;
                                            active_matter_pile__visualEid : EntityId = INVALID_ENTITY_ID)
    if (active_matter_pile__visualEid != INVALID_ENTITY_ID)
      removeSubTemplate(active_matter_pile__visualEid, loot_debug__highlightTempl)
    else
      removeSubTemplate(eid, loot_debug__highlightTempl)
  query() <| $[es(REQUIRE=lootableRendinst, REQUIRE_NOT=item_generated)] (eid : EntityId)
    removeSubTemplate(eid, loot_debug__highlightTempl)


[es(tag=dev, on_appear)]
def highlight_loot_on_appear_create_es(evt : Event;
                                       loot_debug__highlightColorForRendInst : E3DCOLOR;
                                       loot_debug__highlightColorForLoot : E3DCOLOR;
                                       loot_debug__highlightColorForAM : E3DCOLOR;
                                       loot_debug__highlightTempl : string)
  query() <| $[es(REQUIRE=item_generated)] (eid : EntityId;
                                            active_matter_pile__visualEid : EntityId = INVALID_ENTITY_ID)
    if (active_matter_pile__visualEid != INVALID_ENTITY_ID)
      addSubTemplate(active_matter_pile__visualEid, loot_debug__highlightTempl) <| $(var init : ComponentsInitializer)
        init |> set("outline__color", loot_debug__highlightColorForAM)
    else
      addSubTemplate(eid, loot_debug__highlightTempl) <| $(var init : ComponentsInitializer)
        init |> set("outline__color", loot_debug__highlightColorForLoot)
  query() <| $[es(REQUIRE=lootableRendinst, REQUIRE_NOT=item_generated)] (eid : EntityId)
    addSubTemplate(eid, loot_debug__highlightTempl) <| $(var init : ComponentsInitializer)
      init |> set("outline__color", loot_debug__highlightColorForRendInst)


[es(tag=dev, REQUIRE=item_generated, on_appear)]
def highlight_loot_on_creation_items_es(evt : Event;
                                        eid : EntityId;
                                        active_matter_pile__visualEid : EntityId = INVALID_ENTITY_ID)
  find_query() <| $[es] (loot_debug__highlightColorForLoot : E3DCOLOR;
                         loot_debug__highlightColorForAM : E3DCOLOR;
                         loot_debug__highlightTempl : string)
    if (active_matter_pile__visualEid != INVALID_ENTITY_ID)
      addSubTemplate(active_matter_pile__visualEid, loot_debug__highlightTempl) <| $(var init : ComponentsInitializer)
        init |> set("outline__color", loot_debug__highlightColorForAM)
    else
      addSubTemplate(eid, loot_debug__highlightTempl) <| $(var init : ComponentsInitializer)
        init |> set("outline__color", loot_debug__highlightColorForLoot)
    return true