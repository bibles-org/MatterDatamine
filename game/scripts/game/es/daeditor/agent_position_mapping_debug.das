options no_aot

require ecs
require DagorDebug3D
require DagorMath
require DagorDebug3DSolid
require DagorConsole
require PhysMat
require CollRes
require Dacoll
require pathfinder
require math.base
require DngWalkerai
require game.es.ai.agent_position_mapping_common
require game.es.ecs_common
require NavmeshMapping
require math.color
require DagorSystem
require DagorDataBlock
require danetlibs.imgui_daeditor.daEditor.daEditor_common


[console_cmd(name="navmeshmapping.ruler")]
def toggle_navmeshmapping_ruler()
  let found = find_query() <| $ [es(REQUIRE=navmesh_mapping_debug_ruler)] (eid : EntityId)
    destroyEntity(eid)
    return true
  if !found
    createEntity("navmesh_mapping_debug_ruler")


[console_cmd(name="navmeshmapping.draw_zones")]
def toggle_navmeshmapping_debug_draw()
  let found = find_query() <| $ [es(REQUIRE=navmesh_mapping_debug)] (eid : EntityId)
    destroyEntity(eid)
    return true
  if !found
    createEntity("navmesh_mapping_debug")


def draw_mapping_area(tm : float3x4; radius : float; color : E3DCOLOR; frames : int)
  draw_debug_sphere_buffered(tm[3], 0.5, color, frames)
  draw_debug_sphere_buffered(tm[3] + tm[0] * radius, 0.5, color, frames)
  draw_debug_sphere_buffered(tm[3] + tm[1] * radius, 0.5, color, frames)
  draw_debug_sphere_buffered(tm[3] + tm[2] * radius, 0.5, color, frames)
  draw_debug_sphere_buffered(tm[3] - tm[0] * radius, 0.5, color, frames)
  draw_debug_sphere_buffered(tm[3] - tm[1] * radius, 0.5, color, frames)
  draw_debug_sphere_buffered(tm[3] - tm[2] * radius, 0.5, color, frames)

  draw_debug_line_buffered(tm[3] + tm[0] * radius, tm[3] - tm[0] * radius, E3DCOLOR(0xffff0000), frames)
  draw_debug_line_buffered(tm[3] + tm[1] * radius, tm[3] - tm[1] * radius, E3DCOLOR(0xff00ff00), frames)
  draw_debug_line_buffered(tm[3] + tm[2] * radius, tm[3] - tm[2] * radius, E3DCOLOR(0xff0000ff), frames)


[es(no_order, REQUIRE=navmesh_mapping_debug, tag=dev)]
def position_mapping_debug_draw(update : UpdateStageInfoAct)
  let duration = 1
  var activeCamPos : float3
  find_query() <| $ [es] (camera__active : bool; transform : float3x4)
    if !camera__active
      return false
    activeCamPos = transform[3]
    return true
  query() <| $ [es] (eid : EntityId;
                     transform : float3x4;
                     position_mapping__drawUnmappedNavmesh : bool;
                     position_mapping__radius : float;
                     position_mapping__matrix : float3x4)
    let color = get_debug_zone_color(eid)
    draw_mapping_area(transform, position_mapping__radius, color, duration)
    draw_debug_line_buffered(transform[3], position_mapping__matrix[3], color, duration)
    draw_mapping_area(position_mapping__matrix, position_mapping__radius, color, duration)
    draw_debug_line_buffered(position_mapping__matrix[3], position_mapping__matrix[3] + position_mapping__matrix[0], E3DCOLOR(0xffff0000), duration)
    draw_debug_line_buffered(position_mapping__matrix[3], position_mapping__matrix[3] + position_mapping__matrix[1], E3DCOLOR(0xff00ff00), duration)
    draw_debug_line_buffered(position_mapping__matrix[3], position_mapping__matrix[3] + position_mapping__matrix[2], E3DCOLOR(0xff0000ff), duration)
    if !position_mapping__drawUnmappedNavmesh && distance_sq(activeCamPos, transform[3]) < square(500.0) // otherwise it is drawn in another system, no need for double draw
      draw_navmesh_for_mapping_zone(eid, position_mapping__matrix, position_mapping__radius)


[console_cmd(name="navmeshmapping.configure_selected")]
def configure_position_mapping()
  find_query() <| $ [es(REQUIRE=daeditor__selected)] (position_mapping__radius : float; transform : float3x4; eid : EntityId)
    createEntity("navigation_position_mapping_helper") <| $(var init)
      var helperTm = transform
      helperTm[3] += float3(0.0, 1.0, 0.0)
      set(init, "transform", helperTm)
      set(init, "position_mapping__radius", position_mapping__radius)
      set(init, "position_mapping_helper__owner", eid)
    return true


[es(no_order, REQUIRE=position_mapping_helper__owner, tag=dev)]
def draw_position_mapping_helper(update : UpdateStageInfoAct; position_mapping__radius : float; transform : float3x4)
  draw_mapping_area(transform, position_mapping__radius, E3DCOLOR(0xffff0000), 1)


[console_cmd(name="navmeshmapping.finalize_configuration")]
def finalize_position_mapping()
  find_query() <| $ [es] (position_mapping_helper__owner : EntityId; transform : float3x4; eid : EntityId)
    query(position_mapping_helper__owner) <| $ [es] (var position_mapping__matrix : float3x4&)
      position_mapping__matrix = transform
    destroyEntity(eid)
    return true


[es(no_order, REQUIRE=navmesh_mapping_debug_ruler, tag=dev)]
def debug_mapping_ruller(update : UpdateStageInfoAct)
  find_query() <| $ [es] (camera__active : bool; transform : float3x4)
    if !camera__active
      return false
    var len = 4000f
    var norm : float3
    let b = uint((sin(update.curTime) + 1.0) * 0.5 * 255.0)
    let r = 0x000000ff
    let g = uint((cos(update.curTime) + 1.0) * 0.5 * 255.0)
    let color = E3DCOLOR(uint4(r, g, b, 0x000000ff))
    var matId = PHYSMAT_INVALID
    var riDesc = RendInstDesc()
    if traceray_normalized(transform[3], transform[2], len, matId, norm, ETF_ALL, riDesc, -1)
      let pos = transform[3] + transform[2] * len
      draw_debug_sphere_buffered(pos, 0.5, color, 40)
      let mappedPos = navmesh_map_position(pos)
      draw_debug_sphere_buffered(mappedPos, 0.5, color, 40)
      draw_debug_line_buffered(pos, mappedPos, color, 2)

      let up = float3(0.0, 1.0, 0.0)
      draw_debug_line_buffered(mappedPos, mappedPos + up * 3.0, E3DCOLOR(0xffff0000), 2)
      draw_debug_line_buffered(pos, pos + navmesh_unmap_direction(up, mappedPos) * 3.0, E3DCOLOR(0xffff0000), 2)
    else
      draw_debug_line_buffered(transform[3], transform[3] + transform[2] * len, E3DCOLOR(0xffff0000), 2)
    return true


[console_cmd(name="navmeshmapping.map_camera_position")]
def nameshmapping_map_camera_positon()
  find_query() <| $ [es] (camera__active : bool; var transform : float3x4&)
    if !camera__active
      return false
    let mappedPos = navmesh_map_position(transform[3])
    transform[3] = mappedPos
    return true


[console_cmd(name="navmeshmapping.unmap_camera_position")]
def nameshmapping_unmap_camera_positon()
  find_query() <| $ [es] (camera__active : bool; var transform : float3x4&)
    if !camera__active
      return false
    let mappedPos = navmesh_unmap_position(transform[3])
    validate_gameplay_position(mappedPos) <| $()
      return <- "mappedPos={transform[3]}"
    transform[3] = mappedPos
    return true


[console_cmd(name="navmeshmapping.create_debug_waypoint")]
def create_debug_waypoint()
  find_query() <| $ [es] (camera__active : bool; transform : float3x4)
    if !camera__active
      return false
    var len = 4000f
    var norm : float3
    var matId = PHYSMAT_INVALID
    var riDesc = RendInstDesc()
    if traceray_normalized(transform[3], transform[2], len, matId, norm, ETF_ALL, riDesc, -1)
      let pos = transform[3] + transform[2] * len
      var tm = IDENT_TM
      tm[3] = pos
      createEntity("debug_waypoint") <| $(init)
        set(init, "transform", tm)
    return true


[console_cmd(name="navmeshmapping.destroy_debug_waypoints")]
def destroy_debug_waypoints()
  query() <| $ [es(REQUIRE=debug_waypoint)] (eid : EntityId)
    destroyEntity(eid)


[es(no_order, REQUIRE=debug_waypoint)]
def draw_debug_waypoint(update : UpdateStageInfoAct; transform : float3x4)
  let b = 250u
  let r = 255u
  let g = 100u
  let color = E3DCOLOR(uint4(r, g, b, 0x000000ff))
  draw_debug_sphere_buffered(transform[3], 0.5, color, 2)


def private get_debug_zone_color(zone_eid : EntityId)
  let sd = uint(zone_eid)
  let numColors = 8u
  let color = E3DCOLOR(Color4(hsv2rgb(float3(float(sd % numColors * 360u / numColors), 1.0, 1.0)), 1.0))
  return color


[console_cmd(name="navmeshmapping.create_debug_marker")]
def create_debug_marker()
  find_query() <| $ [es] (camera__active : bool; transform : float3x4)
    if !camera__active
      return false
    var len = 4000f
    var norm : float3
    var matId = PHYSMAT_INVALID
    var riDesc = RendInstDesc()
    if traceray_normalized(transform[3], transform[2], len, matId, norm, ETF_ALL, riDesc, -1)
      let pos = transform[3] + transform[2] * len
      var tm = IDENT_TM
      tm[3] = pos
      createEntity("debug_navmeshmapping_marker") <| $(init)
        set(init, "transform", tm)
    return true


[es(no_order, REQUIRE=debug_navmeshmapping_marker)]
def draw_debug_navmeshmapping_marker(update : UpdateStageInfoAct; transform : float3x4)
  let b = 250u
  let r = 255u
  let g = 100u
  let color = E3DCOLOR(uint4(r, g, b, 0x000000ff))
  let frames = 2
  let radius = 1.0
  draw_debug_sphere_buffered(transform[3], 0.5, color, frames)
  draw_debug_sphere_buffered(transform[3] + transform[0] * radius, 0.1, color, frames)
  draw_debug_sphere_buffered(transform[3] + transform[1] * radius, 0.1, color, frames)
  draw_debug_sphere_buffered(transform[3] + transform[2] * radius, 0.1, color, frames)

  draw_debug_line_buffered(transform[3] + transform[0] * radius, transform[3], E3DCOLOR(0xffff0000), frames)
  draw_debug_line_buffered(transform[3] + transform[1] * radius, transform[3], E3DCOLOR(0xff00ff00), frames)
  draw_debug_line_buffered(transform[3] + transform[2] * radius, transform[3], E3DCOLOR(0xff0000ff), frames)

  let mappedPos = navmesh_map_position(transform[3])
  let mappedUp = navmesh_map_direction(transform[1], transform[3])
  let mappedFwd = navmesh_map_direction(transform[0], transform[3])
  let mappedRight = navmesh_map_direction(transform[2], transform[3])

  draw_debug_sphere_buffered(mappedPos, 0.5, color, frames)
  draw_debug_sphere_buffered(mappedPos + mappedFwd * radius, 0.1, color, frames)
  draw_debug_sphere_buffered(mappedPos + mappedUp * radius, 0.1, color, frames)
  draw_debug_sphere_buffered(mappedPos + mappedRight * radius, 0.1, color, frames)

  draw_debug_line_buffered(mappedPos + mappedFwd * radius, mappedPos, E3DCOLOR(0xffff0000), frames)
  draw_debug_line_buffered(mappedPos + mappedUp * radius, mappedPos, E3DCOLOR(0xff00ff00), frames)
  draw_debug_line_buffered(mappedPos + mappedRight * radius, mappedPos, E3DCOLOR(0xff0000ff), frames)

  draw_debug_line_buffered(mappedPos, transform[3], color, frames)


[console_cmd(name="navmeshmapping.dump_mapping_zones")]
def dump_mapping_zones(path : string)
  using() <| $(var blk : DataBlock)
    query() <| $ [es(REQUIRE=position_mapping__matrix)] (eid : EntityId)
      editor_save_entity(eid, blk)
    datablock_save_to_text_file(blk, path)


def private draw_navmesh_for_mapping_zone(eid : EntityId;
                                          position_mapping__matrix : float3x4;
                                          position_mapping__radius : float)
  var ref : dtPolyRef
  let extents = float3(1.0, 1.0, 1.0)
  var p = position_mapping__matrix[3]
  if project_to_nearest_navmesh_point(p, extents, ref)
    var visited : table<dtPolyRef>
    var newFrontier : table<dtPolyRef>
    var frontier <- { ref }
    let maxRadiusSq = square(position_mapping__radius)
    var depthLeft = 1000
    var area : uint8

    let baseColor = get_debug_zone_color(eid)
    var color = Color4(baseColor)
    color.a = 0.75

    while depthLeft-- > 0
      for f in keys(frontier)
        visited.insert(f)
        get_poly_area(f, area)
        var polyTriangle : NavMeshTriangle
        get_triangle_by_poly(f, polyTriangle)
        if (distance_sq(polyTriangle.p0, position_mapping__matrix[3]) > maxRadiusSq
           || distance_sq(polyTriangle.p1, position_mapping__matrix[3]) > maxRadiusSq
           || distance_sq(polyTriangle.p2, position_mapping__matrix[3]) > maxRadiusSq)
          continue
        let p0 = navmesh_unmap_position_in_zone_forced(polyTriangle.p0, eid)
        let p1 = navmesh_unmap_position_in_zone_forced(polyTriangle.p1, eid)
        let p2 = navmesh_unmap_position_in_zone_forced(polyTriangle.p2, eid)
        draw_debug_triangle_buffered(p0, p1, p2, color, 1)
        for_each_linked_poly(f) <| $(linkedPolyRef)
          if !key_exists(visited, linkedPolyRef) && !key_exists(frontier, linkedPolyRef)
            newFrontier.insert(linkedPolyRef)
      delete frontier
      frontier <- newFrontier
      clear(newFrontier)


[es(tag=(dev, gameClient), no_order)]
def debug_agent_navmeshmapping_information(update : UpdateStageInfoAct;
                                           beh_tree__debug : bool;
                                           transform aka agent_transform : float3x4;
                                           position_mapping__isGoalOnSphere : bool;
                                           position_mapping__isOnSphere : bool;
                                           position_mapping__lastZone : EntityId)
  if !beh_tree__debug
    return

  let message = "on sphere: {position_mapping__isOnSphere}, goal on sphere: {position_mapping__isGoalOnSphere}"
  let drawPosition = agent_transform[3] + 0.5 * agent_transform[1]
  add_debug_text_mark(drawPosition, message, -1, 0., E3DCOLOR(0xffffffff))
  query(position_mapping__lastZone) <| $ [es] (transform aka zone_transform : float3x4)
    draw_debug_line_buffered(drawPosition, zone_transform[3], E3DCOLOR(0xffff0000), 1)
    add_debug_text_mark(zone_transform[3], "zone <{position_mapping__lastZone}>", -1, 0., E3DCOLOR(0xffffffff))


[es(tag=(dev, gameClient), no_order)]
def draw_mapped_navmesh_for_zone(update : UpdateStageInfoAct;
                                 eid : EntityId;
                                 position_mapping__matrix : float3x4;
                                 position_mapping__radius : float;
                                 position_mapping__drawUnmappedNavmesh : bool)
  if !position_mapping__drawUnmappedNavmesh
    return

  draw_navmesh_for_mapping_zone(eid, position_mapping__matrix, position_mapping__radius)


[console_cmd(name="navmeshmapping.find_mostly_overlapping_zones")]
def console_find_mostly_overlapping_zones()
  query() <| $ [es] (transform aka transform1 : float3x4;
                     position_mapping__radius aka position_mapping__radius1 : float;
                     eid aka eid1 : EntityId)
    query() <| $ [es] (transform aka transform2 : float3x4;
                       position_mapping__radius aka position_mapping__radius2 : float;
                       eid aka eid2 : EntityId)
      if uint(eid1) > uint(eid2)
        if distance(transform1[3], transform2[3]) < max(position_mapping__radius1, position_mapping__radius2) * 0.5
          let overlapRatio = distance(transform1[3], transform2[3]) / min(position_mapping__radius1, position_mapping__radius2)
          let msg = "{eid1} and {eid2} overlap ratio {overlapRatio}. coords [{transform1[3]}] [{transform2[3]}]"
          console_print(msg)
          print(msg)
          draw_debug_line_buffered(transform1[3], transform2[3], E3DCOLOR(0xffffffff), 5000)
          draw_debug_sphere_buffered((transform1[3] + transform2[3]) * 0.5, distance(transform1[3], transform2[3]) * 0.5, E3DCOLOR(0xffff5555), 24, 5000)


