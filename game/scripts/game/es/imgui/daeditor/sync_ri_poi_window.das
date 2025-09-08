options no_global_variables = false
require ecs
require math.base
require game.events.events
require imgui
require pathfinder
require DagorImgui
require DagorConsole
require DagorMath
require Dacoll
require DagorDebug3D
require DagorSystem
require RendInst
require DagorEditor
require DagorDataBlock
require danetlibs.imgui_daeditor.daEditor.daEditor_common
require active_matter.game.es.imgui.daEditor.poi_validation_common
require imgui/imgui_boost
require daslib/safe_addr

let
  PP_STATUS_UNKNOWN = 0
  PP_STATUS_MATCHED = 1
  PP_STATUS_NEW = 2
  PP_STATUS_NOT_MATCHED = 3

var
  highlightNotMatched = false
  highlightNew = false
  highlightMatched = false

def eid_to_debug_str(eid)
  return "{eid}:<{getEntityTemplateName(eid)}>"

def ri_name_by_handle(handle : riex_handle_t) : string
  return riex_getRIGenExtraName(handle_to_ri_type(handle))

def generate_poi_prototypes()
  query() <| $ [es(REQUIRE=poiPrototype)] (eid : EntityId)
    destroyEntity(eid)
  let onRiGenCreateDone <- @ <| (eid : EntityId)
    sendEvent(eid, EventRIGenExtraRequested())
  createEntity("am_poi_generator", onRiGenCreateDone) <| $ [unused_argument(_)] (_){}

def destroyPrototype(eid)
  query(eid) <| $ [es] (var ri_extra__handle : riex_handle_t&)
    ri_extra__handle = 0
  destroyEntity(eid)

[es(tag=server, on_appear, REQUIRE=poiGenerationIsDone)]
def on_poi_generation_is_done(evt : Event; eid : EntityId)
  destroyEntity(eid)
  query() <| $ [es(REQUIRE=pointOfInterest)] (eid : EntityId; transform aka poi_transform : float3x4; poi__bindedToRi : bool)
    if !poi__bindedToRi
      return
    let poiEid = eid
    var status = PP_STATUS_UNKNOWN
    var matchedEid : EntityId
    query() <| $ [es(REQUIRE=poiPrototype)] (eid : EntityId;
                                             transform : float3x4;
                                             ri_extra__handle : riex_handle_t;
                                             use_object__offset : float3;
                                             var poi_prototype__status : int&;
                                             var poi_prototype__matchedEid : EntityId&)
      let pos = transform * use_object__offset
      if distance_sq(pos, poi_transform[3]) < 0.01

        if poi_prototype__status == PP_STATUS_UNKNOWN
          poi_prototype__status = PP_STATUS_MATCHED
          poi_prototype__matchedEid = poiEid
        else
          let matchedName = ri_name_by_handle(ri_extra__handle)
          logerr("One Ri (<{matchedName}>) at {transform[3]} offsetted to {pos} matches several poi:
              {eid_to_debug_str(poi_prototype__matchedEid)} and {eid_to_debug_str(poiEid)}")

        if status == PP_STATUS_UNKNOWN
          status = PP_STATUS_MATCHED
          matchedEid = eid
        else
          let matchedName = ri_name_by_handle(ri_extra__handle)
          logerr("Sevral RI match the same poi {eid_to_debug_str(poiEid)}. Which one to match? {transform[3]} offsetted to {pos}, one of teh Ri name: <{matchedName}>")

    if status != PP_STATUS_MATCHED
      createEntity("not_matched_poi_prototype") <| $(init)
        set(init, "transform", poi_transform)
        set(init, "poi_prototype__matchedEid", eid)
  query() <| $ [es(REQUIRE=poiPrototype)] (use_object__offset : float3; var poi_prototype__status : int&; var transform : float3x4)
    if poi_prototype__status == PP_STATUS_UNKNOWN
      poi_prototype__status = PP_STATUS_NEW
      let pos = transform * use_object__offset
      identity(transform)
      transform[3] = pos


[imgui_window(name="Sync poi with RI", group = "AM")]
def sync_poi_with_ri_window()
  if IsWindowCollapsed()
    return
  var notMatchedEids : array<EntityId>
  var newPrototypes : array<tuple<eid : EntityId; templateName : string; transform : float3x4>>
  var validCount = 0
  query() <| $ [es(REQUIRE=poiPrototype)] (eid, poi_prototype__matchedEid : EntityId;
                                           transform : float3x4;
                                           poi_prototype__status : int;
                                           poi_prototype__targetTemplate : string)
    if poi_prototype__status == PP_STATUS_NOT_MATCHED
      query(poi_prototype__matchedEid) <| $ [es] (eid : EntityId; poi__bindedToRi : bool)
        if poi__bindedToRi
          push(notMatchedEids, eid)
    if poi_prototype__status == PP_STATUS_NEW
      emplace(newPrototypes,  (eid, poi_prototype__targetTemplate, transform))
    if poi_prototype__status == PP_STATUS_MATCHED
      validCount++
  var unbindedPoiCount = 0
  query() <| $ [es] (poi__bindedToRi : bool)
    if !poi__bindedToRi
      unbindedPoiCount++

  imgui::Checkbox("Highlight not matched##poi", safe_addr(highlightNotMatched))
  imgui::Checkbox("Highlight new##poi", safe_addr(highlightNew))
  imgui::Checkbox("Highlight valid##poi", safe_addr(highlightMatched))
  if imgui::Button("Generate poi prototypes from RI##poi")
    generate_poi_prototypes()
  if imgui::Button("Save all poi##poi")
    save_poi_to_file()
  imgui::NewLine()

  if validCount > 0
    imgui::Text("{validCount} poi still match their RI - no action required")
    imgui::NewLine()
  if unbindedPoiCount > 0
    imgui::Text("{unbindedPoiCount} poi are unbinded from RI")
    imgui::NewLine()

  imgui::Separator()

  if length(notMatchedEids) > 0
    imgui::Text("Poi that no longer have RI:")
    for eid in notMatchedEids
      imgui::Text("{getEntityTemplateName(eid)}:")
      imgui::SameLine()
      if imgui::Button("Zoom##{eid}poi")
        editor_open()
        editor_select_eid(eid)
        entity_object_editor_zoomAndCenter()
      imgui::SameLine()
      if imgui::Button("Unbind from RI##{eid}poi")
        query(eid) <| $ [es] (var poi__bindedToRi : bool&)
          poi__bindedToRi = false
          entity_obj_editor_saveComponent(eid, "poi.bindedToRi")
    imgui::Separator()

  if length(newPrototypes) > 0
    imgui::Text("New poi:")
    if imgui::Button("Create all##poi")
      editor_open(false)
      for it in newPrototypes
        entity_object_editor_createEntityDirect(it.templateName, it.transform)
        destroyEntity(it.eid)
      editor_open()
    for it in newPrototypes
      imgui::Text("{it.templateName}:")
      imgui::SameLine()
      if imgui::Button("Zoom##{it.eid}poi")
        editor_open()
        editor_select_eid(it.eid)
        entity_object_editor_zoomAndCenter()

      imgui::SameLine()
      if imgui::Button("Create##{it.eid}poi")
        editor_open(false)
        entity_object_editor_createEntityDirect(it.templateName, it.transform)
        editor_open()
        destroyEntity(it.eid)

[es(tag=gameClient, no_order)]
def highligh_poi(act : UpdateStageInfoAct; transform : float3x4; use_object__offset : float3; poi_prototype__status : int)
  let pos = transform * use_object__offset
  if highlightMatched && poi_prototype__status == PP_STATUS_MATCHED
    draw_debug_sphere_buffered(pos, 0.75, E3DCOLOR(0xFF00FF00), 12, 1)
  if highlightNew && poi_prototype__status == PP_STATUS_NEW
    draw_debug_sphere_buffered(pos, 0.75, E3DCOLOR(0xFFFFFF00), 12, 1)
  if highlightNotMatched && poi_prototype__status == PP_STATUS_NOT_MATCHED
    draw_debug_sphere_buffered(pos, 0.75, E3DCOLOR(0xFFFF0000), 12, 1)