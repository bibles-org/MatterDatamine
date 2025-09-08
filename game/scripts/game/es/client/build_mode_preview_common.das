module build_mode_preview_common shared

require ecs
require ecs.safe
require math
require math.base
require DagorMath
require DagorSystem
require Dacoll
require game.es.client.build_mode_grid_common


def create_preview_from_building(construction_controller : EntityId) : EntityId
  var result = INVALID_ENTITY_ID
  query(construction_controller) <| $ [es] (transform : float3x4;
                                            construction_controller__blueprint : string;
                                            construction_controller__instanceId : int64;
                                            construction_controller__gridId : int)
    result = createEntity("construction_controller+base_build_mode_controller_preview") <| $(init)
      set(init, "construction_controller__blueprint", construction_controller__blueprint)
      set(init, "transform", transform)
      set(init, "construction_controller__instanceId", construction_controller__instanceId)
      set(init, "construction_controller__gridId", construction_controller__gridId)

  query(construction_controller) <| $ [es] (powered_controller__attachedTo : int64)
    addSubTemplate(result, "powered_controller") <| $(init)
      set(init, "powered_controller__attachedTo", powered_controller__attachedTo)
  if has(construction_controller, "baked_construction_controller")
    addSubTemplate(result, "baked_construction_controller")
  return result


def make_preview_active(preview : EntityId)
  query(preview) <| $ [es] (construction_controller__parts : EidList)
    for part in construction_controller__parts
      addSubTemplate(part, "base_build_mode_preview")


def make_preview_inactive(preview : EntityId)
  query(preview) <| $ [es] (construction_controller__parts : EidList)
    for part in construction_controller__parts
      removeSubTemplate(part, "base_build_mode_preview")


def clear_build_mode_selection(var active_preview : EntityId&)
  make_preview_inactive(active_preview)
  active_preview = INVALID_ENTITY_ID


def create_preview_from_stash(blueprint_name : string;
                              transform aka desired_transform : float3x4;
                              unique_id : string;
                              grid_id : int) : EntityId
  let blueprint = getTemplateByName(blueprint_name)
  if blueprint == null
    logerr("Trying to create empty template for item with unique id <{unique_id}>; template name = \"{blueprint_name}\"")
    return INVALID_ENTITY_ID
  return createEntity("construction_controller+base_build_mode_controller_preview") <| $(init)
    set(init, "transform", desired_transform)
    set(init, "construction_controller__blueprint", blueprint_name)
    set(init, "construction_controller__instanceId", unique_id)
    set(init, "construction_controller__gridId", grid_id)


def drop_construction(var transform : float3x4)
  // drop rendinst on ground
  let pickUpHeight = 10.0
  var height = 300.0
  transform[3][1] += pickUpHeight
  tracedown_normalized(transform[3], height, ETF_HEIGHTMAP)
  transform[3][1] -= height


def move_preview(move : float3;
                 base_build_mode__activeGrid : EntityId;
                 var transform : float3x4&)
  let newPosition = transform[3] + move
  if !is_point_in_grid(base_build_mode__activeGrid, newPosition)
    return
  transform[3] = newPosition
  drop_construction(transform)


def get_id_from_preview(preview : EntityId) : string
  var id = "0"
  query(preview) <| $ [es(REQUIRE=base_build_mode_controller_preview)] (construction_controller__instanceId : string)
    id = construction_controller__instanceId
  return id
