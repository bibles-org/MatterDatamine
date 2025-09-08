require ecs
require danetlibs.imgui_daeditor.imgui.daEditor.ecs_inspectors_common
require danetlibs.imgui_daeditor.imgui.daEditor.ecs_inspectors_macro
require imgui
require daslib/safe_addr
require Action
require daslib/static_let


[ecs_inspector(type_name="EntityActionsTab")]
def draw_BehaviourTree(eid : array<EntityId> implicit; flags : uint; name : string; refs : array<ComponentRenderInfo#>#; level : int; var changed : bool?; sub_menu : block<(var changed : bool?) : bool>) : void
  var val = unsafe(reinterpret<EntityActionsTab?> refs[0].rawData)
  assume ac = *val

  static_let <|
    var show = false

  imgui::Text("{length(ac)} actions")
  imgui::SameLine()
  imgui::Checkbox("Show##name", safe_addr(show))

  if !show
    return

  let names = fixed_array(
    "stateIdx",
    "actionDefTime",
    "timer",
    "actionTime",
    "applyAtDef",
    "applyAt",
    "prevRel",
    "actionPeriod",
    "overridePropsId",
    "interpDelayTicks",
    "propsId",
    "varId",
    "blocksSprint",
    "name",
    "classHash"
  )

  for action in ac
    imgui::TableNextRow()
    imgui::TableSetColumnIndex(0)
    imgui::AlignTextToFramePadding()
    imgui::Text("    {action.name}")
    imgui::TableSetColumnIndex(1)
    if imgui::BeginTable("{action.name}", 2, ImGuiTableFlags.BordersOuter | ImGuiTableFlags.RowBg)
      TableSetupColumn("param", ImGuiTableColumnFlags WidthFixed)
      TableSetupColumn("value", ImGuiTableColumnFlags WidthFixed)
      TableHeadersRow()

      let vals = fixed_array(
        "{action.stateIdx}",
        "{action.actionDefTime}",
        "{action.timer}",
        "{action.actionTime}",
        "{action.applyAtDef}",
        "{action.applyAt}",
        "{action.prevRel}",
        "{action.actionPeriod}",
        "{action.overridePropsId}",
        "{action.interpDelayTicks}",
        "{action.propsId}",
        "{action.varId}",
        "{action.blocksSprint}",
        "{action.name}",
        "{action.classHash}"
      )

      for name_text, value_text in names, vals
        imgui::TableNextRow()
        imgui::TableNextColumn()
        imgui::Text(name_text)
        imgui::TableNextColumn()
        imgui::Text(value_text)

      imgui::EndTable()

