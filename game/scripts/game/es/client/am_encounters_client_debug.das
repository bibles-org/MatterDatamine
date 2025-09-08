options no_aot
require ecs
require ecs.safe
require ecs.soa_template
require ecs.ecs_template
require game.utils.hero
require game.es.am_encounter_jump_quest_common
require math.base
require DagorConsole
require DagorDebug3D
require DagorSystem


[ecs_template]
struct encounter_zone_debug_draw
  encounter_zone__debugDraw : bool = false


[console_cmd(name="encounter.debug_draw")]
def encounter_zone_debug_draw_cmd(draw : bool = true)
  let tmpl = "encounter_zone_debug_draw"
  addSubTemplate(get_controlled_hero(), tmpl) <| $(var init)
    set(init, "encounter_zone__debugDraw", draw)


[es(tag=render, tag=dev, no_order)]
def encounter_zone_debug_es(evt : UpdateStageInfoRenderDebug;
                            encounter_zone__debugDraw : bool)
  if !encounter_zone__debugDraw
    return
  query() <| $ [es] (transform : float3x4;
                     sphere_zone__radius : float;
                     encounter_zone__name : string)
    let color = E3DCOLOR(0xFF09FF00)
    draw_debug_sphere_buffered(transform[3], sphere_zone__radius, color, 36, 1)
    add_debug_text_mark(transform[3], encounter_zone__name, -1, 0.0, color)


[ecs_template]
struct encounter_jump_quest_debug_draw
  encounter_jump_quest__debugDraw : bool = false


[console_cmd(name="encounter.jump_quest_debug_draw")]
def encounter_jump_quest_debug_draw_cmd(draw : bool = true)
  let tmpl = "encounter_jump_quest_debug_draw"
  addSubTemplate(get_controlled_hero(), tmpl) <| $(var init)
    set(init, "encounter_jump_quest__debugDraw", draw)


def get_jump_quest_node_color(node_type : int)
  if node_type == int(EncounterJumpQuestNodeType.PATH)
    return E3DCOLOR(0xFF09FF00)
  elif node_type == int(EncounterJumpQuestNodeType.TOP_PLATFORM)
    return E3DCOLOR(0xFFFF00FF)
  elif node_type == int(EncounterJumpQuestNodeType.DECOR)
    return E3DCOLOR(0xB20077FF)
  else
    return E3DCOLOR(0xFFFF0000)


[soa_def]
def draw_jump_quest_node(node_index : int;
                         nodes : EncounterJumpQuestNode_SOA)
  let nodeType = nodes[node_index].encounter_jump_quest__nodes__type
  let tm = nodes[node_index].encounter_jump_quest__nodes__collisionTm

  let topPoint = get_jump_node_top_point(tm)

  draw_debug_sphere_buffered(tm[3], 0.05, E3DCOLOR(0xFFFF00BF), 12, 1)
  draw_debug_sphere_buffered(topPoint, 0.05, E3DCOLOR(0xFF00FF0D), 12, 1)
  let corner0 = tm * (float3(-0.5, -0.5, -0.5))
  draw_cached_debug_box(
    corner0, tm[0], tm[1], tm[2],
    get_jump_quest_node_color(nodeType))

  if nodeType == int(EncounterJumpQuestNodeType.PATH)
    let humanStandTm = get_jump_node_human_stand_tm(topPoint)
    let corner1 = humanStandTm * (float3(-0.5, -0.5, -0.5))
    draw_cached_debug_box(corner1, humanStandTm[0], humanStandTm[1], humanStandTm[2], E3DCOLOR(0x7EBEBEBE))


[soa_def]
def draw_jump_quest_node_link(node_index0 : int;
                              node_index1 : int;
                              nodes : EncounterJumpQuestNode_SOA)
  let pointATransform = nodes[node_index0].encounter_jump_quest__nodes__collisionTm
  let pointBTransform = nodes[node_index1].encounter_jump_quest__nodes__collisionTm
  let pointATop = get_jump_node_top_point(pointATransform)
  let pointBTop = get_jump_node_top_point(pointBTransform)
  draw_debug_line_buffered(pointATop, pointBTop, E3DCOLOR(0xFFFFFFFF), 1)


[soa_es, es(tag=(render, dev), no_order)]
def encounter_jump_quest_debug_es(evt : UpdateStageInfoRenderDebug;
                                  encounter_jump_quest__debugDraw : bool)
  if !encounter_jump_quest__debugDraw
    return
  query() <| $ [soa_blk, es(REQUIRE=encounter_jump_quest)] (encounter_jump_quest__nodes : EncounterJumpQuestNode_SOA;
                                                            encounter_jump_quest__nodeLinks : IPoint2List)

    let pointsCount = length(encounter_jump_quest__nodes)
    if pointsCount != 0
      for i in range(0, pointsCount - 1)
        draw_jump_quest_node(i, encounter_jump_quest__nodes)
      draw_jump_quest_node(pointsCount - 1, encounter_jump_quest__nodes)
    for link in encounter_jump_quest__nodeLinks
      draw_jump_quest_node_link(link.x, link.y, encounter_jump_quest__nodes)


[ecs_template]
struct encounter_jump_quest_ai_debug_draw
  encounter_jump_quest_ai__debugDraw : bool = false


[console_cmd(name="encounter.jump_quest_ai_debug_draw")]
def encounter_jump_quest_ai_debug_draw_cmd(draw : bool = true)
  let tmpl = "encounter_jump_quest_ai_debug_draw"
  addSubTemplate(get_controlled_hero(), tmpl) <| $(var init)
    set(init, "encounter_jump_quest_ai__debugDraw", draw)


[soa_es, es(tag=(render, dev), no_order)]
def encounter_jump_quest_ai_debug_es(evt : UpdateStageInfoRenderDebug;
                                     encounter_jump_quest_ai__debugDraw : bool)
  if !encounter_jump_quest_ai__debugDraw
    return

  query() <| $ [soa_blk, es] (transform aka core_transform : float3x4;
                              encounter_jump_quest_core_ai__alarmRadiusSq : float;
                              encounter_jump_quest_core_ai__protectiveRadiusSq : float;
                              encounter_jump_quest_core_ai__projectileEids : EidList;
                              enemies : EncounterJumpQuestEnemy_SOA)
    let alarmRadius = sqrt(encounter_jump_quest_core_ai__alarmRadiusSq)
    let enemiesCount = length(enemies)
    draw_debug_sphere_buffered(transform[3], alarmRadius, enemiesCount > 0 ? E3DCOLOR(0xFFFF0000) : E3DCOLOR(0xFF6D6D6D), 36, 1)

    let protectiveRadius = sqrt(encounter_jump_quest_core_ai__protectiveRadiusSq)
    draw_debug_sphere_buffered(transform[3], protectiveRadius, E3DCOLOR(0xFF15A9FF), 36, 1)

    for enemy in enemies
      query(enemy.encounter_jump_quest_core_ai__enemies__eid) <| $ [es] (transform aka enemy_transform : float3x4)
        draw_debug_line_buffered(core_transform[3], enemy_transform[3], E3DCOLOR(0xFFC300FF), 1)
        add_debug_text_mark(enemy_transform[3], "{enemy.encounter_jump_quest_core_ai__enemies__alarmTime}", -1, 0.0, E3DCOLOR(0xFFFF0000))

    for projectileEid in encounter_jump_quest_core_ai__projectileEids
      query(projectileEid) <| $ [es] (transform aka projectile_transform : float3x4;
                                      encounter_jump_quest_core_projectile__state : int;
                                      encounter_jump_quest_core_projectile__enemyEid : EntityId)
        let isAggresiveState = (encounter_jump_quest_core_projectile__state == int(EncounterJumpQuestCoreProjectileState.TRACKING_ENEMY) ||
                                encounter_jump_quest_core_projectile__state == int(EncounterJumpQuestCoreProjectileState.CHARGING_TO_RAM) ||
                                encounter_jump_quest_core_projectile__state == int(EncounterJumpQuestCoreProjectileState.RAM_ENEMY))

        add_debug_text_mark(projectile_transform[3],
                            "state: {encounter_jump_quest_core_projectile__state}",
                            -1, 0.0, isAggresiveState ? E3DCOLOR(0xFFFC1111) : E3DCOLOR(0xFF31CFFF))
        query(encounter_jump_quest_core_projectile__enemyEid) <| $ [es] (transform aka enemy_transform : float3x4)
          draw_debug_line_buffered(projectile_transform[3], enemy_transform[3], E3DCOLOR(0xFFFF0000), 1)
