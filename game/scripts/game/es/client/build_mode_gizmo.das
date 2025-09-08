require ecs
require DagorMath
require game.es.client.build_mode_grid_common
require game.es.client.build_mode_changes_common
require DagorDebug3D


[es(no_order)]
def base_build_mode_gizmo(info : UpdateStageInfoAct;
                          base_build_mode__gizmoPreview : EntityId;
                          base_build_mode__gizmoHeightOffset : float;
                          var transform aka gizmo_transform : float3x4&)
  query(base_build_mode__gizmoPreview) <| $ [es] (transform aka preview_transform : float3x4;
                                                  construction_controller__bboxMax : float3)
    let offset = float3(0.0, construction_controller__bboxMax.y + base_build_mode__gizmoHeightOffset, 0.0)
    gizmo_transform[3] = preview_transform[3] + offset
    draw_debug_line_buffered(gizmo_transform[3], preview_transform[3], E3DCOLOR(0xFFFF0000), 1)


[es(track=base_build_mode__activePreview)]
def update_build_mode_gizmo(evt : Event;
                            base_build_mode__activePreview : EntityId;
                            var base_build_mode__activeGizmo : EntityId&)
  destroyEntity(base_build_mode__activeGizmo)
  base_build_mode__activeGizmo = INVALID_ENTITY_ID
  if base_build_mode__activePreview != INVALID_ENTITY_ID
    base_build_mode__activeGizmo = createEntity("base_build_mode_gizmo") <| $(init)
      set(init, "base_build_mode__gizmoPreview", base_build_mode__activePreview)


[es(track=base_build_mode__isGizmoActive)]
def stop_drag_preview(evt : Event;
                      base_build_mode__isGizmoActive : bool;
                      base_build_mode__activeGizmo : EntityId;
                      base_build_mode__activeGrid : EntityId;
                      var base_build_mode__changes : Array)
  if base_build_mode__isGizmoActive
    return
  query(base_build_mode__activeGizmo) <| $ [es] (base_build_mode__gizmoPreview : EntityId)
    if can_controller_occupy_grid(base_build_mode__activeGrid, base_build_mode__gizmoPreview)
      snap_construction_controller_to_grid(base_build_mode__activeGrid, base_build_mode__gizmoPreview)
      query(base_build_mode__activeGrid) <| $ [es] (base_build_mode_grid__id : int)
        query(base_build_mode__gizmoPreview) <| $ [es] (construction_controller__instanceId : string;
                                                        base_build_mode_preview__previousTransform : float3x4;
                                                        construction_controller__blueprint : string;
                                                        transform : float3x4)
          record_move_change(construction_controller__instanceId,
                             base_build_mode__activeGrid,
                             base_build_mode_grid__id,
                             base_build_mode_preview__previousTransform,
                             base_build_mode__activeGrid,
                             base_build_mode_grid__id,
                             transform,
                             construction_controller__blueprint,
                             base_build_mode__changes)
    else
      query(base_build_mode__gizmoPreview) <| $ [es] (base_build_mode_preview__previousTransform : float3x4;
                                                      var transform aka preview_transform : float3x4&)
        preview_transform = base_build_mode_preview__previousTransform
        controller_occupy_grid(base_build_mode__activeGrid, base_build_mode__gizmoPreview)
