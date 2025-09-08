require ecs
require ecs.common
require net
require game.events.events
require math
require math.base
require game.utils.net_utils
require game.es.teleport_common
require game.es.spawn_common
require DagorMath
require DagorSystem
require game.es.inventory_common
require game.events.inventory_events
require game.events.events_active_matter
require game.es.transform_common
require strings


[es(tag=server)]
def encounter_convert_items(evt : EventOnItemPickup;
                            eid : EntityId)
  query(evt.itemEid) <| $ [es] (encounter_transformable_item__itemsToTransformation : int;
                                encounter_transformable_item__transformationTo : string;
                                encounter_transformable_item__onPickUpMessage : string;
                                encounter_transformable_item__onEndCollectMessage : string)
    query(eid) <| $ [es] (itemContainer : EidList)
      var isTransformedTo = false
      var spareParts : array<tuple<idx : int; eid : EntityId>>
      for idx, item in iter_range(itemContainer), itemContainer
        if item |> has("encounter_transformable_item__itemsToTransformation")
          spareParts |> emplace((idx, item))

      if spareParts |> length() >= encounter_transformable_item__itemsToTransformation
        for i in range(0, encounter_transformable_item__itemsToTransformation)
          destroyEntity(spareParts[i].eid)
        createEntity(encounter_transformable_item__transformationTo) <| $(var init)
          set(init, "item__containerOwnerEid", eid)
        isTransformedTo = true

      if isTransformedTo
        let key = encounter_transformable_item__onEndCollectMessage
        send_net_event(eid, CmdHeroLogExEvent(event = "", key = key), target_entity_conn(eid))
      else
        let key = encounter_transformable_item__onPickUpMessage
        using() <| $(var data : Object)
          set(data, "count", "{encounter_transformable_item__itemsToTransformation - spareParts |> length()}")
          send_net_event(eid, CmdHeroLogExEvent(event = "", key = key, data = ecs_addr(data)), target_entity_conn(eid))


[es(tag=server, REQUIRE=game_interactable_object)]
def game_interactable_object_use(evt : CmdUse;
                                 eid : EntityId;
                                 game_interactable_object__requiredItemTag : string;
                                 game_interactable_object__requiredItemIsConsumable : bool;
                                 game_interactable_object__eventTrigger : string;
                                 game_interactable_object__disposable : bool;
                                 var use_object__enabled : bool&)
  if !use_object__enabled
    return

  assume eventTrigger = game_interactable_object__eventTrigger
  if eventTrigger == ""
    return

  if game_interactable_object__requiredItemTag != ""
    if game_interactable_object__requiredItemIsConsumable
      if !destroy_item_with_comp(evt.requesterEid, game_interactable_object__requiredItemTag)
        return
    else
      if !has_item_with_comp(evt.requesterEid, game_interactable_object__requiredItemTag)
        return

  if game_interactable_object__disposable
    use_object__enabled = false

  broadcast_net_event(EventGameTrigger(source = eid, triggerHash = int(ecs_hash(eventTrigger)), target = evt.requesterEid))


[es(on_appear)]
def encounter_additional_game_object_point_init(evt : Event;
                                                encounter_additional_game_object_point__type : string;
                                                var encounter_additional_game_object_point__typeHash : int&)
  encounter_additional_game_object_point__typeHash = int(ecs_hash(encounter_additional_game_object_point__type))


[es(tag=gameClient, on_appear)]
def setup_default_game_interactable_prompt(evt : Event; item__setCustomUsePrompt : string; var game_interactable_object__defaultCustomUsePrompt : das_string&)
  game_interactable_object__defaultCustomUsePrompt := item__setCustomUsePrompt


[es(tag=gameClient, no_order, REQUIRE=game_interactable_object__selected)]
def update_hero_use_state_for_game_interactable(act : UpdateStageInfoAct;
                                                game_interactable_object__requiredItemTag : string;
                                                game_interactable_object__defaultCustomUsePrompt : string;
                                                game_interactable_object__requiredItemMissingPrompt : string;
                                                var item__setCustomUsePrompt : das_string&;
                                                var item__useActionAvailable : bool&)
  item__useActionAvailable = true
  item__setCustomUsePrompt := game_interactable_object__defaultCustomUsePrompt
  if !empty(game_interactable_object__requiredItemTag)
    find_query() <| $ [es(REQUIRE=hero)] (eid : EntityId)
      item__useActionAvailable = has_item_with_comp(eid, game_interactable_object__requiredItemTag)
      if !item__useActionAvailable
        item__setCustomUsePrompt := game_interactable_object__requiredItemMissingPrompt
      return true


[es(tag=server, no_order, REQUIRE=encounter_random_teleport_zone)]
def encounter_random_teleport_zone_update(act : ParallelUpdateFrameDelayed;
                                          transform aka zone_transform : float3x4;
                                          sphere_zone__radius : float const?;
                                          encounter_random_teleport_zone__teleportInEffectName : string;
                                          encounter_random_teleport_zone__teleportOutEffectName : string)
  let sphereZoneRadiusSq = sphere_zone__radius != null ? square(*sphere_zone__radius) : 0.0
  let zoneItm = sphere_zone__radius == null ? inverse(zone_transform) : IDENT_TM
  query() <| $ [es(REQUIRE=possessedByPlr)] (eid : EntityId;
                                             team aka possessed_team : int;
                                             transform aka target_transform : float3x4)
    if !is_point_in_box_or_sphere_zone(target_transform[3], zone_transform[3], zoneItm, sphereZoneRadiusSq)
      return

    let prevTargetTransform = target_transform

    teleport_eid_to(eid, find_safe_spawn_pos(possessed_team), false)

    if encounter_random_teleport_zone__teleportInEffectName != ""
      createEntity(encounter_random_teleport_zone__teleportInEffectName) <| $(var init)
        init |> set("transform", prevTargetTransform)
    if encounter_random_teleport_zone__teleportOutEffectName != ""
      createEntity(encounter_random_teleport_zone__teleportOutEffectName) <| $(var init)
        init |> set("transform", target_transform)
