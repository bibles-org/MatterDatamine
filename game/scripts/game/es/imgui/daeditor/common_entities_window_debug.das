options no_aot
require ecs
require imgui
require DagorImgui
require DagorEditor
require danetlibs.imgui_daeditor.daEditor.daEditor_common
require danetlibs.imgui_daeditor.imgui.daEditor.ecs_inspector_common


def entity_button(name : string; eid : EntityId)
  let templateName = getEntityTemplateName(eid)

  if imgui::Button("{name} ({eid})")
    if eid != INVALID_ENTITY_ID
      entity_object_editor_updateObjectsList()
      editor_select_eid(eid, true)
      imgui_window_set_visible("Editor", "Inspector", true)

  if IsItemHovered()
    BeginTooltip()
    TextUnformatted(eid != INVALID_ENTITY_ID ? templateName : "None")
    EndTooltip()

  imgui::SameLine()
  if imgui::Button(" * ##{templateName}")
    imgui::OpenPopup("template_menu_{templateName}")

  if imgui::BeginPopup("template_menu_{templateName}")
    for i in range(1, 4)
      if imgui::Button("Inspector #{i+1}##{i+1}")
        imgui::CloseCurrentPopup()
        open_inspector(i, eid, "")

    if imgui::Button("Copy eid")
      imgui::CloseCurrentPopup()
      imgui::SetClipboardText("{eid}")

    imgui::EndPopup()


[imgui_window(name="Common Entities", group="Editor")]
def editor_common_entities_debug_window()

  init_entity_object_editor()

  query <| $ [es(REQUIRE=localPlayer)] (eid : EntityId)
    entity_button("Local Player", eid)

  query() <| $ [es] (eid : EntityId;
                     camera__active : bool)
    if camera__active
      entity_button("Active Camera", eid)

  query() <| $ [es(REQUIRE=watchedByPlr)] (eid : EntityId;
                                           human_use_object__selectedObject : EntityId = INVALID_ENTITY_ID;
                                           human_weap__currentGunEid : EntityId = INVALID_ENTITY_ID;
                                           human_anim__vehicleSelected : EntityId = INVALID_ENTITY_ID)
    imgui::Text("Watched Hero:")
    entity_button("Hero", eid)
    entity_button("Current Gun", human_weap__currentGunEid)
    query(human_weap__currentGunEid) <| $ [es] (grenade_thrower__projectileEntity : EntityId)
      entity_button("Grenade", grenade_thrower__projectileEntity)
    entity_button("Vehicle", human_anim__vehicleSelected)
    entity_button("Use Object", human_use_object__selectedObject)

