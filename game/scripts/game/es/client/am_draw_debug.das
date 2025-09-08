options no_aot

require ecs
require ecs.common
require app
require math.base
require pathfinder
require imgui/imgui_boost
require daslib/strings_boost
require game.es.am_debug_draw_common
require game.es.flanking_ai_common
require game.es.grav_zones_common
require DagorImgui
require DngWalkerai


def pillar(pos : float3; color : E3DCOLOR; frames : int = 1; height : float = 50.0)
  var upPoint = pos
  upPoint.y += height
  draw_debug_line_buffered(pos, upPoint, color, frames)


def draw_object(transform : float3x4; color : E3DCOLOR; frames : int = 1; height : float = 50.0)
  pillar(transform[3], color, frames, height)
  draw_debug_tehedron_buffered(transform[3], 1.0, color, frames)


def get_first_template(eid : EntityId)
  let tmpl = getEntityTemplateName(eid)
  if empty(tmpl)
    return "'-'"
  let parrts <- split(tmpl, "+")
  return parrts[0]


[es(tag=(dev, gameClient), no_order)]
def draw_dev_debug_draw(act : UpdateStageInfoRenderDebug;
                        dev_draw__agents : bool;
                        dev_draw__playerAgents : bool;
                        dev_draw__humanPhysAgents : bool;
                        dev_draw__traps : bool;
                        dev_draw__frogTraps : bool;
                        dev_draw__teleportTraps : bool;
                        dev_draw__flowerTraps : bool;
                        dev_draw__cairdTraps : bool;
                        dev_draw__monstrifyTraps : bool;
                        dev_draw__firefly : bool;
                        dev_draw__changedHuman : bool;
                        dev_draw__flowerHuman : bool;
                        dev_draw__invisibleHuman : bool;
                        dev_draw__statue : bool;
                        dev_draw__boss : bool;
                        dev_draw__nest : bool;
                        dev_draw__wanderingCore : bool;
                        dev_draw__bees : bool;
                        dev_draw__slots : bool;
                        dev_draw__obstacles : bool;
                        dev_draw__gravity_zone : bool;
                        dev_draw__attract_points : bool;
                        dev_draw__navmesh_mapping_zones : bool;
                        dev_draw__households : bool;
                        dev_draw__quest_zones : bool;
                        dev_draw__teleports : bool;
                        dev_draw__notes : bool;
                        dev_draw__secret_ri : bool;
                        dev_draw__rendinsts : bool;
                        //dev_draw__gameObj : bool;
                        dev_draw__vehicle : bool;
                        dev_draw__active_matter : bool;
                        dev_draw__portals : bool;
                        dev_draw__respbases : bool;
                        dev_draw__extraction : bool;
                        dev_draw__ladders : bool)
  var relativePos : float3
  find_query() <| $ [es] (camera__active : bool; transform : float3x4)
    if camera__active
      relativePos = transform[3]
    return camera__active

  if dev_draw__bees
    query() <| $ [es(REQUIRE=swarm_cluster__target)] (eid : EntityId;
                                                      transform : float3x4;
                                                      attract_point__searchRadius : float;
                                                      swarm__visible : bool;
                                                      swarm_cluster__serverCount = 0;
                                                      count = 0)
      draw_object(transform, swarm__visible ? ACGREEN : ACBLUE)
      add_debug_text_mark(transform[3], "{get_first_template(eid)} cli:{count} / sv:{swarm_cluster__serverCount}", -1, 0., swarm__visible ? ACGREEN : ACBLUE)
      draw_debug_ball_buffered(transform[3], attract_point__searchRadius, ATTGREEN, 1)
      draw_debug_ball_buffered(transform[3], -attract_point__searchRadius, ATTGREEN, 1)
  if dev_draw__firefly
    query() <| $ [es(REQUIRE=firefly)] (transform : float3x4)
      draw_object(transform, ACYELLOW)
  if dev_draw__changedHuman
    query() <| $ [es(REQUIRE=changed)] (transform : float3x4)
      draw_object(transform, ACEMERALD)
  if dev_draw__flowerHuman
    query() <| $ [es(REQUIRE=flowerHuman)] (transform : float3x4)
      draw_object(transform, ACGREEN)
  if dev_draw__invisibleHuman
    query() <| $ [es(REQUIRE=invisibleMan)] (transform : float3x4)
      draw_object(transform, ACMAGENTA)
  if dev_draw__statue
    query() <| $ [es(REQUIRE=stalker_statue)] (transform : float3x4)
      draw_object(transform, ACCYAN)
  if dev_draw__boss
    query() <| $ [es(REQUIRE=miniboss__type)] (transform : float3x4)
      draw_object(transform, ACINDI)
  if dev_draw__wanderingCore
    query() <| $ [es(REQUIRE=wandering_core)] (transform aka c_transform : float3x4;
                                               wandering_core__targetEid : EntityId;
                                               wandering_core__targetPos : float3)
      draw_object(transform, ACBLUE)
      if wandering_core__targetEid == INVALID_ENTITY_ID
        draw_debug_arrow_buffered(transform[3], wandering_core__targetPos, ACCYAN, 1)
      query(wandering_core__targetEid) <| $ [es] (transform aka t_transform : float3x4)
        draw_debug_arrow_buffered(c_transform[3], t_transform[3], ACCYAN, 1)
    query() <| $ [es] (navmesh_waypoints__waypoints : Point3List;
                       navmesh_waypoints__projectedWaypoints : Point3List const?;
                       navmesh_waypoints__localSpace : bool;
                       navmesh_waypoints__looped : bool;
                       transform : float3x4)
      for idx in iter_range(navmesh_waypoints__waypoints)
        let pos = navmesh_waypoints__localSpace ? transform * navmesh_waypoints__waypoints[idx] : navmesh_waypoints__waypoints[idx]
        draw_debug_tehedron_buffered(pos, 0.2, ACINDI, 1)
        if navmesh_waypoints__projectedWaypoints != null
          let pos2 = (*navmesh_waypoints__projectedWaypoints)[idx]
          draw_debug_tehedron_buffered(pos2, 0.2, ACCYAN, 1)
          draw_debug_line_buffered(pos, pos2, ACCYAN, 1)
        let color = navmesh_waypoints__projectedWaypoints != null ? ACCYAN : ACINDI
        if idx + 1 < length(navmesh_waypoints__waypoints)
          let posNext = navmesh_waypoints__localSpace ? transform * navmesh_waypoints__waypoints[idx + 1] : navmesh_waypoints__waypoints[idx + 1]
          if navmesh_waypoints__looped
            draw_debug_arrow_buffered(pos, posNext, color, 1)
          else
            draw_debug_line_buffered(pos, posNext, color, 1)
        elif navmesh_waypoints__looped
          let posNext = navmesh_waypoints__localSpace ? transform * navmesh_waypoints__waypoints[0] : navmesh_waypoints__waypoints[0]
          draw_debug_arrow_buffered(pos, posNext, color, 1)
    query() <| $ [es(REQUIRE=chargesWanderingCore)] (transform : float3x4;
                                                     am_storage__value : int = 0;
                                                     item__count : int = 0;
                                                     wandering_core_am_equivalent__value : int = 0)
      if am_storage__value + item__count + wandering_core_am_equivalent__value > 0
        pillar(transform[3], ACEMERALD, 1, 100.0)
    query() <| $ [es(REQUIRE=spawn_pos__amCore)] (transform : float3x4; wandering_core_spawn__radius : float)
      draw_object(transform, ACGREEN)
      draw_debug_circle_buffered(transform[3] + transform[1], transform[1], wandering_core_spawn__radius, ACGREEN, int(wandering_core_spawn__radius + 1.0) * 3, 1)
  if dev_draw__nest
    query() <| $ [es(REQUIRE=nesting_swarm_nest)] (transform : float3x4)
      draw_object(transform, ACORANGE)

  if dev_draw__agents
    query() <| $ [es] (beh_tree__enabled : bool; transform : float3x4)
      let color = beh_tree__enabled ? ACWHITE : ACCYAN
      draw_object(transform, color)
  if dev_draw__humanPhysAgents
    query() <| $ [es(REQUIRE=human_net_phys)] (beh_tree__enabled : bool; transform : float3x4)
      let color = beh_tree__enabled ? ACWHITE : ACCYAN
      draw_object(transform, color)
  if dev_draw__playerAgents
    query() <| $ [es(REQUIRE=heroForPlayer)] (beh_tree__enabled : bool; transform : float3x4)
      let color = beh_tree__enabled ? ACWHITE : ACCYAN
      draw_object(transform, color)

  if dev_draw__traps
    query() <| $ [es(REQUIRE=anomaly_trap)] (transform : float3x4)
      draw_object(transform, ACWHITE)
  if dev_draw__frogTraps
    query() <| $ [es(REQUIRE=frog_trap)] (transform : float3x4)
      draw_object(transform, ACEMERALD)
  if dev_draw__teleportTraps
    query() <| $ [es(REQUIRE=teleport_trap)] (transform : float3x4)
      draw_object(transform, ACBLUE)
  if dev_draw__flowerTraps
    query() <| $ [es(REQUIRE=flower_trap)] (transform : float3x4)
      draw_object(transform, ACGREEN)
  if dev_draw__cairdTraps
    query() <| $ [es(REQUIRE=cairn_trap)] (transform : float3x4)
      draw_object(transform, ACCYAN)
  if dev_draw__monstrifyTraps
    query() <| $ [es(REQUIRE=monstrify_trap__group)] (transform : float3x4)
      draw_object(transform, ACORANGE)

  if dev_draw__extraction
    query() <| $ [es(REQUIRE=extraction_point)] (transform : float3x4; humanTriggerable : Tag const?)
      draw_object(transform, humanTriggerable == null ? ACINDI : ACBLUE)
  if dev_draw__respbases
    query() <| $ [es(REQUIRE=respbase)] (transform : float3x4)
      draw_object(transform, ACGREEN)
  if dev_draw__portals
    query() <| $ [es(REQUIRE=trans_portal)] (transform : float3x4)
      draw_object(transform, ACBLUE)
  if dev_draw__active_matter
    query() <| $ [es(REQUIRE=item__am)] (transform : float3x4)
      draw_object(transform, ACYELLOW)
  if dev_draw__vehicle
    query() <| $ [es(REQUIRE=vehicle)] (transform : float3x4)
      draw_object(transform, ACORANGE)
  if dev_draw__rendinsts
    query() <| $ [es(REQUIRE=lootableRendinst)] (transform : float3x4)
      draw_object(transform, ACGREEN)
  if dev_draw__notes
    query() <| $ [es(REQUIRE=secret_note__linkedContainerEid)] (transform : float3x4)
      draw_object(transform, ACYELLOW)
  if dev_draw__secret_ri
    query() <| $ [es(REQUIRE=secret_lootable_rendinst)] (transform : float3x4)
      draw_object(transform, ACMAGENTA)
  if dev_draw__quest_zones
    query() <| $ [es] (transform : float3x4; sphere_zone__radius : float)
      draw_debug_ball_buffered(transform[3], -sphere_zone__radius, ATTORANGE, 1)
      draw_debug_ball_buffered(transform[3], sphere_zone__radius, ATTORANGE, 1)
    query() <| $ [es] (transform : float3x4; quest_target_geometry_sphere__radius : float)
      draw_debug_ball_buffered(transform[3], -quest_target_geometry_sphere__radius, ATTORANGE, 1)
      draw_debug_ball_buffered(transform[3], quest_target_geometry_sphere__radius, ATTORANGE, 1)
  if dev_draw__teleports
    query() <| $ [es] (transform aka this_transform : float3x4;
                       eid, teleportation_portal__linkedPortal : EntityId;
                       teleportation_portal__safeLocalExitDir : float3;
                       teleportation_portal__isBidirectional : bool)
      let color1 = teleportation_portal__linkedPortal != INVALID_ENTITY_ID ? ATYELLOW : ATTTYELLOW
      let color2 = teleportation_portal__linkedPortal != INVALID_ENTITY_ID ? ACYELLOW : ATTYELLOW
      draw_debug_tm_buffered(transform, color1, 1)
      pillar(transform[3], color2, 1, 100.0)
      let ax1 = transform[3] - (transform[0] + transform[2] + transform[1]) * 0.5
      let ax2 = transform[3] - (-transform[0] + transform[2] + transform[1]) * 0.5
      let ax3 = transform[3] - (transform[0] - transform[2] + transform[1]) * 0.5
      let ax4 = transform[3] - (-transform[0] - transform[2] + transform[1]) * 0.5
      draw_debug_arrow_buffered(ax1, ax1 + transform[1], ACYELLOW, 1)
      draw_debug_arrow_buffered(ax2, ax2 + transform[1], ACYELLOW, 1)
      draw_debug_arrow_buffered(ax3, ax3 + transform[1], ACYELLOW, 1)
      draw_debug_arrow_buffered(ax4, ax4 + transform[1], ACYELLOW, 1)

      if length(teleportation_portal__safeLocalExitDir) > FLT_EPSILON
        draw_debug_arrow_buffered(this_transform[3], this_transform * teleportation_portal__safeLocalExitDir, E3DCOLOR(0xffffff00), 1)
      elif teleportation_portal__isBidirectional
        draw_debug_arrow_buffered(this_transform[3], this_transform[3] - normalize(this_transform[0]), E3DCOLOR(0xffffff00), 1)
        draw_debug_arrow_buffered(this_transform[3], this_transform[3] + normalize(this_transform[0]), E3DCOLOR(0xffffff00), 1)

      if uint(eid) > uint(teleportation_portal__linkedPortal)
        query(teleportation_portal__linkedPortal) <| $ [es] (transform aka other_transform : float3x4)
          draw_debug_line_buffered(this_transform[3], other_transform[3], ACORANGE, 1)
  if dev_draw__households
    query() <| $ [es] (monster_gen__tm : float3x4)
      draw_debug_tm_buffered(monster_gen__tm, ATTBLUE, 1)
      pillar(monster_gen__tm[3], ACBLUE)
  if dev_draw__navmesh_mapping_zones
    query() <| $ [es] (transform, position_mapping__matrix : float3x4; position_mapping__radius : float)
      draw_debug_ball_buffered(transform[3], position_mapping__radius, ATTCYAN, 1)
      draw_debug_ball_buffered(transform[3], -position_mapping__radius, ATTCYAN, 1)
      draw_debug_ball_buffered(position_mapping__matrix[3], position_mapping__radius, ATTWHITE, 1)
      draw_debug_ball_buffered(position_mapping__matrix[3], -position_mapping__radius, ATTWHITE, 1)
      draw_debug_line_buffered(transform[3], position_mapping__matrix[3], ACWHITE, 1)
    query() <| $ [es] (transform : float3x4; negative_position_mapping__radius : float; daeditor__selected : Tag const?)
      let color = daeditor__selected == null ? ATTYELLOW : ATYELLOW
      draw_debug_ball_buffered(transform[3], negative_position_mapping__radius, color, 1)
      draw_debug_ball_buffered(transform[3], -negative_position_mapping__radius, color, 1)
  if dev_draw__attract_points
    query() <| $ [es] (transform : float3x4; attract_point__magnitude : float)
      draw_debug_circle_buffered(transform[3] + float3(0, 1, 0), float3(0, 1, 0), attract_point__magnitude, ACYELLOW, 24, 1)
      pillar(transform[3], ACYELLOW)
  if dev_draw__gravity_zone
    query() <| $ [es] (transform : float3x4;
                       grav_zone__itm : float3x4;
                       daeditor__selected : Tag const?;
                       gravity_zone__boxSize : float3)
      if is_inside_box_zone(relativePos, grav_zone__itm, gravity_zone__boxSize)
        draw_debug_tm_buffered(transform, ATTORANGE, 1)
      elif daeditor__selected != null
        draw_debug_tm_buffered(transform, ATBLUE, 1)
      else
        draw_debug_tm_buffered(transform, ATTBLUE, 1)
  if dev_draw__obstacles
    query() <| $ [es(REQUIRE_NOT=nphys__disabled)] (agent_obstacles : AgentObstacles; transform : float3x4)
      if distance_sq(transform[3], relativePos) > square(100.0)
        return
      add_debug_text_mark(transform[3], "obstacles: {length(agent_obstacles.obstacles)}", -1, 0., ACWHITE)
      if length(agent_obstacles.obstacles) > 0
        let drawOffset = float3(0, 3, 0)
        let microOffset = float3(0., 0.05, 0.)
        draw_debug_sphere_buffered(transform[3] + microOffset, 0.05, ACWHITE, 12, 1)
        draw_debug_sphere_buffered(transform[3] + drawOffset, 0.05, ACWHITE, 12, 1)
        for o in agent_obstacles.obstacles
          for s, _ in o.segments, iter_range(o.segments)
            let inverted = dot(s.dir, s.end - s.start) < .0
            let col =  inverted ? ACRED : ACGREEN
            let col2 =  inverted ? ATTRED : ATTGREEN
            var start = s.start
            var end = s.end
            if inverted
              swap(start, end)
            draw_debug_arrow_buffered(start + microOffset, end + microOffset, col, 1)
            draw_debug_arrow_buffered(start + drawOffset, end + drawOffset, col, 1)
            draw_debug_quad_buffered(start, end, end + float3(0.f, o.height, 0.f), start + float3(0.f, o.height, 0.f), col2, 1)
  if dev_draw__slots
    query() <| $ [es(REQUIRE_NOT=sleeping_monster)] (flanking_ai__dir : float3;
                                                     flanking_ai__radius : float;
                                                     flanking_ai__priority : int;
                                                     walker_agent__targetEid : EntityId;
                                                     transform : float3x4;
                                                     eid : EntityId)
      if distance_sq(transform[3], relativePos) > square(100.0)
        return
      if flanking_ai__priority == 0
        query(walker_agent__targetEid) <| $ [es] (transform : float3x4)
          if distance_sq(transform[3], relativePos) > square(100.0)
            return
          var poly : dtPolyRef
          let pos = get_slot_position(transform[3], flanking_ai__dir, flanking_ai__radius, poly)
          draw_debug_sphere_buffered(pos, 0.5 + 0.1 * eid_frnd(eid), ACWHITE, 12, 1)
  if dev_draw__ladders
    query() <| $ [es(REQUIRE=human_ladder__marker)] (transform : float3x4)
      draw_object(transform, ACMAGENTA)


let offCol = IM_COL32(80, 80, 80, 155)
let offColH = IM_COL32(120, 120, 120, 255)

let imguiRed = IM_COL32(0, 0, 255, 155)
let imguiGreen = IM_COL32(0, 255, 0, 155)
let imguiBlue = IM_COL32(255, 60, 60, 200)
let imguiIndi = IM_COL32(100, 0, 0, 155)
let imguiYellow = IM_COL32(0, 210, 210, 185)
let imguiOrange = IM_COL32(0, 120, 255, 175)
let imguiMagenta = IM_COL32(185, 0, 185, 155)
let imguiCyan = IM_COL32(185, 185, 0, 155)
let imguiWhite = IM_COL32(230, 230, 230, 175)
let imguiEmeralg = IM_COL32(0, 115, 0, 155)

def draw_on_off_button(caption : string; var param : bool&; imgui_color : uint; same_line : bool = false)
  if same_line
    SameLine()
  let hCol = (255u << uint(IM_COL32_A_SHIFT)) | imgui_color
  imgui::PushStyleColor(ImGuiCol.Button, param ? imgui_color : offCol)
  imgui::PushStyleColor(ImGuiCol.ButtonHovered, param ? hCol : offColH)
  if imgui::Button("{caption}##hightlightDebug")
    param = !param
  imgui::PopStyleColor()
  imgui::PopStyleColor()

[imgui_window(name="Dev draw", group="AM")]
def dev_draw_window()
  if IsWindowCollapsed()
    return

  find_query() <| $ [es] (var dev_draw__agents : bool&;
                          var dev_draw__playerAgents : bool&;
                          var dev_draw__humanPhysAgents : bool&;
                          var dev_draw__traps : bool&;
                          var dev_draw__frogTraps : bool&;
                          var dev_draw__teleportTraps : bool&;
                          var dev_draw__flowerTraps : bool&;
                          var dev_draw__cairdTraps : bool&;
                          var dev_draw__monstrifyTraps : bool&;
                          var dev_draw__firefly : bool&;
                          var dev_draw__changedHuman : bool&;
                          var dev_draw__flowerHuman : bool&;
                          var dev_draw__invisibleHuman : bool&;
                          var dev_draw__statue : bool&;
                          var dev_draw__boss : bool&;
                          var dev_draw__nest : bool&;
                          var dev_draw__wanderingCore : bool&;
                          var dev_draw__bees : bool&;
                          var dev_draw__slots : bool&;
                          var dev_draw__obstacles : bool&;
                          var dev_draw__gravity_zone : bool&;
                          var dev_draw__attract_points : bool&;
                          var dev_draw__navmesh_mapping_zones : bool&;
                          var dev_draw__households : bool&;
                          var dev_draw__quest_zones : bool&;
                          var dev_draw__teleports : bool&;
                          var dev_draw__notes : bool&;
                          var dev_draw__secret_ri : bool&;
                          var dev_draw__rendinsts : bool&;
                          //var dev_draw__gameObj : bool&;
                          var dev_draw__vehicle : bool&;
                          var dev_draw__active_matter : bool&;
                          var dev_draw__portals : bool&;
                          var dev_draw__respbases : bool&;
                          var dev_draw__extraction : bool&;
                          var dev_draw__ladders : bool&)

    imgui::Text("Agents")
    draw_on_off_button("All agents", dev_draw__agents, imguiCyan)
    draw_on_off_button("human phys", dev_draw__humanPhysAgents, imguiCyan, true)
    draw_on_off_button("players", dev_draw__playerAgents, imguiCyan, true)

    imgui::Text("Traps")
    draw_on_off_button("All traps", dev_draw__traps, imguiWhite)
    draw_on_off_button("frog", dev_draw__frogTraps, imguiEmeralg, true)
    draw_on_off_button("teleport", dev_draw__teleportTraps, imguiBlue, true)
    draw_on_off_button("flower", dev_draw__flowerTraps, imguiGreen, true)
    draw_on_off_button("cairn", dev_draw__cairdTraps, imguiCyan, true)
    draw_on_off_button("monstrify", dev_draw__monstrifyTraps, imguiOrange, true)

    imgui::Text("Monsters")
    draw_on_off_button("changed h", dev_draw__changedHuman, imguiEmeralg)
    draw_on_off_button("flower h", dev_draw__flowerHuman, imguiGreen, true)
    draw_on_off_button("boss", dev_draw__boss, imguiIndi, true)
    draw_on_off_button("invisible", dev_draw__invisibleHuman, imguiMagenta, true)
    draw_on_off_button("seeds", dev_draw__firefly, imguiYellow, true)
    draw_on_off_button("statue", dev_draw__statue, imguiCyan, true)
    draw_on_off_button("lightning", dev_draw__wanderingCore, imguiBlue, true)
    draw_on_off_button("nest", dev_draw__nest, imguiOrange, true)
    draw_on_off_button("bees", dev_draw__bees, imguiGreen, true)

    imgui::Text("Objects")
    draw_on_off_button("lootable ri", dev_draw__rendinsts, imguiGreen)
    draw_on_off_button("vehicles", dev_draw__vehicle, imguiOrange, true)
    draw_on_off_button("AM", dev_draw__active_matter, imguiYellow, true)
    draw_on_off_button("notes", dev_draw__notes, imguiYellow, true)
    draw_on_off_button("secret ri", dev_draw__secret_ri, imguiMagenta, true)
    draw_on_off_button("portals", dev_draw__portals, imguiBlue, true)
    draw_on_off_button("spawns", dev_draw__respbases, imguiGreen, true)
    draw_on_off_button("extraction", dev_draw__extraction, imguiBlue, true)
    draw_on_off_button("ladders", dev_draw__ladders, imguiMagenta, true)

    imgui::Text("Mechanics")
    draw_on_off_button("flanking slots", dev_draw__slots, imguiWhite)
    draw_on_off_button("obstacles", dev_draw__obstacles, imguiGreen, true)
    draw_on_off_button("gravity", dev_draw__gravity_zone, imguiBlue, true)
    draw_on_off_button("attract points", dev_draw__attract_points, imguiYellow, true)
    draw_on_off_button("nav mapping", dev_draw__navmesh_mapping_zones, imguiCyan, true)
    draw_on_off_button("TM monster gen", dev_draw__households, imguiBlue, true)
    draw_on_off_button("quest zones", dev_draw__quest_zones, imguiOrange, true)
    draw_on_off_button("teleports", dev_draw__teleports, imguiYellow)
    return true