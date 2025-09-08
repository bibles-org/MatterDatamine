options no_aot

require ecs
require imgui
require danetlibs.imgui_daeditor.imgui.daEditor.ecs_inspectors_macro
require danetlibs.imgui_daeditor.daEditor.daEditor_common
require game.es.client.build_mode_grid_common
require game.es.client.build_mode_power_common
require game.es.client.build_mode_preview_common
require game.es.client.build_mode_common
require math.base


[ecs_editor(tags=construction_controller, prefix=true)]
def build_mode_construction_menu(selected_eid : array<EntityId> const#)
  assert(length(selected_eid) == 1)
  let eid = selected_eid[0]
  query(eid) <| $ [es] (transform aka controller_transform : float3x4)
    let isPreview = has(eid, "base_build_mode_controller_preview")
    imgui::Text("Is preview: {isPreview}")
    find_query() <| $ [es] (base_build_mode__activeGrid : EntityId)
      assume grid = base_build_mode__activeGrid
      query(grid) <| $ [es] (transform aka grid_transform : float3x4)
        if !is_point_in_grid(grid, controller_transform[3])
          imgui::Text("Construction is not in grid")
          return
        var footprintStart : int2
        var footprintSize : int2
        get_controller_grid_footprint(grid, eid, footprintStart, footprintSize)
        imgui::Text("Construction grid footprint: ({footprintStart}) - ({footprintStart + footprintSize})")
        let rotationInGrid = get_rotation_in_grid(controller_transform, grid_transform)
        imgui::Text("Construction rotation in grid: {rad_to_deg(rotationInGrid)}")
      return true

[ecs_editor(tags=powered_controller__attachedTo, prefix=true)]
def build_mode_powered_construction_menu(selected_eid : array<EntityId> const#)
  assert(length(selected_eid) == 1)
  let eid = selected_eid[0]
  query(eid) <| $ [es] (powered_controller__attachedTo : string)
    if powered_controller__attachedTo == "0"
      imgui::Text("Power needed")
      return
    let stationController = find_preview_by_id(powered_controller__attachedTo)
    let station = get_construction_power_station(stationController)
    imgui::Text("Powered by {station} (controller: {stationController})")
