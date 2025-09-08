require ecs
require AnimV20
require CollRes
require inventory
require game.es.inventory_common
require DngCamera
require DngHuman
require HumanPhys
require DagorMath
require DagorMathUtils
require game.es.inventory_checks_common
require math.base
require Grid

let
  DEFAULT_USEFUL_COLOR = E3DCOLOR(0xFF8A2BE2) // 0xARGB
  DEFAULT_OVERWEIGHT_COLOR = E3DCOLOR(0xFFC80000)


[es(tag=gameClient, on_appear, REQUIRE=outlinedItem, REQUIRE_NOT=transform)]
def remove_item_outline_on_pickup_es(evt : Event; eid : EntityId)
  removeSubTemplate(eid, "outlined_item")


[es(tag=gameClient, after=hero_human_use_inventory_es, REQUIRE=hero)]
def item_outline_color_update(info : UpdateStageInfoAct; eid : EntityId; human_use_object__selectedObject : EntityId;
                              human_item_outline__visibilityRadius : float)
  let camTmComp = get_TMatrix(get_cur_cam_entity(), "transform")
  if camTmComp == null
    return
  let curPos = (*camTmComp)[3]
  let humanEid = eid
  for_each_entity_in_grid(ecs_hash("loot"), BSphere3(curPos, human_item_outline__visibilityRadius), GridEntCheck.POS) <| $(lootEid : EntityId)
    if !has(lootEid, "outlinedItem")
      addSubTemplate(lootEid, "outlined_item")
  query() <| $ [es(REQUIRE=outlinedItem)] (eid : EntityId; var outline__chosenColor : E3DCOLOR&;
                                           outline__baseColor : E3DCOLOR;
                                           outline__usefulColor : E3DCOLOR;
                                           outline__overweightColor : E3DCOLOR;
                                           var item_outline__recalcColorAt : float&;
                                           item_outline__recalcColorTimer : float)
    if item_outline__recalcColorAt > info.curTime
      return
    if !is_can_pickup_item(humanEid, eid)
      outline__chosenColor = outline__overweightColor
    elif is_item_useful(humanEid, eid)
      outline__chosenColor = outline__usefulColor
    else
      outline__chosenColor = outline__baseColor
    item_outline__recalcColorAt = info.curTime + item_outline__recalcColorTimer

  query() <| $ [es(REQUIRE=outlinedItem)] (eid : EntityId; transform : float3x4; var outline__color : E3DCOLOR&;
                                           outline__chosenColor : E3DCOLOR;
                                           outline__selectedMult : float = 1.0;
                                           outline__unselectedMult : float = 0.4;
                                           item_outline__posMult : float = 0.7;
                                           item_outline__timeMult : float = 8.0)
    let distSq = length_sq(transform[3] - curPos)
    if distSq > square(human_item_outline__visibilityRadius)
      removeSubTemplate(eid, "outlined_item")
      return
    let posTimeOffset = (transform[3].x + transform[3].z) * item_outline__posMult
    let timeInput = (info.curTime + posTimeOffset) * item_outline__timeMult
    let sinMult = cvt(sin(timeInput), -1.0, 1.0, 0.5, 1.0)
    let distMult = cvt(sqrt(distSq) / human_item_outline__visibilityRadius, 0.5, 1.0, outline__unselectedMult, 0.0)
    var mult : float = distMult * square(sinMult)
    if eid == human_use_object__selectedObject
      mult = outline__selectedMult
    else
      // make only 10 different gradations, to reduce number of different outline colors
      mult = floor(mult / outline__unselectedMult * 10.0) / 10.0 * outline__unselectedMult
    let baseColor = outline__chosenColor
    let color = min(float4(uint4(baseColor)) * mult, float4(255.0, 255.0, 255.0, 255.0))
    outline__color = E3DCOLOR(uint4(color.x, color.y, color.z, color.w))


[es(tag=gameClient, REQUIRE=hero, track=human_use_object__selectedObject)]
def toggle_ui_visible(evt : Event; human_use_object__selectedObject : EntityId)
  query() <| $ [es(REQUIRE=ui_visible)] (eid : EntityId)
    removeSubTemplate(eid, "ui_visible")
  if human_use_object__selectedObject != INVALID_ENTITY_ID
    addSubTemplate(human_use_object__selectedObject, "ui_visible")


//transform instead of server_transform is used to make this logic meaningful for what the client sees
def get_item_pickup_score(eid, item_eid : EntityId; view_convex : Point4List; view_itm : float3x4; aimDir, aimFrom, aimTo, minPickupBox : float3; was_selected : bool) : ItemPickupScore
  var ret = ItemPickupScore(score = -1.0, useful = false)
  ecs::query(item_eid) <| $ [es] (animchar_render__enabled : bool = true;
                                  item__lastContainerOwnerEid : EntityId;
                                  item__equipmentSlots : StringList const?;
                                  var transform : float3x4 const?;
                                  collres : CollisionResource const?;
                                  animchar : AnimcharBaseComponent;
                                  animchar_render : AnimcharRendComponent;
                                  boxed_item__actionsBlock : bool = false;
                                  item__id : int = INVALID_ITEM_ID;
                                  item_pickup_priority__lookAtWeight : float = 4.f;
                                  item_pickup_priority__usefulWeight : float = 0.1f;
                                  item_pickup_priority__angleWeight : float = 1.f;
                                  item_pickup_priority__useCollresMinWidth : float = 1.5f;
                                  item__visible : bool = true;
                                  item__disablePickup : bool = false;
                                  item__blockInventoryMove : Tag const?;
                                  forceVisibleInUi : Tag const? = null)
    // TODO: remove this hack
    // this is a hack (forceVisibleInUi) to make items visible in UI
    // in future need add ability creation items without animchar
    if !animchar_render__enabled && forceVisibleInUi == null || !item__visible || item__disablePickup || item__blockInventoryMove != null || boxed_item__actionsBlock
      return
    if item__id == INVALID_ITEM_ID && item__equipmentSlots == null
      return

    if transform == null
      transform = get_TMatrix(item__lastContainerOwnerEid, "transform")
    if transform == null
      return

    var lbb = BBox3()
    scene_instance_get_local_bounding_box(animchar_render.sceneInstance, lbb)
    lbb |> bbox3_add(minPickupBox)
    lbb |> bbox3_add(-minPickupBox)
    let entPos = (*transform) * lbb.center
    // base score based on the angle
    ret.itemDot = dot(normalize(entPos - aimFrom), aimDir)
    ret.score = ret.itemDot * item_pickup_priority__angleWeight

    // if behind the view, return (res.score < 0.0 = check failed)
    if ret.score < 0.0
      return

    let outOfFrustumBias = -0.5
    let checkPos = view_itm * entPos
    for plane in view_convex
      let dist = distance_plane_point3(plane, checkPos)
      if dist > 0.0
        ret.score += outOfFrustumBias
        break

    let width = lbb.width
    if collres == null || width.x + width.y + width.z < item_pickup_priority__useCollresMinWidth
      let itemItm = inverse(*transform)
      let from = itemItm * aimFrom
      let to = itemItm * aimTo
      if test_segment_box_intersection(from, to, lbb)
        ret.score += item_pickup_priority__lookAtWeight
    else
      let t = 10f
      if collres_rayhit(*collres, *transform, animchar.nodeTree, aimFrom, aimDir, t)
        ret.score += item_pickup_priority__lookAtWeight

    ret.useful = is_item_useful(eid, item_eid)
    if ret.useful
      ret.score += item_pickup_priority__usefulWeight

    let selectedItemBias = 0.05
    if was_selected
      ret.score += selectedItemBias

  return ret


[es(tag=gameClient, after=(hero_human_use_vehicle_object_es, before_human_inventory_use_update),
    before=hero_human_final_use_object_sync, REQUIRE=hero, REQUIRE_NOT=deadEntity)]
def hero_human_use_inventory_es(info : UpdateStageInfoAct;
                                eid : EntityId;
                                itemsAround : EidList;
                                human__aimTm : float3x4;
                                var human_use_object__selectedObject : EntityId&;
                                var human_use_object__selectedObjectDot : float&;
                                human_use_object__lastSelectedObject : EntityId;
                                human_inventory__selectConvex : Point4List;
                                human_inventory__selectTpsConvex : Point4List;
                                human_inventory__pickupRadius : float = 2.5;
                                human_inventory__pickupHeight : float = 2.5;
                                human_inventory__pickupItemMinBox : float3 = float3(0.1f, 0.1f, 0.1f);
                                human__canPickupItems : bool = true;
                                human_net_phys : HumanActor;
                                isTpsView : bool = false)
  if !human__canPickupItems || (human_use_object__selectedObject != INVALID_ENTITY_ID && human_use_object__selectedObjectDot <= -1.0)
    return

  var bestScore = FLT_MIN
  var bestEntity = ecs::INVALID_ENTITY_ID
  var bestEntityDot = -1.0
  var isBestUseful = false

  let camTmComp = get_TMatrix(get_cur_cam_entity(), "transform")
  if camTmComp == null
    return
  var camTm := *camTmComp
  camTm[0] = camTm[2]
  camTm |> orthonormalize()

  let tps = isTpsView && human_net_phys.phys.currentState.zoomPosition == 0.0
  let viewTm & = camTm
  let viewItm = inverse(viewTm)

  let aimDir = viewTm[0]
  let projToChar = tps ? dot(human__aimTm[3] - viewTm[3], viewTm[0]) * aimDir : float3(0.0)
  let pickupDistanceUpperBound = human_inventory__pickupRadius + human_inventory__pickupHeight
  let aimFrom = viewTm[3] + projToChar
  let aimTo = aimFrom + aimDir * pickupDistanceUpperBound

  for itemEid in itemsAround
    if itemEid == eid
      continue

    let pickupScore = get_item_pickup_score(eid, itemEid, tps ? human_inventory__selectTpsConvex : human_inventory__selectConvex,
                                            viewItm, aimDir, aimFrom, aimTo, human_inventory__pickupItemMinBox, human_use_object__lastSelectedObject == itemEid)
    if pickupScore.score > bestScore

      if human_use_object__selectedObjectDot > -1.0
        if pickupScore.itemDot < human_use_object__selectedObjectDot
          continue

      isBestUseful = pickupScore.useful
      bestScore = pickupScore.score
      bestEntity = itemEid
      bestEntityDot = pickupScore.itemDot

  if bestEntity != INVALID_ENTITY_ID
    human_use_object__selectedObject = bestEntity
    human_use_object__selectedObjectDot = bestEntityDot
