require ecs
require BehNodes
require DagorDataBlock
require danetlibs.imgui_daeditor.imgui.daEditor.ecs_inspector_common
require danetlibs.imgui_daeditor.imgui.daEditor.ecs_inspectors_common
require danetlibs.imgui_daeditor.imgui.daEditor.ecs_inspectors_macro
require imgui
require strings
require walkerai
require daslib/defer
require DagorMath
require DagorDebug3D


[ecs_inspector(type_name="BehaviourTree")]
def draw_BehaviourTree(eid : array<EntityId> implicit; flags : uint; name : string; refs : array<ComponentRenderInfo#>#; level : int; var changed : bool?; sub_menu : block<(var changed : bool?) : bool>) : void
  var val = unsafe(reinterpret<BehaviourTree ??> refs[0].rawData)
  assume behTree = **val
  imgui::AlignTextToFramePadding()
  imgui::Text("{behTree.root.name}")
  imgui::SameLine()
  if imgui::Button("blackboard")
    print("{eid}: beh tree {behTree.root.name} blackboard:")
    print(behTree.blackBoard |> string())
  imgui::SameLine()
  if imgui::Button("reset")
    beh_tree_reset(behTree)
  default_menu(eid, name, "BehaviourTree", changed, sub_menu)


[ecs_inspector(type_name="ai::AgentDangers")]
def draw_AgentDangers(eid : array<EntityId> implicit; flags : uint; name : string; refs : array<ComponentRenderInfo#>#; level : int; var changed : bool?; sub_menu : block<(var changed : bool?) : bool>) : void
  var val = unsafe(reinterpret<AgentDangers?> refs[0].rawData)
  assume dangers = (*val).dangers
  imgui::PushID(name)
  defer <|
    imgui::PopID()
  imgui::TableNextRow()
  imgui::TableSetColumnIndex(0)
  imgui::AlignTextToFramePadding()

  let len = length(dangers)
  let isEmpty = len == 0
  var open = false
  let fullName = level == 0 ? item_flags(flags, name) : name
  if isEmpty && level == 0
    imgui::Text(fullName)
    imgui_hint(name)
  else
    let treeflags = isEmpty ? ImGuiTreeNodeFlags.Leaf | ImGuiTreeNodeFlags.NoTreePushOnOpen | ImGuiTreeNodeFlags.Bullet : ImGuiTreeNodeFlags.None
    open = TreeNodeEx(fullName, treeflags)
    imgui_hint(name)
  imgui::TableSetColumnIndex(1)

  if !isEmpty
    imgui::SameLine()
    imgui::Text("{typeinfo typename(type<AgentDangers>)} size: {len}")
  else
    imgui::SameLine()
    imgui::Text("<empty>")
    return

  if open
    var idx = -1
    while ++idx < length(dangers)
      assume d = dangers[idx]
      let key = "[{d.eid}]"
      imgui::PushID(key)

      imgui::TableNextRow()
      imgui::TableSetColumnIndex(1)

      imgui::BeginTable(key, 4, ImGuiTableFlags.Resizable | ImGuiTableFlags.BordersOuter | ImGuiTableFlags.RowBg)
      imgui::TableNextRow()

      imgui::TableSetColumnIndex(0)
      imgui::AlignTextToFramePadding()
      imgui::Text("eid: {d.eid}")
      imgui::TableSetColumnIndex(1)
      imgui::Text("dst: {d.distance:.1f}")
      imgui::TableSetColumnIndex(2)
      imgui::Text("alert: {d.alertness:.2f}")
      imgui::TableSetColumnIndex(3)
      imgui::Text("trace:{d.traceable ? "+" : "-"}")
      imgui::TableNextRow()

      imgui::TableSetColumnIndex(0)
      imgui::AlignTextToFramePadding()
      imgui::Text("noise:{d.noiseMeter:.1f}")
      imgui::TableSetColumnIndex(1)
      imgui::Text("meter:{d.dangerMeter:.1f}")
      imgui::TableSetColumnIndex(2)
      imgui::Text("lastT:{d.lastTime:.1f}")
      imgui::TableSetColumnIndex(3)
      imgui::Text("frustumT:{d.inFrustumTime:.1f}")

      imgui::EndTable()

      imgui_hint <| $
        draw_arrow_to_target(eid[0], d.eid, 1)
        return getEntityTemplateName(d.eid)
      default_menu(eid, name, "Danger", changed) <| $ [unused_argument(sub_changed)] (sub_changed)
        if imgui::Button("show me")
          imgui::CloseCurrentPopup()
          draw_arrow_to_target(eid[0], d.eid, 1000)
        return sub_menu |> invoke(changed)

      imgui::PopID()

    imgui::TreePop()

def draw_arrow_to_target(from_eid, to_eid : EntityId; duration : int)
  query(from_eid) <| $ [es] (transform aka s_transform : float3x4)
    query(to_eid) <| $ [es] (transform aka a_transform : float3x4)
      draw_debug_arrow_buffered(s_transform[3] + s_transform[1], a_transform[3] + a_transform[1], E3DCOLOR(0xffffff00), duration)
