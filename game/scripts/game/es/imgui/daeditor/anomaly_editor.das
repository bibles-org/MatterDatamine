options no_global_variables = false
require ecs
require math.base
require EcsUtils
require imgui
require DagorImgui
require DagorDebug3D
require DagorConsole
require DagorSystem
require DagorMath
require DagorDataBlock
require DagorEditor

require daslib/static_let
require daslib/safe_addr
require game.es.level_common

require math.base
require danetlibs.imgui_daeditor.imgui.daEditor.ecs_inspectors_macro
require danetlibs.imgui_daeditor.daEditor.daEditor_common

struct AnomalyConfig
  tag : string
  tagHash : uint
  anomalyTemplate : string
  saveTo : string
  expandsToWalls : bool
  rotatable : bool

let
  darknessAnomalyConfig <- AnomalyConfig(
    tag = "darknessAnomalySpot",
    tagHash = ecs_hash("darknessAnomalySpot"),
    anomalyTemplate = "movable_darkness_anomaly_spawn_box",
    saveTo = "../prog/gameBase/content/active_matter/gamedata/scenes/_geisel_library_darkness_anomaly.blk",
    expandsToWalls = true,
    rotatable = true
  )
  disorientedAnomalyConfig <- AnomalyConfig(
    tag = "disorientedAnomalyTrap",
    tagHash = ecs_hash("disorientedAnomalyTrap"),
    anomalyTemplate = "disoriented_anomaly_trap",
    saveTo = "../prog/gameBase/content/active_matter/gamedata/scenes/_geisel_library_disoriented_anomaly.blk"
  )
  lianaTrapConfig <- AnomalyConfig(
    tag = "lianaTrap",
    tagHash = ecs_hash("lianaTrap"),
    anomalyTemplate = "am_liana_trap",
    saveTo = "../prog/gameBase/content/active_matter/gamedata/scenes/_geisel_library_liana_trap.blk"
  )
  configs <- fixed_array(darknessAnomalyConfig, disorientedAnomalyConfig, lianaTrapConfig)

var configIndex = 0


[imgui_func(name="Edit anomalies", group="AM")]
def select_anomaly()
  let config & = configs[configIndex]
  let found = find_query() <| $ [es(REQUIRE=(anomalySpot, transform))] (eid : EntityId)
    if !has(eid, config.tag, config.tagHash)
      return false
    editor_open()
    imgui_window_set_visible("Editor", "Inspector", true)
    editor_select_eid(eid)
    return true
  if !found
    editor_open(false)
    entity_object_editor_createEntityDirect(config.anomalyTemplate, IDENT_TM)
    editor_open()
    select_anomaly()


[ecs_editor(tags=(anomalySpot, transform))]
def anomaly_editor(selected_eid : array<EntityId> const#)
  static_let <|
    var highlightAll = false
    var autoZoom = false

  let config & = configs[configIndex]

  var points : array<tuple<eid : EntityId; tm : float3x4>>
  query() <| $ [es(REQUIRE=anomalySpot)] (eid : EntityId; transform : float3x4)
    if has(eid, config.tag, config.tagHash)
      points |> emplace <|  (eid, transform)
  points |> sort <| $(a; b)
    return uint(a.eid) < uint(b.eid)

  var selectedIdx = 0
  for idx, it in iter_range(points), points
    if it.eid == selected_eid[0]
      selectedIdx = idx
      break

  BeginGroup()

  AlignTextToFramePadding()
  imgui::Text("Anomaly type to edit:")
  let selectedValue = config.tag
  imgui::SameLine()
  if imgui::BeginCombo("##Anomaly type", selectedValue)
    for c, idx in configs, iter_range(configs)
      let isSelected = configIndex == idx
      if imgui::Selectable(c.tag, isSelected)
        configIndex = idx
        select_anomaly()
    imgui::EndCombo()

  EndGroup()

  imgui::Separator()

  BeginGroup()

  AlignTextToFramePadding()
  imgui::Text("{selectedIdx + 1}/{length(points)}")

  imgui::SameLine()
  if imgui::Button("Select prev##anomaly{selected_eid}")
    selectedIdx -= 1
    if selectedIdx < 0
      selectedIdx += length(points)
    editor_select_eid(points[selectedIdx].eid)
    if autoZoom
      entity_object_editor_zoomAndCenter()

  imgui::SameLine()
  if imgui::Button("Select next##anomaly{selected_eid}")
    selectedIdx += 1
    if selectedIdx >= length(points)
      selectedIdx = 0
    editor_select_eid(points[selectedIdx].eid)
    if autoZoom
      entity_object_editor_zoomAndCenter()

  if imgui::Button("Move anomaly here##anomaly{selected_eid}")
    find_query() <| $ [es] (camera__active : bool; transform : float3x4)
      if camera__active
        let newPos = transform[3] + transform[2] * 0.5
        query(selected_eid[0]) <| $ [es] (var transform : float3x4&)
          transform[3] = newPos
      return camera__active

  if config.expandsToWalls
    if imgui::Button("Expand anomaly to walls##anomaly{selected_eid}")
      query(selected_eid[0]) <| $ [es] (var transform : float3x4&)
        let foundTm = get_nearest_indoor_tm(transform[3], 2f)
        if foundTm is tm
          transform = foundTm as tm

  if config.rotatable
    if imgui::Button("Rotate anomaly##anomaly{selected_eid}")
      query(selected_eid[0]) <| $ [es] (var transform : float3x4&)
        let t0 = transform[0]
        transform[0] = transform[2]
        transform[2] = t0

  if imgui::Button("Save##anomaly{selected_eid}")
    using() <| $(var blk : DataBlock)
      for point in points
        editor_save_entity(point.eid, blk)
      datablock_save_to_text_file(blk, config.saveTo)

  EndGroup()
  SameLine()
  BeginGroup()

  imgui::Checkbox("Auto zoom##anomaly{selected_eid}", safe_addr(autoZoom))

  if imgui::Button("Create new anomaly##anomaly{selected_eid}")
    find_query() <| $ [es] (camera__active : bool; transform : float3x4)
      if camera__active
        var tm = IDENT_TM
        tm[3] = transform[3] + transform[2] * 0.5
        editor_open(false)
        entity_object_editor_createEntityDirect(config.anomalyTemplate, tm)
        editor_open()
      return camera__active

  EndGroup()


[ecs_editor(tags=(darknessAnomalySpot, transform), prefix=false)]
def linked_darkness_anomalies_editor(selected_eid : array<EntityId> const#)
  var first = true
  query() <| $ [es] (eid, darkness_anomaly__spotEid : EntityId)
    if first
      imgui::Text("Related darkness zones:")
      first = false
    if darkness_anomaly__spotEid == selected_eid[0]
      AlignTextToFramePadding()
      imgui::Text("eid {eid}")
      imgui::SameLine()
      if imgui::Button("Select##anomaly{eid}")
        editor_select_eid(eid)
  if first
    imgui::Text("No linked darkness zones")


def draw_rect(c0, c1, c2, c3 : float3; color : E3DCOLOR)
  draw_cached_debug_line(c0, c1, color)
  draw_cached_debug_line(c1, c2, color)
  draw_cached_debug_line(c2, c3, color)
  draw_cached_debug_line(c0, c3, color)
  draw_cached_debug_line(c0, c2, color)
  draw_cached_debug_line(c1, c3, color)

def draw_side(transform : float3x4; x : float; color : E3DCOLOR)
  let corner0 = transform * float3(x, -0.5, -0.5)
  let corner1 = transform * float3(x, -0.5, 0.5)
  let corner2 = transform * float3(x, 0.5, 0.5)
  let corner3 = transform * float3(x, 0.5, -0.5)

  draw_rect(corner0, corner1, corner2, corner3, color)

def draw_anomaly(transform : float3x4; color : E3DCOLOR)
  draw_side(transform, -0.5, color)
  draw_side(transform, 0.5, color)

[es(tag=(render, dev), REQUIRE=(darknessAnomalySpot, daeditor__selected), no_order)]
def draw_selected_darkness_anomaly_spot(evt : UpdateStageInfoRenderDebug; eid : EntityId; transform : float3x4)
  begin_draw_cached_debug_lines(false, false, false)
  draw_anomaly(transform, E3DCOLOR(0xFF00FF00))
  let selectedEid = eid
  query() <| $ [es(REQUIRE=darknessAnomalySpot)] (eid : EntityId; transform : float3x4)
    if eid != selectedEid
      draw_anomaly(transform, E3DCOLOR(0xFFFFFF99))
  end_draw_cached_debug_lines()


[es(tag=(render, dev), REQUIRE=(darknessAnomaly, daeditor__selected), no_order)]
def draw_selected_darkness_anomaly(evt : UpdateStageInfoRenderDebug; transform : float3x4;
                                   darkness_anomaly__spotEid : EntityId)
  begin_draw_cached_debug_lines(false, false, false)
  draw_anomaly(transform, E3DCOLOR(0xFFFF0000))

  query(darkness_anomaly__spotEid) <| $ [es(REQUIRE=darknessAnomalySpot)] (transform : float3x4)
    draw_anomaly(transform, E3DCOLOR(0xFF00FF00))
  end_draw_cached_debug_lines()