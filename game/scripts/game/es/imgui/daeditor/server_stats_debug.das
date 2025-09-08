options no_aot

require ecs
require app
require DagorMath
require DagorImgui
require DagorConsole
require DagorDebug3DSolid
require DagorEditor
require DagorSystem
require danetlibs.imgui_daeditor.daEditor.daEditor_common
require imgui/imgui_boost
require daslib/strings_boost
require daslib/static_let
require daslib/safe_addr


[imgui_window(name="Server Stats", group="Debug")]
def server_stats_window()
  if IsWindowCollapsed()
    return

  let found = find_query() <| $ [es] (server_stats_controller__fps : float;
                                      server_stats_controller__dtMinMaxAvg : float3)
    let fpsText = fmt(":.1f", server_stats_controller__fps)
    let dtMinText = fmt(":.1f", server_stats_controller__dtMinMaxAvg.x * 1000.0)
    let dtMaxText = fmt(":.1f", server_stats_controller__dtMinMaxAvg.y * 1000.0)
    let dtAvgText = fmt(":.1f", server_stats_controller__dtMinMaxAvg.z * 1000.0)

    var fpsColor = IM_COL32(255, 255, 255, 255)
    if server_stats_controller__fps <= 12.0
      fpsColor = IM_COL32(0, 0, 255, 255)
    elif server_stats_controller__fps <= 24.0
      fpsColor = IM_COL32(0, 160, 255, 255)

    imgui::PushStyleColor(imgui::ImGuiCol.Text, fpsColor)
    imgui::Text("FPS: {fpsText} ({dtMinText}<{dtMaxText} {dtAvgText})")
    imgui::PopStyleColor()
    return true

  if !found
    imgui::Text("server_stats_controller is not found!")
