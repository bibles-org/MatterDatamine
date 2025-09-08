module heat_source_common shared
require ecs
require ecs.common
require math
require math.base
require DagorSystem
require DagorMath
require AnimV20
require GeomNodeTree
require strings
require dm
require DngDm
require CollRes
require danetlibs.renderer.includes.pufd_events public

[export]
enum partType
  HULL = 0
  ENGINE = 1
  RADIATOR = 2
  TRACK = 3
  WHEEL = 4
  TANK_GUN_MAIN = 5
  TANK_GUN_MAIN_OVERHEATED = 6
  TANK_MG = 7
  HUMAN_HEAD = 8
  HUMAN_TORSO = 9
  HUMAN_LEG = 10
  HUMAN_HAND = 11
  HUMAN_GUN = 12

def updateHeatSourceTm(carTransform : float3x4;
                       collres : CollisionResource;
                       animchar : AnimcharBaseComponent;
                       collisionNodeId : int;
                       heatEid : EntityId)
  if heatEid == INVALID_ENTITY_ID
    return
  let node = collres_get_node(collres, collisionNodeId)
  if node != null
    var tm : float3x4
    collres_get_collision_node_tm(collres, collisionNodeId, carTransform, animchar.nodeTree, tm)
    let partModelBBox = (*node).modelBBox
    let pos = tm * partModelBBox.center
    query(heatEid) <| $ [es] (var transform : float3x4&;
                              heat_source__type : int)
      if (heat_source__type == int(partType.WHEEL))
        transform = carTransform
      else
        transform = tm
      transform[3] = pos

def destroyHeatSources(var listEId : EidList)
  for heatEid in listEId
    if heatEid == INVALID_ENTITY_ID
      continue
    destroyEntity(heatEid)

def createHeatSource(transform : float3x4;
                     collres : CollisionResource;
                     animchar : AnimcharBaseComponent;
                     damage_model : DamageModel;
                     partId : int;
                     var listEId : EidList;
                     partTemperature : float4;
                     var offset : float3;
                     scale : float3;
                     typePart : partType;
                     overheat : bool = false;
                     shouldInflate : bool = false;
                     dirRadOffset : float3 = float3(0, 0, 0);
                     radMult : float = 0.0)
  let collisionNodeId = get_collision_node_id(damage_model.dmData, partId)
  let node = collres_get_node(collres, collisionNodeId)
  var heatEid = INVALID_ENTITY_ID
  if node != null
    var tm : float3x4
    collres_get_collision_node_tm(collres, collisionNodeId, transform, animchar.nodeTree, tm)
    let partModelBBox = (*node).modelBBox
    var rad : float3
    if typePart != partType.WHEEL
      rad = partModelBBox.width
    else
      rad = float3((*node).boundingSphere.r)
    heatEid = createEntity("heat_source_item") <| $(var init : ComponentsInitializer)
      set(init, "transform", tm)
      set(init, "heat_source__basicRad", rad)
      set(init, "heat_source__radMult", radMult)
      set(init, "heat_source__dirRadOffset", dirRadOffset)
      set(init, "heat_source__offset", offset)
      set(init, "heat_source__basicScale", scale)
      set(init, "heat_source__shouldInflate", shouldInflate)
      set(init, "heat_source__scale", scale)
      set(init, "heat_source__temperature", partTemperature)
      set(init, "heat_source__type", int(typePart))
      set(init, "heat_source__overheat", overheat)
    push(listEId, heatEid)

def find_turret_heat_source_params(turret_info : Array; turret_name : string;
                                   var out_offset : float3&; var out_scale : float3&; var out_radMult : float&) : bool
  for item in turret_info
    let turret = get_ecs_object(item)
    if turret != null && get_string(turret, "turretName", "") == turret_name
      out_offset = get_Point3(turret, "offset") ?? out_offset
      out_scale = get_Point3(turret, "scale") ?? out_scale
      out_radMult = get_float(turret, "radMult") ?? out_radMult
      return true
  return false
