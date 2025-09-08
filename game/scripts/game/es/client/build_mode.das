require ecs
require ecs.safe
require game.events.events_active_matter
require game.events.events_game
require DngCamera
require math.base
require DagorInput
require math
require DagorMath
require RendInst
require Dacoll
require game.es.client.build_mode_preview_common
require game.es.client.build_mode_grid_common
require game.es.client.build_mode_changes_common
require game.es.client.build_mode_common
require DagorDebug3D
require DagorDebug3DSolid
require DagorSystem
require CollRes
require DngCamera


def get_hero_camera_params(camera_eid : EntityId;
                           var position : float3&;
                           var offset_distance : float&;
                           var oXz_angle_degrees : float&;
                           var Oy_angle_degrees : float&)
  query(camera_eid) <| $ [es] (transform : float3x4)
    position = transform[3] + transform[2]
    offset_distance = 1.0f
    oXz_angle_degrees = rad_to_deg(atan2(transform[2].z, -transform[2].x))
    Oy_angle_degrees = rad_to_deg(safe_asin(-transform[2].y))


[es(REQUIRE=base_build_mode)]
def enter_build_mode(evt : CmdInputEnterBuildMode;
                     base_build_mode__cameraTemplate : string;
                     var base_build_mode__camera : EntityId&;
                     var base_build_mode__active : bool&;
                     var base_build_mode__activeGrid : EntityId&;
                     var base_build_mode__cameraToReturn : EntityId&)
  if base_build_mode__active
    return

  base_build_mode__active = true

  var heroPosition = float3(0.0)
  find_query() <| $ [es(REQUIRE=hero)] (transform : float3x4)
    heroPosition = transform[3]
    return true

  var closestGrid = INVALID_ENTITY_ID
  var closestGridDistance = -1.0
  var closestGridId = -1
  query() <| $ [es] (eid : EntityId; transform : float3x4; base_build_mode_grid__id : int)
    let distance = distance_sq(transform[3], heroPosition)
    if distance < closestGridDistance || closestGridDistance < 0.0
      closestGrid = eid
      closestGridDistance = distance
      closestGridId = base_build_mode_grid__id

  base_build_mode__activeGrid = closestGrid
  addSubTemplate(base_build_mode__activeGrid, "base_build_mode_active_grid")

  base_build_mode__cameraToReturn = get_cur_cam_entity()
  query(base_build_mode__cameraToReturn) <| $ [es] (var camera__active : bool&)
    camera__active = false

  var position : float3
  var offsetDistance : float
  var oXzAngleDegrees : float
  var OyAngleDegrees : float
  get_hero_camera_params(base_build_mode__cameraToReturn,
                         position, offsetDistance,
                         oXzAngleDegrees, OyAngleDegrees)
  base_build_mode__camera = createEntity(base_build_mode__cameraTemplate) <| $(var init)
    set(init, "camera__active", true)
    let snappedHeroPosition = get_snapped_point(base_build_mode__activeGrid, heroPosition, false)
    set(init, "build_mode_camera_target__position", snappedHeroPosition)
    set(init, "build_mode_camera_target__positionCurrent", position)
    set(init, "build_mode_camera_target__offsetDistanceCurrent", offsetDistance)
    set(init, "build_mode_camera_target__oXzAngleDegreesCurrent", oXzAngleDegrees)
    set(init, "build_mode_camera_target__OyAngleDegreesCurrent", OyAngleDegrees)

  activate_action_set(get_action_set_handle("Human"), false)
  activate_action_set(get_action_set_handle("HUDBase"), false)
  activate_action_set(get_action_set_handle("BuildMode"), true)
  query() <| $ [es(REQUIRE=construction_controller)] (eid : EntityId)
    create_preview_from_building(eid)
    hide_building(eid)


[es(REQUIRE=base_build_mode)]
def exit_build_mode(evt : CmdExitBuildMode;
                    eid aka build_mode_eid : EntityId;
                    base_build_mode__cameraToReturn : EntityId;
                    var base_build_mode__activeGrid : EntityId&;
                    var base_build_mode__activePreview : EntityId&;
                    var base_build_mode__camera : EntityId&;
                    var base_build_mode__active : bool&;
                    var base_build_mode__changes : Array;
                    var base_build_mode__unpoweredPreviews : EidList;
                    var base_build_mode__activeGizmo : EntityId&)
  if !base_build_mode__active
    return
  base_build_mode__active = false
  clear_build_mode_selection(base_build_mode__activePreview)

  clear(base_build_mode__unpoweredPreviews)
  removeSubTemplate(base_build_mode__activeGrid, "base_build_mode_active_grid")
  base_build_mode__activeGrid = INVALID_ENTITY_ID

  query(base_build_mode__camera) <| $ [es] (var build_mode_camera_target__position : float3&;
                                            var build_mode_camera_target__offsetDistance : float&;
                                            var build_mode_camera_target__oXzAngleDegrees : float&;
                                            var build_mode_camera_target__OyAngleDegrees : float&;
                                            var build_mode_camera_target__animationTimePassed : float&;
                                            var build_mode_camera_target__exitOnAnimationFinish : bool&)
    get_hero_camera_params(base_build_mode__cameraToReturn,
                           build_mode_camera_target__position,
                           build_mode_camera_target__offsetDistance,
                           build_mode_camera_target__oXzAngleDegrees,
                           build_mode_camera_target__OyAngleDegrees)
    build_mode_camera_target__animationTimePassed = 0.0f
    build_mode_camera_target__exitOnAnimationFinish = true

  base_build_mode__camera = INVALID_ENTITY_ID

  destroyEntity(base_build_mode__activeGizmo)
  base_build_mode__activeGizmo = INVALID_ENTITY_ID

  if evt.saveChanges
    // event is immediate, because exit build mode is in charge of
    // clearing all of the previews. And if previews are cleared, then
    // save_build_mode_changes system cannot calculate new power layout
    // for the base. Could be removed in the future, when each power
    // layout change is a separate undoable change
    sendEventImmediate(build_mode_eid, CmdBuildModeSaveChanges())

  clear(base_build_mode__changes)
  query() <| $ [es(REQUIRE=base_build_mode_controller_preview)] (eid : EntityId; construction_controller__gridId : int)
    if !has(eid, "baked_construction_controller")
      let grid = find_grid_by_id(construction_controller__gridId)
      free_grid(grid, eid)
    destroyEntity(eid)

  query() <| $ [es(REQUIRE=construction_controller, REQUIRE_NOT=base_build_mode_controller_preview)] (eid : EntityId)
    unhide_building(eid)


[es(on_disappear)]
def return_camera_on_exit(evt : Event;
                          var camera__active : bool&)
  camera__active = false

  find_query() <| $ [es(REQUIRE=base_build_mode)] (base_build_mode__cameraToReturn : EntityId)
    set_scene_camera_entity(base_build_mode__cameraToReturn)
    return true

  activate_action_set(get_action_set_handle("Human"), true)
  activate_action_set(get_action_set_handle("HUDBase"), true)
  activate_action_set(get_action_set_handle("BuildMode"), false)
  activate_action_set(get_action_set_handle("BuildModeDragging"), false)


def get_blueprint_by_id(id : string; all_items : Array)
  for itemComponent in all_items
    let itemObject = itemComponent |> get_ecs_object()
    if itemObject == null
      continue
    let itemId = (*itemObject).uniqueId ?? "0"
    if itemId == id
      return (*itemObject).template_name ?? ""
  return ""


[es]
def save_build_mode_changes(evt : CmdBuildModeSaveChanges;
                            eid : EntityId;
                            var base_build_mode__changes : Array)
  using() <| $(var obj : Object)
    query() <| $ [es(REQUIRE=base_build_mode_controller_preview)] (powered_controller__attachedTo : string;
                                                                   construction_controller__instanceId : string)
      obj |> set(construction_controller__instanceId, powered_controller__attachedTo)
    sendEvent(eid, CmdRequestChangeBasePower(basePower = ecs_addr(obj)))
  clear(base_build_mode__changes)


[es]
def update_active_buildings(evt : CmdUpdateActiveBuildings;
                            player_profile__activeBuildingsPositions : IPoint2List;
                            player_profile__activeBuildingsRotations : IntList;
                            player_profile__activeBuildingsGridIds : IntList;
                            player_profile__activeBuildingsIds : StringList;
                            player_profile__allItems : Array)
  // Remove any buildings that were taken away (including previews of already standing ones)
  query() <| $ [es(REQUIRE=construction_controller, REQUIRE_NOT=base_build_mode_controller_preview, REQUIRE_NOT=baked_construction_controller)] (eid : EntityId;
                                                                                                                                                 construction_controller__gridId : int;
                                                                                                                                                 construction_controller__instanceId aka actual_construction_controller__instanceId : string)
    let index = find_index_if(each(player_profile__activeBuildingsIds)) <| $(id)
      return id == construction_controller__instanceId
    // If this building is still deployed - skip
    if index != -1
      return
    // This building will be destroyed, but first we'll check for its active previews
    find_query() <| $ [es(REQUIRE=base_build_mode_controller_preview)] (eid aka preview_eid : EntityId; construction_controller__instanceId aka preview_construction_controller__instanceId : string)
      if preview_construction_controller__instanceId != actual_construction_controller__instanceId
        return false
      find_query() <| $ [es] (base_build_mode__isGizmoActive : bool)
        let isBeingDraggedByGizmo = base_build_mode__isGizmoActive && find_query() <| $ [es] (base_build_mode__gizmoPreview : EntityId)
          return base_build_mode__gizmoPreview == preview_eid
        if !isBeingDraggedByGizmo
          let grid = find_grid_by_id(construction_controller__gridId)
          free_grid(grid, preview_eid)
        return true
      destroyEntity(preview_eid)
      return true
    destroyEntity(eid)

  query() <| $ [es] (eid : EntityId; base_build_mode_grid__id : int)
    for i in range(length(player_profile__activeBuildingsPositions))
      assume buildPosition = player_profile__activeBuildingsPositions[i]
      assume buildRotation = player_profile__activeBuildingsRotations[i]
      assume buildGridId = player_profile__activeBuildingsGridIds[i]
      assume buildId = player_profile__activeBuildingsIds[i]
      if buildGridId != base_build_mode_grid__id
        continue
      let buildBlueprint = get_blueprint_by_id(string(buildId), player_profile__allItems)
      if buildBlueprint == ""
        logerr("Failed to find blueprint for builing with id {buildId}")
        continue
      var tm = calc_controller_transform_in_grid(eid, buildPosition, buildRotation, buildBlueprint)
      drop_construction(tm)
      // Check if there's already existing controller for this building. Previews are untouched
      let found = find_query() <| $ [es(REQUIRE_NOT=base_build_mode_controller_preview)] (construction_controller__instanceId : string;
                                                                                          var transform : float3x4&;
                                                                                          var construction_controller__gridId : int&)
        let isControllerRelevant = construction_controller__instanceId == buildId
        if isControllerRelevant
          transform = tm
          construction_controller__gridId = buildGridId
        return isControllerRelevant
      if !found
        // Sync creation is needed in case
        // if several CmdUpdateActiveBuildings would fire in one frame
        // then with async creation each controller would receive additional
        // copy for every request
        createEntitySync("construction_controller") <| $(init)
          set(init, "construction_controller__blueprint", buildBlueprint)
          set(init, "transform", tm)
          set(init, "construction_controller__instanceId", buildId)
          set(init, "construction_controller__gridId", buildGridId)


[es(REQUIRE=base_build_mode)]
def build_mode_trace_building(evt : EventUIMouseMoved;
                              eid aka build_mode_eid : EntityId;
                              base_build_mode__activeGizmo : EntityId;
                              base_build_mode__activeGrid : EntityId;
                              var base_build_mode__activePreview : EntityId&)
  var worldPoint : float3
  var worldDir : float3
  let screenPosition = float2(evt.screenX, evt.screenY)
  screen_to_world(screenPosition, worldPoint, worldDir)

  var tracedGizmo = false
  query(base_build_mode__activeGizmo) <| $ [es] (transform : float3x4)
    let gizmoDist = rayIntersectSphereDist(worldPoint, worldDir, transform[3], 1.0)
    tracedGizmo = gizmoDist > 0.0
    if tracedGizmo
      sendEvent(build_mode_eid, EventBuildModeGizmoStartDrag())
  if tracedGizmo
    return

  var distance = 1000.0
  var pmid = -1
  var norm : float3
  var riDesc = RendInstDesc()

  let previousActivePreview = base_build_mode__activePreview
  clear_build_mode_selection(base_build_mode__activePreview)
  var activeGridId = -1
  query(base_build_mode__activeGrid) <| $ [es] (base_build_mode_grid__id : int)
    activeGridId = base_build_mode_grid__id

  if traceray_normalized(worldPoint, worldDir, distance, pmid, norm, ETF_RI, riDesc, -1) && riDesc.isValid
    let handle = riDesc.riExtraHandle
    find_query() <| $ [es] (ri_extra : RiExtraComponent;
                            construction_part__controller : EntityId)
      if ri_extra.handle != handle
        return false
      // Clicked on the selected building -> deselect it(do nothing)
      if previousActivePreview != construction_part__controller
        // Clicked on existing preview
        query(construction_part__controller) <| $ [es(REQUIRE=base_build_mode_controller_preview)] (construction_controller__gridId : int)
          if construction_controller__gridId != activeGridId
            return
          base_build_mode__activePreview = construction_part__controller
          make_preview_active(base_build_mode__activePreview)
      return true
  else
    find_query() <| $ [es] (construction_part__controller : EntityId;
                            collres : CollisionResource;
                            transform : float3x4)
      if construction_part__controller == previousActivePreview
        return false
      var shouldTrace = false
      query(construction_part__controller) <| $ [es(REQUIRE=base_build_mode_controller_preview)] (construction_controller__gridId : int)
        shouldTrace = construction_controller__gridId == activeGridId
      if shouldTrace && collres_rayhit(collres, transform, null, worldPoint, worldDir, distance)
        base_build_mode__activePreview = construction_part__controller
        make_preview_active(base_build_mode__activePreview)
        return true
      return false


[es]
def deploy_building_from_stash(evt : CmdDeployBuildingPreviewFromStash;
                               var base_build_mode__changes : Array&;
                               var base_build_mode__activePreview : EntityId&)
  clear_build_mode_selection(base_build_mode__activePreview)
  let grid = find_grid_by_id(evt.gridId)
  let transform = calc_controller_transform_in_grid(grid,
                                                    evt.position,
                                                    evt.rotation,
                                                    evt.blueprintName)
  base_build_mode__activePreview = create_preview_from_stash(evt.blueprintName, transform, evt.uniqueId, evt.gridId)
  if base_build_mode__activePreview != INVALID_ENTITY_ID && evt.recordChange
    record_unstash_change(evt.uniqueId,
                          grid,
                          evt.gridId,
                          transform,
                          evt.blueprintName,
                          base_build_mode__changes)


[es(REQUIRE=base_build_mode)]
def unstash_building_before_camera(evt : CmdDeployBuildingPreviewBeforeCamera;
                                   eid : EntityId;
                                   base_build_mode__camera : EntityId;
                                   base_build_mode__activeGrid : EntityId)
  let previewExists = find_query() <| $ [es(REQUIRE=base_build_mode_controller_preview)] (construction_controller__instanceId : string)
    return construction_controller__instanceId == evt.uniqueId
  if previewExists
    return

  query(base_build_mode__camera) <| $ [es] (build_mode_camera_target__position : float3)
    query(base_build_mode__activeGrid) <| $ [es] (transform aka grid_transform : float3x4; base_build_mode_grid__id : int)
      var desiredTransform = grid_transform
      desiredTransform[3] = build_mode_camera_target__position
      var rotation = 0
      var position = int2(0)
      let blueprintName = get_blueprint_from_unique_id(evt.uniqueId)
      calc_controller_position_and_rotation_in_grid(base_build_mode__activeGrid,
                                                    desiredTransform,
                                                    blueprintName,
                                                    rotation,
                                                    position)
      sendEvent(eid, CmdDeployBuildingPreviewFromStash(
        uniqueId = evt.uniqueId,
        position = position,
        rotation = rotation,
        gridId = base_build_mode_grid__id,
        blueprintName = blueprintName,
        recordChange = true
      ))


[es]
def move_build_mode_camera_to_selection(evt : CmdMoveCameraToSelection;
                                        base_build_mode__activePreview : EntityId;
                                        base_build_mode__camera : EntityId)
  query(base_build_mode__camera) <| $ [es] (var build_mode_camera_target__position : float3&;
                                            var build_mode_camera_target__animationTimePassed : float&)
    query(base_build_mode__activePreview) <| $ [es] (transform : float3x4)
      build_mode_camera_target__position = transform[3]
      build_mode_camera_target__animationTimePassed = 0.0f


[es(REQUIRE=base_build_mode_controller_preview, REQUIRE_NOT=baked_construction_controller, on_appear, before=init_build_controller)]
def init_construction_controller_preview(evt : Event;
                                         eid : EntityId; construction_controller__blueprint : string;
                                         construction_controller__instanceId : string;
                                         construction_controller__gridId : int;
                                         transform : float3x4)
  find_query() <| $ [es(REQUIRE=base_build_mode)] (base_build_mode__activePreview : EntityId;
                                                   var base_build_mode__changes : Array)
    var grid = INVALID_ENTITY_ID
    find_query() <| $ [es] (eid aka grid_eid : EntityId; base_build_mode_grid__id : int)
      if base_build_mode_grid__id != construction_controller__gridId
        return false
      grid = eid
      return true
    let beforeTm := transform
    let placeAvailable = safely_snap_construction_controller_to_grid(grid, eid)
    if !placeAvailable
      // TODO: move to stash
      logerr("[BUILD MODE] no free space to place {construction_controller__blueprint}")

    var beforeRotation = 0
    var beforePosition = int2()
    calc_controller_position_and_rotation_in_grid(grid,
                                                  beforeTm,
                                                  construction_controller__blueprint,
                                                  beforeRotation,
                                                  beforePosition)
    var afterRotation = 0
    var afterPosition = int2()
    calc_controller_position_and_rotation_in_grid(grid,
                                                  transform,
                                                  construction_controller__blueprint,
                                                  afterRotation,
                                                  afterPosition)
    if beforePosition != afterPosition || beforeRotation != afterRotation
      // If last change is "unstash this building" -> change unstash location to the new one
      // otherwise record move change
      let len = length(base_build_mode__changes)
      var changedUnstash = false
      if len > 0
        assume last = base_build_mode__changes[len - 1] as Object
        assume relevantChange = get_string(last, "type", "") == "unstash"
        assume releventId = get_string(last, "construction_id", "0") == construction_controller__instanceId
        if relevantChange && releventId
          using() <| $(var to : Object)
            set(to, "move", afterPosition)
            set(to, "rotate", afterRotation)
            set(to, "gridId", construction_controller__gridId)
            set(*last, "to", to)
            changedUnstash = true
      if !changedUnstash
        record_move_change(construction_controller__instanceId,
                          grid,
                          construction_controller__gridId,
                          beforeTm,
                          grid,
                          construction_controller__gridId,
                          transform,
                          construction_controller__blueprint,
                          base_build_mode__changes)
    if eid == base_build_mode__activePreview
      make_preview_active(eid)
    return true


[es(on_appear, on_event=EventLevelLoaded)]
def init_build_mode_grid(evt : Event;
                         eid : EntityId;
                         base_build_mode_grid__dimentions : int2;
                         base_build_mode_grid__blockedAreas : Array;
                         var ui__node_pos : float3&;
                         var base_build_mode_grid__cells : EidList)
  resize(base_build_mode_grid__cells, base_build_mode_grid__dimentions.x * base_build_mode_grid__dimentions.y)
  for blockedArea in base_build_mode_grid__blockedAreas
    let obj = get_ecs_object(blockedArea)
    let shape = obj.shape ?? ""
    if shape == "rectangle"
      let start = obj.start ?? int2(-1)
      let end = obj.end ?? int2(-1)
      occupy_grid(eid, start, end, eid)
    else
      logerr("unknown blocked shape \"{shape}\"")

  let center = get_grid_center(eid)
  ui__node_pos += center


[es(no_order, REQUIRE=base_build_mode_active_grid)]
def build_mode_draw_grid(info : UpdateStageInfoAct;
                         transform : float3x4;
                         base_build_mode_grid__dimentions : int2;
                         base_build_mode_grid__step : float;
                         base_build_mode_grid__yDrawOffset : float)
  let start = transform[3] + float3(0., base_build_mode_grid__yDrawOffset, 0.)
  assume forward = transform[2]
  assume right = transform[0]

  assume dims = base_build_mode_grid__dimentions
  assume step = base_build_mode_grid__step
  for i in range(dims.x + 1)
    let delta = float(i) * step
    let near = start + right * delta
    let far = near + forward * float(dims.y) * step
    draw_debug_line_buffered(near, far, E3DCOLOR(0xFF00FF00), 1)

  for i in range(dims.y + 1)
    let delta = float(i) * step
    let left = start + forward * delta
    let r = left + right * float(dims.x) * step
    draw_debug_line_buffered(left, r, E3DCOLOR(0xFF00FF00), 1)


[es(no_order, REQUIRE=base_build_mode_active_grid)]
def build_mode_draw_unbuildable_grid(info : UpdateStageInfoAct;
                                     eid aka grid_eid : EntityId;
                                     transform : float3x4;
                                     base_build_mode_grid__dimentions : int2;
                                     base_build_mode_grid__yDrawOffset : float;
                                     base_build_mode_grid__step : float;
                                     base_build_mode_grid__cells : EidList)
  for i, occupant in iter_range(base_build_mode_grid__cells), base_build_mode_grid__cells
    if occupant == INVALID_ENTITY_ID
      continue
    let x = i / base_build_mode_grid__dimentions.y
    let y = i % base_build_mode_grid__dimentions.y
    let drawPos = get_grid_coordinates_by_row_column(grid_eid, int2(x, y), true) + float3(0., base_build_mode_grid__yDrawOffset, 0.)
    let boxDimentions = float3(base_build_mode_grid__step, 0.1, base_build_mode_grid__step) * 0.9
    let box = BBox3(-boxDimentions / 2.0, boxDimentions / 2.0)
    var boxTm = transform
    boxTm[3] = drawPos
    let color = occupant == grid_eid ? E3DCOLOR(0xaacc0000) : E3DCOLOR(0xaa666666)
    draw_debug_cube_buffered(box, boxTm, color, 1)


[es]
def move_selected_to_stash(evt : CmdStashCurrentBuilding;
                           eid : EntityId;
                           base_build_mode__activeGrid : EntityId;
                           base_build_mode__isGizmoActive : bool;
                           var base_build_mode__changes : Array;
                           var base_build_mode__activePreview : EntityId&)
  if base_build_mode__activePreview == INVALID_ENTITY_ID
    return

  if !base_build_mode__isGizmoActive
    free_grid(base_build_mode__activeGrid, base_build_mode__activePreview)
  query(base_build_mode__activePreview) <| $ [es] (transform : float3x4;
                                                   construction_controller__instanceId : string;
                                                   construction_controller__blueprint : string)
    sendEvent(eid, CmdMovePreviewToStash(uniqueId = construction_controller__instanceId))
    using() <| $(var change : Object)
      set(change, "type", "stash")
      set(change, "construction_id", construction_controller__instanceId)
      using() <| $(var from : Object)
        var rotation = 0
        var position = int2()
        calc_controller_position_and_rotation_in_grid(base_build_mode__activeGrid,
                                                      transform,
                                                      construction_controller__blueprint,
                                                      rotation,
                                                      position)
        set(from, "move", position)
        set(from, "rotate", rotation)
        query(base_build_mode__activeGrid) <| $ [es] (base_build_mode_grid__id : int)
          set(from, "gridId", base_build_mode_grid__id)
        set(change, "from", from)
      push(base_build_mode__changes, change)
  destroyEntity(base_build_mode__activePreview)
  clear_build_mode_selection(base_build_mode__activePreview)


[es]
def build_mode_undo(evt : CmdBuildModeUndo;
                    eid : EntityId;
                    var base_build_mode__changes : Array)
  let lastIndex = length(base_build_mode__changes) - 1
  if lastIndex < 0
    return
  let lastChange = get_ecs_object(base_build_mode__changes[lastIndex])
  if lastChange == null
    return
  if lastChange == null
    logerr("Invalid change: cannot get as object")
    return
  let changeType = get_string(lastChange, "type", "")
  if changeType == "move"
    undo_move_change(*lastChange)
  elif changeType == "stash"
    undo_stash_change(*lastChange, eid)
  elif changeType == "unstash"
    undo_unstash_change(*lastChange, eid)
  else
    logerr("cannot undo change: of type (\"{changeType}\")")
  erase(base_build_mode__changes, lastIndex)


[es]
def change_active_grid(evt : CmdChangeActiveBuildGrid;
                       base_build_mode__camera : EntityId;
                       var base_build_mode__activePreview : EntityId&;
                       var base_build_mode__activeGrid : EntityId&)
  clear_build_mode_selection(base_build_mode__activePreview)
  removeSubTemplate(base_build_mode__activeGrid, "base_build_mode_active_grid")
  base_build_mode__activeGrid = evt.gridEid
  addSubTemplate(base_build_mode__activeGrid, "base_build_mode_active_grid")
  query(base_build_mode__camera) <| $ [es] (var build_mode_camera_target__position : float3&;
                                            var build_mode_camera_target__animationTimePassed : float&)
    let center = get_grid_center(base_build_mode__activeGrid)
    build_mode_camera_target__position = center
    build_mode_camera_target__animationTimePassed = 0.0f