require ecs
require math.base
require imgui
require pathfinder
require DagorImgui
require DagorConsole
require DagorMath
require Dacoll
require DagorDebug3D
require DagorSystem
require DagorEditor
require active_matter.game.es.imgui.daEditor.poi_validation_common
require imgui/imgui_boost
require danetlibs.imgui_daeditor.daEditor.daEditor_common

let WARN_TOO_LONG_AT = 3.0

struct NavData
  eid : EntityId
  poiEid : EntityId
  isValid : bool
  pos : float3
  navPos : float3
  inaccessible : bool
  isLong : bool

[imgui_window(name="Bind navmesh pos", group = "AM")]
def bind_navmesh_pos_window()
  if IsWindowCollapsed()
    return

  var inProgress = false
  let count = get_valid_poi_count()
  find_query() <| $ [es] (poi_validator__poiIndex : int; poi_validator__poiEids : EidList)
    let progress = int(100.0 * safediv(float(poi_validator__poiIndex), float(length(poi_validator__poiEids))))
    imgui::Text("{progress}% {(count.total - count.invalid)} / {count.total}")
    inProgress = true
    return true

  if inProgress
    return

  var bindingsTotal = 0
  var zeroBindings = 0
  var longBindings = 0
  var inaccessible = 0
  let bindingsLongLengthSq = square(WARN_TOO_LONG_AT)
  let zero = float3()
  query() <| $ [es] (nav_binding__navMeshPos : float3; nav_binding__inaccessible : bool; transform : float3x4)
    bindingsTotal++
    if nav_binding__inaccessible
      inaccessible++
    elif nav_binding__navMeshPos == zero
      zeroBindings++
    elif distance_sq(transform[3], nav_binding__navMeshPos) > bindingsLongLengthSq
      longBindings++

  var cursorPos = float3()
  find_query() <| $ [es] (camera__active : bool; transform : float3x4)
    if camera__active
      var traceDir : float3 = transform[2]
      var t = 200.0
      var norm : float3
      let up = float3(0.0, 1.0, 0.0)
      if dot(up, traceDir) < 0.99
        //move the cursor closer to the bottom side of the screen. More convenient this way.
        let axis = normalize(cross(up, traceDir))
        let q = quat(axis, 0.15)
        traceDir = q * traceDir
      traceray_normalized(transform[3], traceDir, t, norm)
      cursorPos = transform[3] + traceDir * (t - 0.1)
      draw_debug_sphere_buffered(cursorPos, 0.25, E3DCOLOR(0xFFFFFF80), 24, 1)
      draw_debug_sphere_buffered(cursorPos, 0.3, E3DCOLOR(0xFFFFFF80), 24, 1)
      draw_debug_line_buffered(cursorPos, cursorPos + float3(0.0, 5.0, 0.0), E3DCOLOR(0xFFFFFF80), 1)
      find_query() <| $ [es(REQUIRE=(daeditor__selected, nav_binding__navMeshPos))] (transform : float3x4)
        let humanHeight = 1.8
        let useDistance = 3.0
        let dst = distance(transform[3], cursorPos + float3(0.0, humanHeight, 0.0))
        if dst < 10.0
          let accessible = dst > useDistance
          let color = accessible ? E3DCOLOR(0xFFFF0000) : E3DCOLOR(0xFFFFFF80)
          draw_debug_sphere_buffered(cursorPos, 0.25, color, 24, 1)
          let useFrom = cursorPos + float3(0.0, humanHeight, 0.0)
          let dir = normalize(transform[3] - useFrom)
          draw_debug_line_buffered(useFrom, useFrom + dir * min(useDistance, dst), color, 1)
        return true

    return camera__active

  imgui::BeginGroup()

  if imgui::Button("Delete and recalculate ALL##nav_binding")
    rebuild_all_bindings()
  imgui::Text("Bindings total:{bindingsTotal}")
  imgui::Text("Uninitialized:{zeroBindings}")
  imgui::Text("Inaccessible:{inaccessible}")
  imgui::Text("Bindings over {WARN_TOO_LONG_AT} meters away:{longBindings}")
  if imgui::Button("Validate existing bindings##nav_binding")
    validate_existing_bindings()

  imgui::EndGroup()

  imgui::SameLine()
  imgui::BeginGroup()
  if imgui::Button("Toggle navmesh draw##nav_binding")
    console_command("app.debug_navmesh")
  find_query() <| $ [es(REQUIRE=(daeditor__selected, nav_binding__navMeshPos))] (eid : EntityId)
    let selectedEid = eid
    find_query() <| $ [es] (eid, poi__eid : EntityId; poi__pos : float3;
                            poi__inaccessible, poi__isValid : bool; poi__navPos : Point3List)
      if poi__eid == selectedEid
        imgui::NewLine()
        imgui::Text("Selected:")
        let navPos = length(poi__navPos) > 0 ? poi__navPos[0] : float3()
        create_poi_view(eid, poi__eid, poi__isValid, poi__pos, navPos, poi__inaccessible, cursorPos, "nav_binging_single")
      return poi__eid == selectedEid
    return true
  imgui::EndGroup()

  if count.total > 0
    var navData : array<NavData>
    query() <| $ [es] (poi__eid, eid : EntityId;
                       poi__isValid : bool;
                       poi__pos : float3;
                       poi__navPos : Point3List;
                       poi__inaccessible : bool)
      query(poi__eid) <| $ [es] (transform : float3x4)
        let navPos = length(poi__navPos) > 0 ? poi__navPos[0] : float3()
        let isLong = poi__isValid && distance_sq(transform[3], navPos) > bindingsLongLengthSq
        emplace(navData, NavData(eid = eid, poiEid = poi__eid, isValid = poi__isValid,
            pos = poi__pos, navPos = navPos, inaccessible = poi__inaccessible, isLong = isLong))
    sort(navData) <| $(a; b)
      return uint(a.poiEid) < uint(b.poiEid)
    imgui::NewLine()
    if imgui::Button("Assign all valid bindings##nav_bindings")
      assign_valid_bindings()
    if imgui::Button("Assign all and save poi##nav_bindings")
      //No info as to where to save. So each type needs its own button with a hardcoded save location
      assign_valid_bindings()
      save_poi_to_file()
    imgui::NewLine()

    imgui::BeginGroup()
    imgui::Text("{count.invalid} INVALID:")
    imgui::NewLine()
    for datum in navData
      if !datum.isValid && !datum.inaccessible
        imgui::NewLine()
        create_poi_view(datum.eid, datum.poiEid, datum.isValid, datum.pos, datum.navPos, datum.inaccessible, cursorPos, "nav_binging_INVALID")
    imgui::EndGroup()

    imgui::SameLine()
    imgui::BeginGroup()
    imgui::Text("{count.total - count.invalid} VALID:")
    imgui::NewLine()
    for datum in navData
      if datum.isValid
        imgui::NewLine()
        create_poi_view(datum.eid, datum.poiEid, datum.isValid, datum.pos, datum.navPos, datum.inaccessible, cursorPos, "nav_binging_VALID")
    imgui::EndGroup()

    imgui::SameLine()
    imgui::BeginGroup()
    imgui::Text("inaccessable:")
    imgui::NewLine()
    for datum in navData
      if datum.inaccessible
        imgui::NewLine()
        create_poi_view(datum.eid, datum.poiEid, datum.isValid, datum.pos, datum.navPos, datum.inaccessible, cursorPos, "nav_binging_inaccessable")
    imgui::EndGroup()

    imgui::SameLine()
    imgui::BeginGroup()
    imgui::Text("VALID but long:")
    imgui::NewLine()
    for datum in navData
      if datum.isLong
        imgui::NewLine()
        create_poi_view(datum.eid, datum.poiEid, datum.isValid, datum.pos, datum.navPos, datum.inaccessible, cursorPos, "nav_binging_long")
    imgui::EndGroup()


    find_query() <| $ [es(REQUIRE=(daeditor__selected, nav_binding__navMeshPos))] (eid : EntityId; transform : float3x4)
      find_query() <| $ [es] (poi__eid : EntityId; poi__pos : float3; var poi__navPos : Point3List; poi__isValid : bool)
        if poi__eid == eid
          draw_debug_sphere_buffered(transform[3], 1.25, E3DCOLOR(0xFFFFFF00), 12, 1)
          if transform[3] != poi__pos
            draw_debug_sphere_buffered(poi__pos, 0.75, E3DCOLOR(0xFFFFFF00), 12, 1)
          let color = poi__isValid ? E3DCOLOR(0xFF00FF00) : E3DCOLOR(0xFFFF0000)
          for p in poi__navPos
            draw_debug_sphere_buffered(p, 0.08, color, 12, 1)
          if poi__isValid
            draw_debug_line_buffered(transform[3], poi__navPos[0], E3DCOLOR(0xFF00FF00), 1)
        return poi__eid == eid
      return true

def create_poi_view(eid : EntityId; poi_eid : EntityId; is_valid : bool; pos : float3; nav_pos : float3;
                    inaccessible : bool; cursor_pos : float3; suffix : string)
  imgui::Text("{poi_eid} <{getEntityTemplateName(poi_eid)}>:")
  if inaccessible
    imgui::Text("(inaccessible)")
  if imgui::Button("Zoom##{poi_eid}{suffix}")
    editor_open()
    editor_select_eid(poi_eid)
    entity_object_editor_zoomAndCenter()
  if imgui::Button("Rebuild from cursor pos##{poi_eid}{suffix}")
    validate_single_poi(poi_eid, cursor_pos)
  else
    imgui::Text("add a cursor to edit")
  if imgui::Button("Toggle \"inaccessible\"##{poi_eid}{suffix}")
    query(eid) <| $ [es] (var poi__inaccessible : bool&)
      poi__inaccessible = !inaccessible
    query(poi_eid) <| $ [es] (var nav_binding__inaccessible : bool&)
      nav_binding__inaccessible = !inaccessible
      entity_obj_editor_saveComponent(poi_eid, "nav_binding.inaccessible")
  if is_valid
    imgui::Text("Dist: {distance(nav_pos, pos)}")


def get_valid_poi_count() : tuple<total : int; invalid : int>
  var result : tuple<total : int; invalid : int>
  query() <| $ [es] (poi__isValid : bool; poi__inaccessible : bool)
    result.total++
    if !poi__isValid && !poi__inaccessible
      result.invalid++
  return <- result