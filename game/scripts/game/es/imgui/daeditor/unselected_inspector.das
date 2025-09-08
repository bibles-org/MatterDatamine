require ecs
require imgui
require DagorEditor
require daslib.strings_boost
require danetlibs.imgui_daeditor.imgui.daEditor.ecs_inspectors_macro
require danetlibs.imgui_daeditor.daEditor.daEditor_common


[ecs_unselected_inspector]
def draw_unselected_inspector() : void
  if imgui::Button("Select hero")
    query() <| $ [es(REQUIRE=hero)] (eid : EntityId)
      editor_open()
      editor_select_eid(eid)
      editor_open(false)
  if imgui::Button("Select local player")
    query() <| $ [es(REQUIRE=hero)] (possessedByPlr : EntityId)
      query(possessedByPlr) <| $ [es] (eid : EntityId)
        editor_open()
        editor_select_eid(eid)
        editor_open(false)
  find_query() <| $ [es] (spectator__target : EntityId)
    if spectator__target != INVALID_ENTITY_ID
      if imgui::Button("Select spectate target")
        editor_open()
        editor_select_eid(spectator__target)
        editor_open(false)
    return true
  if imgui::Button("Select active camera")
    query() <| $ [es] (eid : EntityId; camera__active : bool)
      if camera__active
        editor_open()
        editor_select_eid(eid)
        editor_open(false)
  if imgui::Button("Select nearest friend")
    query() <| $ [es(REQUIRE=hero)] (eid aka hero_eid : EntityId; team aka my_team : int; transform aka my_transform : float3x4)
      var bestDstSq = FLT_MAX
      var bestEid = INVALID_ENTITY_ID
      query() <| $ [es(REQUIRE_NOT=camera__active)] (eid aka their_eid : EntityId; team aka their_team : int; transform aka their_transform : float3x4)
        if my_team == their_team && hero_eid != their_eid
          let dstSq = distance_sq(my_transform[3], their_transform[3])
          if dstSq < bestDstSq
            bestDstSq = dstSq
            bestEid = eid
      editor_open()
      editor_select_eid(bestEid)
      entity_object_editor_zoomAndCenter()
  if imgui::Button("Select nearest enemy")
    query() <| $ [es(REQUIRE=hero)] (team aka my_team : int; transform aka my_transform : float3x4)
      var bestDstSq = FLT_MAX
      var bestEid = INVALID_ENTITY_ID
      query() <| $ [es] (eid : EntityId; team aka their_team : int; transform aka their_transform : float3x4)
        if my_team != their_team
          let dstSq = distance_sq(my_transform[3], their_transform[3])
          if dstSq < bestDstSq
            bestDstSq = dstSq
            bestEid = eid
      editor_open()
      editor_select_eid(bestEid)
      entity_object_editor_zoomAndCenter()
  query() <| $ [es(REQUIRE=hero)] (human_weap__gunEids : EidList; human_weap__currentGunSlot : int = -1)
    for i in range(3)
      if length(human_weap__gunEids) > i && human_weap__gunEids[i] != INVALID_ENTITY_ID
        let w1Name = get_first_template(human_weap__gunEids[i])
        let isCur = human_weap__currentGunSlot == i
        if imgui::Button("Select weapon {i} {isCur ? "current" : ""} <{human_weap__gunEids[i]}>({w1Name})")
          editor_open()
          editor_select_eid(human_weap__gunEids[i])
          editor_open(false)
  query() <| $ [es(REQUIRE=hero)] (human_use_object__selectedObject : EntityId)
    if human_use_object__selectedObject != INVALID_ENTITY_ID
      let selectedName = get_first_template(human_use_object__selectedObject)
      if imgui::Button("Select hero's selected object <{human_use_object__selectedObject}>({selectedName})")
        editor_open()
        editor_select_eid(human_use_object__selectedObject)
        editor_open(false)


def get_first_template(eid : EntityId)
  let tmpl = getEntityTemplateName(eid)
  if !empty(tmpl)
    let parts <- split(tmpl, "+")
    return parts[0]
  return "---"