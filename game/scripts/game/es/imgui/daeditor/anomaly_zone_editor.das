options no_global_variables = false
require ecs
require imgui
require math.base
require DagorImgui
require DagorDebug3D
require DagorMath
require DagorEditor

require daslib/static_let
require daslib/safe_addr

require game.events.events_active_matter
require active_matter.game.es.anomalies.anomaly_zones_common
require danetlibs.imgui_daeditor.imgui.daEditor.ecs_inspectors_macro
require danetlibs.imgui_daeditor.daEditor.daEditor_common


[ecs_editor(tags=(anomaly_zone__generated, transform))]
def anomaly_editor(selected_eid : array<EntityId> const#)
  static_let <|
    var autoZoom = false
    var randomGen = true
  var points : array<tuple<eid : EntityId; pos : float3>>
  query() <| $ [es(REQUIRE=anomaly_zone__generated)] (eid : EntityId; transform : float3x4)
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

  if imgui::Button("Select prev##az{selected_eid[0]}")
    selectedIdx -= 1
    if selectedIdx < 0
      selectedIdx += length(points)
    editor_select_eid(points[selectedIdx].eid)
    if autoZoom
      entity_object_editor_zoomAndCenter()

  imgui::SameLine()
  if imgui::Button("Select next##az{selected_eid[0]}")
    selectedIdx += 1
    if selectedIdx >= length(points)
      selectedIdx = 0
    editor_select_eid(points[selectedIdx].eid)
    if autoZoom
      entity_object_editor_zoomAndCenter()

  if imgui::Button("Cleanup")
    cleanup_zone_children(selected_eid[0])
  SameLine()

  if imgui::Button("Regen")
    cleanup_zone_children(selected_eid[0])
    if randomGen
      selected_eid[0] |> set("nmesh_voxel__randomSeed", 0)
    selected_eid[0] |> set("anomaly_zone__generated", false)
    sendEvent(selected_eid[0], CmdGenerateAnomalyZone())

  SameLine()
  imgui::Checkbox("Randomize##az{selected_eid}", safe_addr(randomGen))

  EndGroup()
  SameLine()
  BeginGroup()

  imgui::Checkbox("Auto zoom##poi{selected_eid[0]}", safe_addr(autoZoom))

  EndGroup()


[es(tag=(render, dev), REQUIRE=daeditor__selected, no_order)]
def draw_selected_anomaly_zone(evt : UpdateStageInfoRenderDebug; transform : float3x4;
                               nmesh_voxel__gridSize : int3; nmesh_voxel__gridStep : float)
  begin_draw_cached_debug_lines(false, false, false)

  let width = float3(nmesh_voxel__gridSize) * (nmesh_voxel__gridStep * 0.5)
  let box = BBox3(transform[3] - width, transform[3] + width)
  draw_cached_debug_box(box, E3DCOLOR(0xFFFFFFFF))

  let centerBox = BBox3(transform[3], nmesh_voxel__gridStep)
  draw_cached_debug_box(centerBox, E3DCOLOR(0xFFFFFFFF))

  end_draw_cached_debug_lines()