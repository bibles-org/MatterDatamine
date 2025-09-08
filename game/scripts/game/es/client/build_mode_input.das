require ecs
require DagorInput
require game.events.input_events
require game.events.events_active_matter
require game.events.events
require math.base
require DagorMath
require DagorSystem
require DagorDebug3DSolid
require game.es.client.build_mode_preview_common
require game.es.client.build_mode_grid_common


[es(tag=input, on_appear)]
def human_build_mode_input_appear(evt : Event; var human_input__buildModeEnter : int&)
  human_input__buildModeEnter = int(get_action_handle("BuildMode.Enter", TYPEGRP_DIGITAL))


[es(tag=input)]
def human_build_mode_input_init(evt : EventDaInputInit; var human_input__buildModeEnter : int&)
  if evt.init
    human_input__buildModeEnter = int(get_action_handle("BuildMode.Enter", TYPEGRP_DIGITAL))
  else
    human_input__buildModeEnter = int(BAD_ACTION_HANDLE)


def init_build_mode_input(var build_mode_input__buildModeExit : uint16&;
                          var build_mode_input__moveGizmo : uint16&;
                          var build_mode_input__enableGizmoMove : uint16&;
                          var build_mode_input__rotateBuildingRight : uint16&;
                          var build_mode_input__rotateBuildingLeft : uint16&;
                          var build_mode_input__showBriefing : uint16&;
                          var build_mode_input__moveToStash : uint16&;
                          var build_mode_input__undo : uint16&;
                          var build_mode_drag_input__rotateBuildingRight : uint16&;
                          var build_mode_drag_input__rotateBuildingLeft : uint16&;
                          var build_mode_input__enterMarket : uint16&)
  build_mode_input__buildModeExit = get_action_handle("BuildMode.Exit", TYPEGRP_DIGITAL)
  build_mode_input__moveGizmo = get_action_handle("BuildMode.MoveGizmo", TYPEGRP_STICK)
  build_mode_input__enableGizmoMove = get_action_handle("BuildMode.EnableGizmoMove", TYPEGRP_DIGITAL)
  build_mode_input__rotateBuildingRight = get_action_handle("BuildMode.RotateBuildingRight", TYPEGRP_DIGITAL)
  build_mode_input__rotateBuildingLeft = get_action_handle("BuildMode.RotateBuildingLeft", TYPEGRP_DIGITAL)
  build_mode_input__showBriefing = get_action_handle("BuildMode.Briefing", TYPEGRP_DIGITAL)
  build_mode_input__moveToStash = get_action_handle("BuildMode.MoveToStash", TYPEGRP_DIGITAL)
  build_mode_input__undo = get_action_handle("BuildMode.Undo", TYPEGRP_DIGITAL)
  build_mode_drag_input__rotateBuildingRight = get_action_handle("BuildModeDragging.RotateBuildingRight", TYPEGRP_DIGITAL)
  build_mode_drag_input__rotateBuildingLeft = get_action_handle("BuildModeDragging.RotateBuildingLeft", TYPEGRP_DIGITAL)
  build_mode_input__enterMarket = get_action_handle("BuildMode.EnterMarket", TYPEGRP_DIGITAL)

def reset_build_mode_input(var build_mode_input__buildModeExit : uint16&;
                           var build_mode_input__moveGizmo : uint16&;
                           var build_mode_input__enableGizmoMove : uint16&;
                           var build_mode_input__rotateBuildingRight : uint16&;
                           var build_mode_input__rotateBuildingLeft : uint16&;
                           var build_mode_input__showBriefing : uint16&;
                           var build_mode_input__moveToStash : uint16&;
                           var build_mode_input__undo : uint16&;
                           var build_mode_drag_input__rotateBuildingRight : uint16&;
                           var build_mode_drag_input__rotateBuildingLeft : uint16&;
                           var build_mode_input__enterMarket : uint16&)
  build_mode_input__buildModeExit = BAD_ACTION_HANDLE
  build_mode_input__moveGizmo = BAD_ACTION_HANDLE
  build_mode_input__enableGizmoMove = BAD_ACTION_HANDLE
  build_mode_input__rotateBuildingRight = BAD_ACTION_HANDLE
  build_mode_input__rotateBuildingLeft = BAD_ACTION_HANDLE
  build_mode_input__showBriefing = BAD_ACTION_HANDLE
  build_mode_input__moveToStash = BAD_ACTION_HANDLE
  build_mode_input__undo = BAD_ACTION_HANDLE
  build_mode_drag_input__rotateBuildingRight = BAD_ACTION_HANDLE
  build_mode_drag_input__rotateBuildingLeft = BAD_ACTION_HANDLE
  build_mode_input__enterMarket = BAD_ACTION_HANDLE


[es(tag=input, on_appear, on_event=EventLevelLoaded)]
def build_mode_input_on_appear(evt : Event;
                               var build_mode_input__buildModeExit : uint16&;
                               var build_mode_input__moveGizmo : uint16&;
                               var build_mode_input__enableGizmoMove : uint16&;
                               var build_mode_input__rotateBuildingRight : uint16&;
                               var build_mode_input__rotateBuildingLeft : uint16&;
                               var build_mode_input__showBriefing : uint16&;
                               var build_mode_input__moveToStash : uint16&;
                               var build_mode_input__undo : uint16&;
                               var build_mode_drag_input__rotateBuildingRight : uint16&;
                               var build_mode_drag_input__rotateBuildingLeft : uint16&;
                               var build_mode_input__enterMarket : uint16&)
  init_build_mode_input(build_mode_input__buildModeExit,
                        build_mode_input__moveGizmo,
                        build_mode_input__enableGizmoMove,
                        build_mode_input__rotateBuildingRight,
                        build_mode_input__rotateBuildingLeft,
                        build_mode_input__showBriefing,
                        build_mode_input__moveToStash,
                        build_mode_input__undo,
                        build_mode_drag_input__rotateBuildingRight,
                        build_mode_drag_input__rotateBuildingLeft,
                        build_mode_input__enterMarket)


[es(tag=input)]
def build_mode_input_on_init(evt : EventDaInputInit;
                             var build_mode_input__buildModeExit : uint16&;
                             var build_mode_input__moveGizmo : uint16&;
                             var build_mode_input__enableGizmoMove : uint16&;
                             var build_mode_input__rotateBuildingRight : uint16&;
                             var build_mode_input__rotateBuildingLeft : uint16&;
                             var build_mode_input__showBriefing : uint16&;
                             var build_mode_input__moveToStash : uint16&;
                             var build_mode_input__undo : uint16&;
                             var build_mode_drag_input__rotateBuildingRight : uint16&;
                             var build_mode_drag_input__rotateBuildingLeft : uint16&;
                             var build_mode_input__enterMarket : uint16&)
  if evt.init
    init_build_mode_input(build_mode_input__buildModeExit,
                          build_mode_input__moveGizmo,
                          build_mode_input__enableGizmoMove,
                          build_mode_input__rotateBuildingRight,
                          build_mode_input__rotateBuildingLeft,
                          build_mode_input__showBriefing,
                          build_mode_input__moveToStash,
                          build_mode_input__undo,
                          build_mode_drag_input__rotateBuildingRight,
                          build_mode_drag_input__rotateBuildingLeft,
                          build_mode_input__enterMarket)
  else
    reset_build_mode_input(build_mode_input__buildModeExit,
                          build_mode_input__moveGizmo,
                          build_mode_input__enableGizmoMove,
                          build_mode_input__rotateBuildingRight,
                          build_mode_input__rotateBuildingLeft,
                          build_mode_input__showBriefing,
                          build_mode_input__moveToStash,
                          build_mode_input__undo,
                          build_mode_drag_input__rotateBuildingRight,
                          build_mode_drag_input__rotateBuildingLeft,
                          build_mode_input__enterMarket)


[es(tag=input, REQUIRE=hero)]
def human_enter_build_mode(evt : EventDaInputActionTriggered;
                           input__enabled : bool;
                           human_input__buildModeEnter : int)
  if input__enabled && int(evt.action) == human_input__buildModeEnter
    broadcastEvent(CmdInputEnterBuildMode())


[es(tag=input, REQUIRE=base_build_mode)]
def build_mode_move_to_stash(evt : EventDaInputActionTriggered;
                             eid : EntityId;
                             input__enabled : bool;
                             build_mode_input__moveToStash : uint16)
  if input__enabled && evt.action == build_mode_input__moveToStash
    sendEvent(eid, CmdStashCurrentBuilding())


[es(tag=input, REQUIRE=base_build_mode)]
def build_mode_input_undo(evt : EventDaInputActionTriggered;
                          eid : EntityId;
                          input__enabled : bool;
                          build_mode_input__undo : uint16)
  if input__enabled && evt.action == build_mode_input__undo
    sendEvent(eid, CmdBuildModeUndo())


[es(tag=input, REQUIRE=base_build_mode)]
def build_mode_open_market(evt : EventDaInputActionTriggered;
                           input__enabled : bool;
                           build_mode_input__enterMarket : uint16)
  if input__enabled && evt.action == build_mode_input__enterMarket
    // broadcastEvent([[ CmdShowEnlistMenu menuName="marketScreen" ]])
    logerr("`CmdShowEnlistMenu` was removed, and there is no working build mode right now. Please, remove this code or replace it with something else.")


[es(tag=input, REQUIRE=base_build_mode)]
def build_mode_exit_build_mode(evt : EventDaInputActionTriggered;
                               input__enabled : bool;
                               build_mode_input__buildModeExit : uint16)
  if input__enabled && evt.action == build_mode_input__buildModeExit
    broadcastEvent(CmdInputExitBuildMode())


[es(tag=input)]
def build_mode_show_briefing(evt : EventDaInputActionTriggered;
                             eid : EntityId;
                             input__enabled : bool;
                             build_mode_input__showBriefing : uint16)
  if input__enabled && evt.action == build_mode_input__showBriefing
    sendEvent(eid, CmdShowBuildModeBriefing())


[es(tag=input, REQUIRE=base_build_mode)]
def build_mode_rotate_building(evt : EventDaInputActionTriggered;
                               base_build_mode__constructionRotationStep : float;
                               input__enabled : bool;
                               base_build_mode__activePreview : EntityId;
                               base_build_mode__isGizmoActive : bool;
                               build_mode_input__rotateBuildingRight : uint16;
                               build_mode_input__rotateBuildingLeft : uint16;
                               build_mode_drag_input__rotateBuildingRight : uint16;
                               build_mode_drag_input__rotateBuildingLeft : uint16)
  if (!input__enabled
      || base_build_mode__activePreview == INVALID_ENTITY_ID
      || !base_build_mode__isGizmoActive)
    return
  var angleDelta = 0.0
  if evt.action == build_mode_input__rotateBuildingRight || evt.action == build_mode_drag_input__rotateBuildingRight
    angleDelta = -1.0
  elif evt.action == build_mode_input__rotateBuildingLeft || evt.action == build_mode_drag_input__rotateBuildingLeft
    angleDelta = 1.0
  if angleDelta == 0.0
    return

  query(base_build_mode__activePreview) <| $ [es] (var transform : float3x4&)
    var rotation = IDENT_TM
    rotyTM(deg_to_rad(angleDelta * base_build_mode__constructionRotationStep), rotation)
    transform = transform * rotation


[es(track=base_build_mode__isGizmoActive)]
def activate_build_mode_drag_action_set(evt : Event;
                                        base_build_mode__isGizmoActive : bool)
  activate_action_set(get_action_set_handle("BuildModeDragging"), base_build_mode__isGizmoActive)


[es]
def build_mode_on_gizmo_start_drag(evt : EventBuildModeGizmoStartDrag;
                                   base_build_mode__activePreview : EntityId;
                                   base_build_mode__activeGrid : EntityId;
                                   var base_build_mode__isGizmoLocked : bool&)
  base_build_mode__isGizmoLocked = false

  var start = int2(-1)
  var size = int2(-1)
  get_controller_grid_footprint(base_build_mode__activeGrid, base_build_mode__activePreview, start, size)
  free_grid(base_build_mode__activeGrid, start, size)
  query(base_build_mode__activePreview) <| $ [es] (transform : float3x4;
                                                   var base_build_mode_preview__previousTransform : float3x4&)
    base_build_mode_preview__previousTransform = transform


[es(tag=input)]
def build_mode_move_preview_with_gizmo(input : UpdateStageUpdateInput;
                                       base_build_mode__activePreview : EntityId;
                                       base_build_mode__camera : EntityId;
                                       build_mode_input__moveGizmo : uint16;
                                       build_mode_input__enableGizmoMove : uint16;
                                       base_build_mode__activeGrid : EntityId;
                                       var base_build_mode__isGizmoLocked : bool&;
                                       var base_build_mode__isGizmoActive : bool&)
  if base_build_mode__isGizmoLocked
    return
  let wasActive = base_build_mode__isGizmoActive
  base_build_mode__isGizmoActive = get_digital_action_state(build_mode_input__enableGizmoMove).bState
  base_build_mode__isGizmoLocked = wasActive && !base_build_mode__isGizmoActive
  if !base_build_mode__isGizmoActive
    return
  let move = get_analog_stick_action_state(build_mode_input__moveGizmo)
  query(base_build_mode__camera) <| $ [es] (transform aka camera_transform : float3x4;
                                            build_mode_camera_target__minMaxOffsetDistance : float2;
                                            build_mode_camera_target__offsetDistance : float)
    var worldTransform = float3x3()
    worldTransform[0] = camera_transform[0]
    worldTransform[1] = float3(0.0, 1.0, 0.0)
    worldTransform[2] = normalize(x0z(camera_transform[2]))
    let offsetRange = build_mode_camera_target__minMaxOffsetDistance.y - build_mode_camera_target__minMaxOffsetDistance.x
    let usedOffset = build_mode_camera_target__offsetDistance - build_mode_camera_target__minMaxOffsetDistance.x
    let offsetRatio = usedOffset / offsetRange
    let translationMultiplier = 1.0 + offsetRatio
    let translationWorld = worldTransform * float3(move.x, 0.0, move.y) * translationMultiplier
    query(base_build_mode__activePreview) <| $ [es] (construction_controller__blueprint : string;
                                                     var transform aka preview_transform : float3x4&)
      move_preview(translationWorld, base_build_mode__activeGrid, transform)
      // Draw preview of the location where building would be snapped if gizmo was released
      query(base_build_mode__activeGrid) <| $ [es] (transform aka grid_transform : float3x4;
                                                    base_build_mode_grid__step : float;
                                                    base_build_mode_grid__yDrawOffset : float)
        let blueprint = getTemplateByName(construction_controller__blueprint)
        if blueprint == null
          return
        let gridDimentions = get_IPoint2(getTemplateComponent(*blueprint, "blueprint_base__gridSize", ecs_hash("blueprint_base__gridSize")))
        if gridDimentions == null
          return
        let dims = *gridDimentions
        let snappedCenter = get_snapped_controller_coords(base_build_mode__activeGrid, dims, preview_transform)
        var boxTm = preview_transform
        boxTm[3] = snappedCenter
        boxTm[3].y = grid_transform[3].y + base_build_mode_grid__yDrawOffset
        let footprintSize = float3(float(dims.x), 0.0, float(dims.y)) * base_build_mode_grid__step
        let box = BBox3(-footprintSize / 2.0, footprintSize / 2.0 + float3(0.0, 0.1, 0.0))
        let color = can_controller_occupy_grid(base_build_mode__activeGrid, base_build_mode__activePreview) ? E3DCOLOR(0xffffff00) : E3DCOLOR(0xffff0000)
        draw_debug_cube_buffered(box, boxTm, color, 1)
