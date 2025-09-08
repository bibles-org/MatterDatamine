require ecs
require imgui
require DagorImgui
require DagorDebug3D
require DagorConsole
require DagorSystem
require DagorMath
require DagorEditor
require math.base

require daslib/static_let
require daslib/safe_addr

require danetlibs.imgui_daeditor.imgui.daEditor.ecs_inspectors_macro
require danetlibs.imgui_daeditor.daEditor.daEditor_common


[imgui_func(name="Edit indoor poi", group="AM")]
def select_indoor_poi()
  let found = find_query() <| $ [es(REQUIRE=(indoorPointOfInterest, transform))] (eid : EntityId)
    editor_open()
    imgui_window_set_visible("Editor", "Inspector", true)
    editor_select_eid(eid)
    return true
  if !found
    editor_open(false)
    entity_object_editor_createEntityDirect("indoor_point_of_interest", IDENT_TM)
    editor_open()
    select_indoor_poi()


[ecs_editor(tags=(indoorPointOfInterest, transform))]
def indoor_poi_editor(selected_eid : array<EntityId> const#)
  static_let <|
    var highlightAll = false
    var autoZoom = false
  var points : array<tuple<eid : EntityId; pos : float3>>
  query() <| $ [es(REQUIRE=indoorPointOfInterest)] (eid : EntityId; transform : float3x4)
    points |> emplace <|  (eid, transform[3])

  points |> sort <| $(a; b)
    return uint(a.eid) < uint(b.eid)

  var selectedIdx = 0
  for idx, it in iter_range(points), points
    if it.eid == selected_eid[0]
      selectedIdx = idx
      break

  BeginGroup()

  AlignTextToFramePadding()
  imgui::Text("{selectedIdx + 1}/{length(points)}")

  imgui::SameLine()

  if imgui::Button("Select prev##poi{selected_eid[0]}")
    selectedIdx -= 1
    if selectedIdx < 0
      selectedIdx += length(points)
    editor_select_eid(points[selectedIdx].eid)
    if autoZoom
      entity_object_editor_zoomAndCenter()

  imgui::SameLine()
  if imgui::Button("Select next##poi{selected_eid[0]}")
    selectedIdx += 1
    if selectedIdx >= length(points)
      selectedIdx = 0
    editor_select_eid(points[selectedIdx].eid)
    if autoZoom
      entity_object_editor_zoomAndCenter()

  EndGroup()
  SameLine()
  BeginGroup()

  imgui::Checkbox("Auto zoom##poi{selected_eid[0]}", safe_addr(autoZoom))
  imgui::Checkbox("Highlight all##poi{selected_eid[0]}", safe_addr(highlightAll))
  if highlightAll
    for point in points
      draw_debug_sphere_buffered(point.pos, 0.2, E3DCOLOR(0xFF00FF00), 12, 1)

  EndGroup()