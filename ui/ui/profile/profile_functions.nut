import "%dngscripts/ecs.nut" as ecs
from "math" import min

let {IPoint2} = require("dagor.math")

function getTemplateComponent(template_name, component_name){
  if (template_name == null || template_name.len() == 0)
    return null
  let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(template_name)
  return template != null ? template.getCompValNullable(component_name) : null
}

function parseBaseBuildings(deployed_constructions) {
  local positions = []
  local rotations = []
  local ids_int64 = []
  local gridIds = []

  foreach (construction in deployed_constructions) {
    let pos = construction?.v?.positionInGrid;
    positions.append(IPoint2(pos?.x ?? 0, pos?.y ?? 0))
    rotations.append(construction?.v?.rotationInGrid ?? 0)
    gridIds.append(construction?.v?.grid_id ?? 0)
    ids_int64.append(construction?.k ?? 0)
  }

  return {positions, rotations, ids_int64, gridIds}
}

function parseBasePower(base_power) {
  local basePower = {}
  foreach (powerInfo in base_power) {
    basePower[$"{powerInfo?.k ?? 0}_int64"] <- powerInfo?.v ?? 0
  }
  return basePower
}

return {
  getTemplateComponent
  parseBaseBuildings
  parseBasePower
}
