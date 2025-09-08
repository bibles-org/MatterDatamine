require ecs
require DagorMath
require RendInst
require CollRes
require Grid
require net
require strings
require game.events.events
require game.events.events_active_matter
require game.es.use_query_params_common
require game.utils.hero
require daslib/algorithm
require game.es.transform_common
require game.es.status_tip_common
require math.base


[es(tag=gameClient, before=hero_human_pre_use_object_es)]
def hero_human_use_entity(act : UpdateStageInfoAct;
                          client_usable_objects__extraQueryRadius = 0.;
                          var client_usable_objects__usableEids : EidList;
                          var client_usable_objects__usableEntityDots : FloatList)
  clear(client_usable_objects__usableEids)
  clear(client_usable_objects__usableEntityDots)
  let params = get_use_query_params(get_controlled_hero())
  if !params.canUse
    return
  let queryRadius = params.dist.x + client_usable_objects__extraQueryRadius
  let viewBB = BBox3(params.pos + params.dir * queryRadius * .5, queryRadius)
  for_each_entity_in_grid(ecs_hash("interactable"), viewBB, GridEntCheck.BOUNDING)  <| $(targetEid : EntityId)
    query(targetEid) <| $ [es(REQUIRE=clientUsable)] (transform : float3x4; use_object__offset : float3 const?; use_object__enabled = true)
      if !use_object__enabled
        return
      let pos = use_object__offset != null ? transform * (*use_object__offset) : transform[3]
      let dot = dot(normalize(pos - params.pos), params.dir)
      let insertionIndex = client_usable_objects__usableEntityDots |> lower_bound(dot) <| $(x, y)
        return x > y
      client_usable_objects__usableEids |> push(targetEid, insertionIndex)
      client_usable_objects__usableEntityDots |> push(dot, insertionIndex)


def calc_obb(ri_extra__handle : uint64; var use_object__obbMin, use_object__obbMax : float3&) : bool
  let riType = handle_to_ri_type(ri_extra__handle)
  let collres = get_ri_gen_extra_collres(int(riType))
  if collres != null
    use_object__obbMin = collres.boundingBox.boxMin
    use_object__obbMax = collres.boundingBox.boxMax
    return true
  return false


[es(on_appear, on_event=EventRiExtraLoaded, after=check_ri_extra_loading_needed)]
def auto_calc_ri_extra_use_box_on_appear(evt : Event; ri_extra : RiExtraComponent; var use_object__obbMin, use_object__obbMax : float3&)
  if length_sq(use_object__obbMin) == 0. && length_sq(use_object__obbMax) == 0.
    ri_extra.handle |> calc_obb(use_object__obbMin, use_object__obbMax)


[es(on_appear, REQUIRE_NOT=ri_extra, after=rendinst_with_handle_move_es)]
def auto_calc_ri_extra_handle_use_box(evt : Event; ri_extra__handle : uint64; var use_object__obbMin, use_object__obbMax : float3&)
  if length_sq(use_object__obbMin) == 0. && length_sq(use_object__obbMax) == 0.
    ri_extra__handle |> calc_obb(use_object__obbMin, use_object__obbMax)


[es(on_appear)]
def auto_calc_collres_use_box(evt : Event; collres : CollisionResource;  var use_object__obbMin, use_object__obbMax : float3&)
  if length_sq(use_object__obbMin) == 0. && length_sq(use_object__obbMax) == 0.
    use_object__obbMin = collres.boundingBox.boxMin
    use_object__obbMax = collres.boundingBox.boxMax


def add_selected_tag(eid)
  query(eid) <| $ [es] (use_object__selectedTemplate : string)
    if !empty(use_object__selectedTemplate)
      eid |> addSubTemplate(use_object__selectedTemplate)


def remove_selected_tag(eid)
  query(eid) <| $ [es] (use_object__selectedTemplate : string)
    if !empty(use_object__selectedTemplate)
      eid |> removeSubTemplate(use_object__selectedTemplate)


[es(tag=gameClient, REQUIRE=hero, track=human_use_object__selectedObject)]
def toggle_selected_object_tag(evt : Event; human_use_object__selectedObject, human_use_object__lastSelectedObject : EntityId)
  remove_selected_tag(human_use_object__lastSelectedObject)
  add_selected_tag(human_use_object__selectedObject)


[es(tag=gameClient, REQUIRE=hero, on_disappear)]
def removev_selected_object_tag(evt : Event; human_use_object__selectedObject, human_use_object__lastSelectedObject : EntityId)
  remove_selected_tag(human_use_object__lastSelectedObject)
  remove_selected_tag(human_use_object__selectedObject)


[es(tag=gameClient, on_event=EventUseObjectBlocked, REQUIRE=eid)]
def disaply_human_use_object_fail_reason(evt : Event)
  query() <| $ [es(REQUIRE=hero)] (eid : EntityId; human_use_object__blockReason : string; human_use_object__blockReasonStatusTip : string)
    if !empty(human_use_object__blockReason)
      sendEvent(eid, CmdHeroLogExEventLocal(event = "interaction_denied", key = human_use_object__blockReason))
    elif !empty(human_use_object__blockReasonStatusTip)
      create_status_tip(human_use_object__blockReasonStatusTip)
