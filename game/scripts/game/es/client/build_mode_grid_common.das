module build_mode_grid_common shared

require ecs
require math
require math.base
require DagorMath
require DagorSystem


def get_forward_angle_from_transform(transform : float3x4)
  return atan2(transform[0][2], transform[0][0])


def get_rotation_in_grid(transform : float3x4; grid_transform : float3x4)
  return get_forward_angle_from_transform(transform) - get_forward_angle_from_transform(grid_transform)


def is_point_in_grid(grid : EntityId; point : float3)
  var result = false
  query(grid) <| $ [es] (transform : float3x4;
                         base_build_mode_grid__dimentions : int2;
                         base_build_mode_grid__step : float)
    let localPoint = inverse(transform) * point
    assume dims = base_build_mode_grid__dimentions
    assume step = base_build_mode_grid__step
    result = localPoint.x > 0.0 && localPoint.z > 0.0 && localPoint.x < float(dims.x) * step && localPoint.z < float(dims.y) * step
  return result


def get_grid_projected_intersection_point(grid : EntityId; point : float3)
  var result = int2(-1)
  query(grid) <| $ [es] (transform : float3x4;
                         base_build_mode_grid__dimentions : int2;
                         base_build_mode_grid__step : float)
    let localPoint = inverse(transform) * point
    let coords = roundi(localPoint / base_build_mode_grid__step)
    result = int2(coords.x, coords.z)
    result.x = clamp(result.x, 0, base_build_mode_grid__dimentions.x)
    result.y = clamp(result.y, 0, base_build_mode_grid__dimentions.y)
  return result


def get_grid_coordinates_by_row_column(grid : EntityId; row_column : int2; center_coords : bool)
  var result = float3()
  query(grid) <| $ [es] (transform : float3x4;
                         base_build_mode_grid__step : float)
    var localPoint = float3(float(row_column.x), 0.0, float(row_column.y)) * base_build_mode_grid__step
    if center_coords
      localPoint += x0z(float3(base_build_mode_grid__step / 2.0))
    result = transform * localPoint
  return result


def get_snapped_point(grid : EntityId; point : float3; snap_to_cell_center : bool)
  let rowColumn = get_grid_projected_intersection_point(grid, point)
  return get_grid_coordinates_by_row_column(grid, rowColumn, snap_to_cell_center)


// returns angle in range [0, 2PI)
def normalize_radians_angle(angle : float)
  let reminder = floor(abs(angle) / (2.0 * PI)) * sign(angle)
  var fixedAngle = angle - reminder * (2.0 * PI)
  if fixedAngle < 0.0
    fixedAngle += 2.0 * PI
  return fixedAngle


def is_footprint_rotated(controller_transform : float3x4; grid_transform : float3x4)
  let angleInGrid = normalize_radians_angle(get_rotation_in_grid(controller_transform, grid_transform))
  // If construction is rotated 90 or -90 degrees
  // it's dimentions are swapped (works for rectangle grid footprints)
  // contruction can only be rotated 0, 90, -90 or 180 degrees
  return abs(abs(angleInGrid - PI) - PI / 2.0) < PI / 10.0


def get_blueprint_dims(blueprint_name : string)
  let blueprint = getTemplateByName(blueprint_name)
  if blueprint == null
    logerr("[BUILD MODE]: blueprint \"{blueprint_name}\" is not a valid template")
    return int2(-1)
  let controllerGridDims = get_IPoint2(getTemplateComponent(*blueprint, "blueprint_base__gridSize", ecs_hash("blueprint_base__gridSize")))
  if controllerGridDims == null
    logerr("[BUILD MODE]: blueprint doesn't have gird size")
    return int2(-1)
  return *controllerGridDims


def get_controller_grid_footprint(grid : EntityId;
                                  controller : EntityId;
                                  var footprint_start : int2&;
                                  var footprint_size : int2&)
  query(controller) <| $ [es] (transform aka controller_transform : float3x4; construction_controller__blueprint : string)
    query(grid) <| $ [es] (transform aka grid_transform : float3x4; base_build_mode_grid__step : float)
      var controllerDims = get_blueprint_dims(construction_controller__blueprint)
      if is_footprint_rotated(controller_transform, grid_transform)
        swap(controllerDims.x, controllerDims.y)
      let topLeftCorner = controller_transform[3] - float3x3(grid_transform) * float3(float(controllerDims.x), 0.0, float(controllerDims.y)) * base_build_mode_grid__step / 2.0
      let rowColumn = get_grid_projected_intersection_point(grid, topLeftCorner)
      footprint_start = rowColumn
      footprint_size = controllerDims


def occupy_grid(grid : EntityId;
                start : int2;
                end : int2;
                occupant : EntityId)
  var cell = start
  query(grid) <| $ [es] (base_build_mode_grid__dimentions : int2;
                         var base_build_mode_grid__cells : EidList)
    while cell.x < end.x
      while cell.y < end.y
        let index = cell.x * base_build_mode_grid__dimentions.y + cell.y
        assume current = base_build_mode_grid__cells[index]
        if current == INVALID_ENTITY_ID || current == occupant
          current = occupant
        cell.y += 1
      cell.x += 1
      cell.y = start.y


def controller_occupy_grid(grid : EntityId; controller : EntityId)
  var footprintStart = int2(-1)
  var footprintSize = int2(-1)
  get_controller_grid_footprint(grid, controller, footprintStart, footprintSize)
  if footprintSize.x < 0 || footprintSize.y < 0
    logerr("[BUILD MODE] controller {controller} doesn't have a footprint")
    return
  let footprintEnd = footprintStart + footprintSize
  occupy_grid(grid, footprintStart, footprintEnd, controller)


def free_grid(grid : EntityId; start : int2; footprint_size : int2)
  if footprint_size.x < 0 || footprint_size.y < 0
    logerr("[BUILD MODE] passed negative footprint size to free_grid")
    return
  var cell = start
  let end = start + footprint_size
  query(grid) <| $ [es] (base_build_mode_grid__dimentions : int2;
                         var base_build_mode_grid__cells : EidList)
    while cell.x < end.x
      while cell.y < end.y
        let index = cell.x * base_build_mode_grid__dimentions.y + cell.y
        assume current = base_build_mode_grid__cells[index]
        current = INVALID_ENTITY_ID
        cell.y += 1
      cell.x += 1
      cell.y = start.y


def free_grid(grid : EntityId; controller : EntityId)
  var footprintStart = int2(-1)
  var footprintSize = int2(-1)
  get_controller_grid_footprint(grid, controller, footprintStart, footprintSize)
  free_grid(grid, footprintStart, footprintSize)


def get_snapped_controller_coords(grid : EntityId;
                                  controller_grid_dims : int2;
                                  controller_transform : float3x4)
  var snappedPosition = controller_transform[3]
  query(grid) <| $ [es] (transform aka grid_transform : float3x4; base_build_mode_grid__step : float)
    var controllerGridSize = float2(controller_grid_dims) * base_build_mode_grid__step
    if is_footprint_rotated(controller_transform, grid_transform)
      swap(controllerGridSize.x, controllerGridSize.y)

    // Two corners are needed to properly snap construction that is out of the grid
    let corners = fixed_array(controllerGridSize / 2.0, -controllerGridSize / 2.0)
    for cornerOffset in corners
      let corner = snappedPosition - float3x3(grid_transform) * float3(cornerOffset.x, 0.0, cornerOffset.y)
      let snappedCorner = get_snapped_point(grid, corner, false)
      let diff = snappedCorner - corner
      snappedPosition += diff
  snappedPosition.y = controller_transform[3].y
  return snappedPosition


def is_footprint_in_grid(grid_dimentions : int2;
                         footprint_start : int2;
                         footprint_end : int2)
  return footprint_start.x >= 0 && footprint_start.y >= 0 && footprint_end.x <= grid_dimentions.x && footprint_end.y <= grid_dimentions.y

def is_footprint_available(grid_dimentions : int2;
                           grid_cells : EidList;
                           footprint_start : int2;
                           footprint_end : int2;
                           occupant : EntityId = INVALID_ENTITY_ID)
  var cell = footprint_start
  var footprintAvailable = true
  if !is_footprint_in_grid(grid_dimentions, footprint_start, footprint_end)
    return false
  while cell.x < footprint_end.x && footprintAvailable
    while cell.y < footprint_end.y
      let index = cell.x * grid_dimentions.y + cell.y
      assume current = grid_cells[index]
      footprintAvailable = current == INVALID_ENTITY_ID || current == occupant
      if !footprintAvailable
        break
      cell.y += 1
    cell.x += 1
    cell.y = footprint_start.y
  return footprintAvailable


def can_controller_occupy_grid(grid : EntityId; controller : EntityId)
  var footprintStart = int2(-1)
  var footprintSize = int2(-1)
  get_controller_grid_footprint(grid, controller, footprintStart, footprintSize)
  let footprintEnd = footprintStart + footprintSize
  var available = false
  query(grid) <| $ [es] (base_build_mode_grid__dimentions : int2;
                         base_build_mode_grid__cells : EidList)
    available = is_footprint_available(base_build_mode_grid__dimentions,
                                       base_build_mode_grid__cells,
                                       footprintStart,
                                       footprintEnd,
                                       controller)
  return available


let allowedControllerRotations = fixed_array<float>(0.0, PI / 2.0, PI, PI * 1.5)


def get_snapped_controller_angle_index(grid_transform : float3x4;
                                       controller_transform : float3x4)
  let angleInGrid = get_rotation_in_grid(controller_transform, grid_transform)
  let fixedAngle = normalize_radians_angle(angleInGrid)
  var angleIndex = 0
  var closestDiff = abs(allowedControllerRotations[angleIndex] - angleInGrid)
  for i, angle in iter_range(allowedControllerRotations), allowedControllerRotations
    let currentDiff = abs(angle - fixedAngle)
    if closestDiff > currentDiff
      closestDiff = currentDiff
      angleIndex = i
  return angleIndex


def get_in_grid_rotation_by_index(index : int)
  return allowedControllerRotations[index]


def get_snapped_controller_rotation(grid_transform : float3x4;
                                    controller_transform : float3x4)
  let angleIndex = get_snapped_controller_angle_index(grid_transform, controller_transform)
  let closestAngle = get_in_grid_rotation_by_index(angleIndex)
  var rotation = IDENT_TM
  rotyTM(closestAngle, rotation)
  return grid_transform * rotation


def try_find_free_space(grid : EntityId;
                        grid_dimentions : int2;
                        grid_cells : EidList;
                        controller : EntityId;
                        var controller_transform : float3x4)
  if can_controller_occupy_grid(grid, controller)
    return true

  var footprintStart = int2(-1)
  var footprintSize = int2(-1)
  get_controller_grid_footprint(grid, controller, footprintStart, footprintSize)

  let searchStepForward = int2(1, 0)
  let searchStepBackward = -searchStepForward
  let searchStepRight = int2(0, 1)
  let searchStepLeft = -searchStepRight
  let searchPattern = fixed_array(searchStepForward, searchStepRight, searchStepBackward, searchStepLeft)

  var radius = 1
  while true
    var atLeastOnePositionInGrid = false
    var currentFootprintStart = footprintStart - int2(radius)
    var currentFootprintEnd = currentFootprintStart + footprintSize
    for curStep in searchPattern
      for _ in range(0, radius * 2)
        currentFootprintStart += curStep
        currentFootprintEnd += curStep
        let isInGrid = is_footprint_in_grid(grid_dimentions, currentFootprintStart, currentFootprintEnd)
        atLeastOnePositionInGrid = atLeastOnePositionInGrid || isInGrid
        if !isInGrid
          continue
        let available = is_footprint_available(grid_dimentions,
                                                          grid_cells,
                                                          currentFootprintStart,
                                                          currentFootprintEnd,
                                                          controller)
        if available
          let start = get_grid_coordinates_by_row_column(grid, currentFootprintStart, false)
          let end = get_grid_coordinates_by_row_column(grid, currentFootprintEnd, false)
          controller_transform[3] = (start + end) / 2.0
          return true

    if !atLeastOnePositionInGrid
      break
    radius += 1

  return false


def safely_snap_construction_controller_to_grid(grid : EntityId; controller : EntityId)
  var foundPlace = false
  query(controller) <| $ [es] (var transform aka controller_transform : float3x4&;
                               construction_controller__blueprint : string)
    let controllerDims = get_blueprint_dims(construction_controller__blueprint)
    var newTransform = controller_transform
    query(grid) <| $ [es] (transform aka grid_transform : float3x4;
                           base_build_mode_grid__dimentions : int2;
                           base_build_mode_grid__cells : EidList)
      newTransform = get_snapped_controller_rotation(grid_transform, controller_transform)
      newTransform[3] = get_snapped_controller_coords(grid, controllerDims, controller_transform)
      controller_transform = newTransform
      foundPlace = try_find_free_space(grid,
                                       base_build_mode_grid__dimentions,
                                       base_build_mode_grid__cells,
                                       controller,
                                       controller_transform)
    if foundPlace
      controller_occupy_grid(grid, controller)
  return foundPlace


def snap_construction_controller_to_grid(grid : EntityId; controller : EntityId)
  query(controller) <| $ [es] (var transform aka controller_transform : float3x4&;
                               construction_controller__blueprint : string)
    let controllerDims = get_blueprint_dims(construction_controller__blueprint)
    var newTransform = controller_transform
    query(grid) <| $ [es] (transform aka grid_transform : float3x4)
      newTransform = get_snapped_controller_rotation(grid_transform, controller_transform)
    newTransform[3] = get_snapped_controller_coords(grid, controllerDims, controller_transform)
    controller_transform = newTransform
    controller_occupy_grid(grid, controller)


def get_grid_center(grid : EntityId)
  var result = float3(0.0)
  query(grid) <| $ [es] (transform : float3x4;
                         base_build_mode_grid__dimentions : int2;
                         base_build_mode_grid__step : float)
    let offset = float2(base_build_mode_grid__dimentions) * base_build_mode_grid__step / 2.0
    result = transform * float3(offset.x, 0.0, offset.y)
  return result


def rotate_footprint_dims(rotation : int; var dims : int2&)
  if rotation == 1 || rotation == 3
    swap(dims.x, dims.y)
  return dims


def calc_controller_transform_in_grid(grid : EntityId;
                                      pos : int2;
                                      rotation : int;
                                      blueprint : string)
  var gridTm = IDENT_TM
  var gridStep = 1.0
  query(grid) <| $ [es] (transform : float3x4; base_build_mode_grid__step : float)
    gridTm = transform
    gridStep = base_build_mode_grid__step
  let angle = get_in_grid_rotation_by_index(rotation)
  var rotTm = IDENT_TM
  rotyTM(angle, rotTm)
  var tm = gridTm * rotTm
  var dims = get_blueprint_dims(blueprint)
  rotate_footprint_dims(rotation, dims)
  let topLeftPos = get_grid_coordinates_by_row_column(grid, pos, false)
  tm[3] = topLeftPos + float3x3(gridTm) * float3(float(dims.x), 0.0, float(dims.y)) * gridStep / 2.0
  return tm


def calc_controller_position_and_rotation_in_grid(grid : EntityId;
                                                  controller_transform : float3x4;
                                                  blueprint : string;
                                                  var rotation : int&;
                                                  var move : int2&)
  query(grid) <| $ [es] (transform aka grid_transform : float3x4)
    rotation = get_snapped_controller_angle_index(grid_transform, controller_transform)
    var dims = get_blueprint_dims(blueprint)
    rotate_footprint_dims(rotation, dims)
    let topLeftOffset = float3x3(grid_transform) * float3(float(dims.x), 0., float(dims.y))
    move = get_grid_projected_intersection_point(grid, controller_transform[3] - topLeftOffset)


def find_grid_by_id(id : int)
  var grid = INVALID_ENTITY_ID
  find_query() <| $ [es] (eid : EntityId; base_build_mode_grid__id : int)
    if base_build_mode_grid__id != id
      return false
    grid = eid
    return true
  return grid


def find_closest_grid(point : float3;
                      seach_radius_sq : float = square(200.0))
  var gridEid = INVALID_ENTITY_ID
  var minDistSq = VERY_BIG_NUMBER
  query() <| $ [es(REQUIRE=base_build_mode_grid__id)] (eid aka grid_eid : EntityId;
                                                       transform aka grid_transform : float3x4)
    let distSq = distance_sq(point, grid_transform[3])
    if distSq < seach_radius_sq && distSq < minDistSq
      minDistSq = distSq
      gridEid = grid_eid
  return gridEid