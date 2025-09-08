options no_aot
require app
require ecs
require strings
require DagorSystem
require DagorConsole
require DagorEditor
require DagorFiles
require DagorDataBlock
require EcsUtils
require DngWalkerai


def tm_to_string(val : float3x4)
  return "[[{val[0]}] [{val[1]}] [{val[2]}] [{val[3]}]]"

def template_without_daeditor(eid : EntityId)
  return remove_sub_template_name(eid, "daeditor_selected")

def to_string_via_blk(compName : string; eid : EntityId)
  var data = ""
  using() <| $(var blk : DataBlock)
    let mgr & = getEntityManager()
    component_to_blk_param(compName, mgr |> getComponentRef(eid, compName), blk)
    data := string(blk)
  return data

[console_cmd(name="daEd4.selection_composite_tms", hint="<file>")]
def console_selected_composite_transforms(file : string = "")
  if !is_editor_activated()
    console_print("No entity is selected")
    return

  let firstSelectedEid = entity_object_editor_getFirstSelectedEntity()
  if firstSelectedEid == INVALID_ENTITY_ID
    console_print("No entity is selected")
    return

  query(firstSelectedEid) <| $ [es] (transform aka first_transform : float3x4)
    var results : table<uint; float3x4>
    query() <| $ [es(REQUIRE=daeditor__selected)] (eid aka other_eid : EntityId;
                                                   transform aka other_transform : float3x4)
      if other_eid == firstSelectedEid
        return

      let relativeTransform = inverse(first_transform) * other_transform
      results.insert(uint(other_eid), relativeTransform)
      console_print("{other_eid}<{template_without_daeditor(other_eid)}>: relative_tm={relativeTransform}")

    if file != ""
      df_open(file, DF_WRITE | DF_APPEND) <| $(outputFile)
        outputFile |> df_puts("{template_without_daeditor(firstSelectedEid)}: {tm_to_string(first_transform)}\n")
        for resultKey, resultValue in keys(results), values(results)
          outputFile |> df_puts("{template_without_daeditor(EntityId(resultKey))}: {tm_to_string(resultValue)}\n")
        outputFile |> df_puts("\n")



[console_cmd(name="am.selection_to_encounter_object")]
def console_selection_to_encounter_object()
  if !is_editor_activated()
    console_print("No entity is selected")
    return

  var firstSelectedEid = entity_object_editor_getFirstSelectedEntity()
  if firstSelectedEid == INVALID_ENTITY_ID
    console_print("No entity is selected")
    return

  var hasCursorTm = false
  query() <| $ [es(REQUIRE=(daeditor__selected, cursor_tm))] (eid : EntityId)
    if hasCursorTm
      console_print("Several cursors are selected. Results may be unpredictable.")
    firstSelectedEid = eid
    hasCursorTm = true

  query(firstSelectedEid) <| $ [es] (transform aka first_transform : float3x4)
    using() <| $(var blueprint : Array)
      query() <| $ [es(REQUIRE=daeditor__selected, REQUIRE_NOT=cursor_tm)] (eid : EntityId;
                                                                            transform aka other_transform : float3x4;
                                                                            navmesh_phys__atTime : float const?;
                                                                            walker_agent : EntityAgent const?;
                                                                            animchar__res : das_string const?;
                                                                            ri_extra__name : das_string const?)
        using() <| $(var instance : Object)
          instance |> set("templ", template_without_daeditor(eid))
          instance |> set("transform", inverse(first_transform) * other_transform)
          if navmesh_phys__atTime != null || walker_agent != null
            instance |> set("dropOnNavmesh", true)
          elif animchar__res != null || ri_extra__name != null
            instance |> set("dropOnNormal", true)
          blueprint |> push(instance)
      let objEid = createEntitySync("blank_array") <| $(init)
        init |> set("blank_array", blueprint)
      var result = to_string_via_blk("blank_array", objEid)
      result = result |> replace("blank_array:array", "interesting_encounter__blueprint:array")
      result = result |> replace("blank_array:object", "i:object")
      result = result |> replace("\n  ", "\n    ")
      set_clipboard_ansi_text(result)
      print(result)