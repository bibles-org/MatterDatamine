require ecs
require inventory
require GridCollision
require GeomNodeTree
require DagorMath
require AnimV20
require math.base
require CollRes
require Grid
require game.es.inventory_checks_common


[es(after=human_visibility_tracer_es, before=hero_human_use_inventory_es, tag=(ui, render, gameClient), REQUIRE=watchedByPlr, REQUIRE_NOT=deadEntity)]
def items_around_es(info : UpdateStageInfoAct;
                    var itemsAround : EidList;
                    transform aka hero_transform : float3x4;
                    human_inventory__lookNodeId : int;
                    animchar : AnimcharBaseComponent;
                    resources_gatherer_hero__enabled : bool = false;
                    human_inventory__pickupRadius : float;
                    human_inventory__pickupHeight : float;
                    human_inventory__pickupRemoveRadius : float;
                    human_inventory__pickupRemoveHeight : float)
  var queryPos = transform[3]
  if human_inventory__lookNodeId >= 0
    queryPos = geomtree_getNodeWpos(*animchar.nodeTree, human_inventory__lookNodeId)

  var stillNear : array<EntityId>
  for itemEid in itemsAround
    query(itemEid) <| $ [es] (transform : float3x4;
                              item__visible : bool;
                              animchar_render__enabled : bool = true;
                              collres : CollisionResource const? = null;
                              item__am : Tag const?;
                              forceVisibleInUi : Tag const? = null)
      assume isItemAm = item__am != null
      if !resources_gatherer_hero__enabled && isItemAm
        return
      let isItemNear = is_item_accessible_by_distance(human_inventory__lookNodeId, animchar, hero_transform,
          human_inventory__pickupRemoveRadius, human_inventory__pickupRemoveHeight, transform, collres)
      if (item__visible && isItemNear && (animchar_render__enabled || forceVisibleInUi != null))
        stillNear |> push(itemEid)
  itemsAround |> clear()
  for itemEid in stillNear
    itemsAround |> push(itemEid)

  let bestQueryPos = length(transform[3] - queryPos)
  let radius = human_inventory__pickupRemoveRadius + human_inventory__pickupRemoveHeight + bestQueryPos
  let hmapDisplacementReserve = 0.3
  for_each_entity_in_grid(ecs_hash("loot"), BSphere3(queryPos, radius + hmapDisplacementReserve), GridEntCheck.BOUNDING) <| $(eid : EntityId)
    query(eid) <| $ [es] (eid : EntityId;
                          transform aka item_transform : float3x4;
                          server_transform : float3x4;
                          item__visible : bool;
                          animchar_render__enabled : bool = true;
                          collres : CollisionResource const? = null;
                          item__am : Tag const?;
                          forceVisibleInUi : Tag const? = null)
      assume isItemAm = item__am != null
      if !resources_gatherer_hero__enabled && isItemAm
        return

      if distance_sq(server_transform[3], queryPos) > square(radius)
        return
      // TODO: remove this hack
      // this is a hack (forceVisibleInUi) to make items visible in UI
      // in future need add ability creation items without animchar
      let stillNearIdx = find_index(stillNear, eid)
      // assume here so we don't calculate is_item_accessible_by_distance again if item was near us before (stillNearIdx > 0)
      assume isItemNear = is_item_accessible_by_distance(human_inventory__lookNodeId, animchar, hero_transform,
          human_inventory__pickupRadius, human_inventory__pickupHeight, item_transform, collres)
      if stillNearIdx == -1 && item__visible && isItemNear && (animchar_render__enabled || forceVisibleInUi != null)
        itemsAround |> push(eid)


[es(on_event=EventComponentsDisappear, tag=(ui, render, gameClient), REQUIRE=watchedByPlr, REQUIRE_NOT=deadEntity)]
def clear_items_around_es(evt : Event; var itemsAround : EidList)
  itemsAround |> clear()
