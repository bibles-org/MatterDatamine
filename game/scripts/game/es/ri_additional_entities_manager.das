require ecs
require ecs.safe
require app
require level
require DagorMath
require DagorSystem
require RendInst


[es(tag=server, on_event=EventLevelLoaded, on_appear)]
def ri_additional_entities_manager_spawn(evt : Event;
                                         eid : EntityId;
                                         ri_additional_entities_manager__list : Object)

  if !is_level_loaded()
    return

  var sphere = BSphere3()
  let zoneFound = find_query() <| $ [es(REQUIRE=moving_zone__sourcePos)] (sphere_zone__radius : float; transform : float3x4)
    sphere = BSphere3(transform[3], sphere_zone__radius * 2.0)
    return true
  if !zoneFound
    let pos = float3(0.0, 0.0, 0.0)
    sphere = BSphere3(pos, 2048.0)

  for object in ri_additional_entities_manager__list
    let riName = object.key

    let resIdx = get_rigen_extra_res_idx(riName)
    if resIdx < 0
      logwarn("ri_additional_entities_manager__list: {eid}:{getEntityTemplateName(eid)} contains unknown ri name '{riName}'")
      continue

    getRiGenExtraInstances(resIdx, sphere) <| $(handles : array<riex_handle_t>#)
      for handle in handles
        var tm : float3x4
        get_rigen_extra_matrix(handle, tm)

        let valueObj = object.value as Object
        let templatesList = get_ecs_StringList(valueObj?.templates)
        if templatesList != null
          for templateName in *templatesList
            createEntity(string(templateName)) <| $(var init : ComponentsInitializer)
              init |> set("transform", tm)