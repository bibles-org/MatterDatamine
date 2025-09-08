module build_mode_changes_common shared

require ecs
require ecs.safe
require math.base
require game.events.events_active_matter
require game.es.client.build_mode_common
require game.es.client.build_mode_grid_common
require game.es.client.build_mode_preview_common
require DagorSystem


def apply_move_change(change : Object; build_mode_eid : EntityId)
  let to = get_ecs_object(change, "to")
  if to == null
    logerr("Invalid move change: cannot get \"to\" as object")
    return
  sendEvent(build_mode_eid, CmdRequestMoveBuilding(
    id = get_int64(change, "construction_id") ?? 0l,
    move = get_IPoint2(to, "move") ?? int2(),
    rotate = get_int(to, "rotate") ?? 0,
    grid = get_int(to, "gridId") ?? 0
  ))


def undo_move_change(change : Object)
  let from = get_ecs_object(change, "from")
  if from == null
    logerr("Invalid move change: cannot get \"from\" as an object")
    return
  let id = get_string(change, "construction_id", "0")
  let move = get_IPoint2(from, "move") ?? int2()
  let rotate = get_int(from, "rotate") ?? 0
  let gridId = get_int(from, "gridId") ?? 0
  let preview = find_preview_by_id(id)
  let grid = find_grid_by_id(gridId)

  free_grid(grid, preview)
  query(preview) <| $ [es] (construction_controller__blueprint : string; var transform : float3x4&)
    transform = calc_controller_transform_in_grid(grid, move, rotate, construction_controller__blueprint)
  controller_occupy_grid(grid, preview)


def record_move_change(id : string;
                       from_grid : EntityId;
                       from_grid_id : int;
                       from_transform : float3x4;
                       to_grid : EntityId;
                       to_grid_id : int;
                       to_transform : float3x4;
                       blueprint : string;
                       var changes : Array)
  using() <| $(var change : Object)
    set(change, "type", "move")
    set(change, "construction_id", id)
    using() <| $(var from : Object)
      var rotation = 0
      var position = int2()
      calc_controller_position_and_rotation_in_grid(from_grid,
                                                    from_transform,
                                                    blueprint,
                                                    rotation,
                                                    position)
      set(from, "move", position)
      set(from, "rotate", rotation)
      set(from, "gridId", from_grid_id)
      set(change, "from", from)
    using() <| $(var to : Object)
      var rotation = 0
      var position = int2()
      calc_controller_position_and_rotation_in_grid(to_grid,
                                                    to_transform,
                                                    blueprint,
                                                    rotation,
                                                    position)
      set(to, "move", position)
      set(to, "rotate", rotation)
      set(to, "gridId", to_grid_id)
      set(change, "to", to)
    push(changes, change)


def apply_stash_change(change : Object; build_mode_eid : EntityId)
  sendEvent(build_mode_eid, CmdRequestStashBuilding(
    id = get_int64(change, "construction_id") ?? 0l
  ))


def undo_stash_change(change : Object; build_mode_eid : EntityId)
  let from = get_ecs_object(change, "from")
  if from == null
    logerr("Invalid stash change: cannot get \"from\" as an object")
    return
  let id = get_string(change, "construction_id", "0")
  let move = get_IPoint2(from, "move") ?? int2()
  let rotate = get_int(from, "rotate") ?? 0
  let gridId = get_int(from, "gridId") ?? 0
  let blueprintName = get_blueprint_from_unique_id(id)
  sendEvent(build_mode_eid, CmdDeployBuildingPreviewFromStash(
    uniqueId = id,
    position = move,
    rotation = rotate,
    gridId = gridId,
    blueprintName = blueprintName,
    recordChange = false
  ))


def apply_unstash_change(change : Object; build_mode_eid : EntityId)
  let to = get_ecs_object(change, "to")
  if to == null
    logerr("Invalid unstash change: cannot get \"to\" as object")
    return
  sendEvent(build_mode_eid, CmdRequestUnstashBuilding(
    uniqueId = get_int64(change, "construction_id") ?? 0l,
    move = get_IPoint2(to, "move") ?? int2(),
    rotate = get_int(to, "rotate") ?? 0,
    grid = get_int(to, "gridId") ?? 0
  ))


def undo_unstash_change(change : Object; build_mode_eid : EntityId)
  let id = get_string(change, "construction_id", "0")
  let to = get_ecs_object(change, "to")
  if to == null
    logerr("Invalid unstash change: cannot get \"to\" as an object")
    return
  let grid = find_grid_by_id(get_int(to, "gridId") ?? 0)
  let preview = find_preview_by_id(id)
  if preview == INVALID_ENTITY_ID
    logerr("Undo unstash: cannot find preview to stash")
    return
  query(build_mode_eid) <| $ [es] (base_build_mode__isGizmoActive : bool;
                                   var base_build_mode__activePreview : EntityId&)
    if !base_build_mode__isGizmoActive
      free_grid(grid, preview)
    if preview == base_build_mode__activePreview
      clear_build_mode_selection(base_build_mode__activePreview)
  destroyEntity(preview)
  sendEvent(build_mode_eid, CmdMovePreviewToStash(uniqueId = id))


def record_unstash_change(unique_id : string;
                          grid : EntityId;
                          grid_id : int;
                          preview_transform : float3x4;
                          blueprint : string;
                          var changes : Array)
  using() <| $(var change : Object)
    set(change, "type", "unstash")
    set(change, "construction_id", unique_id)
    using() <| $(var to : Object)
      var move = int2()
      var rotation = 0
      calc_controller_position_and_rotation_in_grid(grid,
                                                    preview_transform,
                                                    blueprint,
                                                    rotation,
                                                    move)
      set(to, "move", move)
      set(to, "rotate", rotation)
      set(to, "gridId", grid_id)
      set(change, "to", to)
    push(changes, change)