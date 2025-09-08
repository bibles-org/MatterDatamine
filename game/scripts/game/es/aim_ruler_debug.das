options no_aot
require ecs
require strings
require CollRes
require DagorConsole
require Dacoll
require DagorDebug3D
require GridCollision
require CollisionTraces
require Grid
require PhysMat

[console_cmd(name="aim.ruler")]
def draw_aim_ruler()
  let found = find_query() <| $ [es(REQUIRE=aimRulerDebug)] (eid : EntityId)
    destroyEntity(eid)
    return true
  if !found
    createEntity("aim_ruler_debug")

def private trace_grid(grid_type : uint; pos, dir : float3; var len : float&)
  var retEid = INVALID_ENTITY_ID
  trace_entities_in_grid(grid_type, pos, dir, len, INVALID_ENTITY_ID, SortIntersections.YES) <| $(intersections : array<IntersectedEntity>#)
    if length(intersections) != 0
      retEid = intersections[0].eid
  return retEid

[es(tag=render, no_order, REQUIRE=aimRulerDebug)]
def draw_ruler_es(evt : UpdateStageInfoRenderDebug; shouldDraw : bool; tracePos : float3; traceDir : float3)
  if !shouldDraw
    return
  var len = 4000f
  var norm : float3
  var color = E3DCOLOR(0xFFFFFFFF)
  var matId = PHYSMAT_INVALID
  var riDesc = RendInstDesc()
  if traceray_normalized(tracePos, traceDir, len, matId, norm, ETF_ALL, riDesc, -1)
    color = E3DCOLOR(0xFF00FF00)
  var desc = fmt(":.2f", len) + "m"
  let humanTarget = trace_grid(ecs_hash("humans"), tracePos, traceDir, len)
  let vehicleTarget = trace_grid(ecs_hash("vehicles"), tracePos, traceDir, len)
  let lootTarget = trace_grid(ecs_hash("loot"), tracePos, traceDir, len)
  let gunTarget = trace_grid(ecs_hash("interactable"), tracePos, traceDir, len)
  let targetEid = !!gunTarget ? gunTarget : !!lootTarget ? lootTarget : !!humanTarget ? humanTarget : vehicleTarget
  if !targetEid
    if matId >= 0
      desc += " mat {matId} <{get_material_name(get_material(matId))}>"
  else
    color = E3DCOLOR(0xFF00FF00)
    query(targetEid) <| $ [es] (possessedByPlr : EntityId const?; transform : float3x4; collres : CollisionResource; material : string = "default")
      var t = 4000f
      if collres_traceray(collres, transform, tracePos, traceDir, t, norm, matId)
        desc += " pmat {matId} <{get_material_name(get_material(matId))}>"
      desc += " mat {get_material_id(material)} <{material}>"
      if possessedByPlr != null
        desc += " plr <{get_string(*possessedByPlr, "name", "")}>"
    desc += " {targetEid} <{getEntityTemplateName(targetEid)}>"
  let pos = tracePos + traceDir * len
  draw_debug_line_buffered(tracePos, pos, color, 5)
  add_debug_text_mark(pos, desc, -1, 0., color)