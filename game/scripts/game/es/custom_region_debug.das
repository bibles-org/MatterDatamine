options no_aot
require ecs
require Dacoll
require math.base
require DagorDebug3D
require DagorConsole
require ecs.extra_set
require DagorDebug3DSolid
require DagorFiles
require DagorDataBlock
require gameObject
require level
require danetlibs.console_commands.main.console_common


def private clear_region_creation_points()
  query() <| $ [es(REQUIRE=region_creation_point__idx)] (eid : EntityId)
    destroyEntity(eid)


def private point3D(point : float2)
  return float3(point.x, traceht_lmesh(point), point.y)


def private draw_region(custom_region__points : Point2List)
  let addHeight = float3(0.0, 50.0, 0.0)
  let fillColor = E3DCOLOR(0x775555ff)
  let borderColor = E3DCOLOR(0xaaaaaaff)

  for i in iter_range(custom_region__points)
    assume points = custom_region__points
    let next = (i + 1) % length(points)
    draw_debug_quad_buffered(
      point3D(points[i]), point3D(points[next]),
      point3D(points[next]) + addHeight, point3D(points[i]) + addHeight,
      fillColor, 1)
    draw_debug_line_buffered(point3D(points[i]), point3D(points[i]) + addHeight, borderColor, 1)
    draw_debug_line_buffered(point3D(points[i]), point3D(points[next]) + addHeight, borderColor, 1)


[console_cmd(name="region.draw_region")]
def region_draw_region(region_name : string = ""; duration = 5000)
  var regionEid = INVALID_ENTITY_ID
  if empty(region_name)
    query() <| $ [es] (camera__active : bool; transform aka camera_transform : float3x4)
      if camera__active
        var bestDstSq = FLT_MAX
        query() <| $ [es(REQUIRE=custom_region__name)] (eid : EntityId; transform : float3x4)
          let dstSq = distance_sq(transform[3], camera_transform[3])
          if dstSq < bestDstSq
            bestDstSq = dstSq
            regionEid = eid
  else
    find_query() <| $ [es] (eid : EntityId; custom_region__name : string)
      if custom_region__name == region_name
        regionEid = eid
        return true
      return false

  query(regionEid) <| $ [es] (custom_region__name : string; custom_region__points : Point2List)
    console_print("Drawing region: {custom_region__name}")
    draw_region(custom_region__points)


[es(tag=dev, no_order, REQUIRE=daeditor__selected)]
def draw_debug_region(evt : UpdateStageInfoRenderDebug; custom_region__points : Point2List)
  draw_region(custom_region__points)


[console_cmd(name="region.edit_region")]
def region_edit_region(region_name : string = "")
  var regionToEdit = INVALID_ENTITY_ID
  if empty(region_name)
    find_query() <| $ [es(REQUIRE=(daeditor__selected, custom_region__points))] (eid : EntityId)
      regionToEdit = eid
      return true
    if regionToEdit == INVALID_ENTITY_ID
      console_print("No region name specified or region selected. Disable edit mode.")
      clear_region_creation_points()
      return
  else
    find_query() <| $ [es] (custom_region__name : string; eid : EntityId)
      if custom_region__name == region_name
        regionToEdit = eid
        return true
      return false
    if regionToEdit == INVALID_ENTITY_ID
      console_print("Error: Region not found: {region_name}.")
      clear_region_creation_points()
      return

  query(regionToEdit) <| $ [es] (custom_region__points : Point2List)
    console_print("Editing points for region: {region_name}.")
    clear_region_creation_points()
    var idx = 0
    for point in custom_region__points
      createEntity("region_creation_point") <| $(var init)
        var tm = IDENT_TM
        tm[3] = point3D(point)
        init |> set("transform", tm)
        init |> set("region_creation_point__idx", idx)
      idx += 100


[console_cmd(name="region.add_region")]
def region_add_region(region_name : string; show_on_map = false; filename = "region.txt")
  if empty(region_name)
    console_print("Error: Empty region name.")
    return
  var points : array<tuple<int; float2>>
  query() <| $ [es] (region_creation_point__idx : int; transform : float3x4)
    points |> push((region_creation_point__idx, float2(transform[3].x, transform[3].z)))
  points |> sort() <| $(a, b)
    return a._0 < b._0
  var pointCoords : array<float2>
  for point in points
    pointCoords |> push(point._1)
  if length(points) < 3
    console_print("Error: Region must contain at lease 3 points, now: {length(points)}.")
    return

  let regionType = show_on_map ? "custom_region_on_map" : "custom_region"
  if filename != ""
    df_open(filename, DF_WRITE | DF_APPEND) <| $(outputFile)
      outputFile |> df_puts("entity\{\n")
      outputFile |> df_puts("  _template:t=\"{regionType}\"\n")
      outputFile |> df_puts("  custom_region__name:t=\"{region_name}\"\n")
      outputFile |> df_puts("  \"custom_region__points:list<p2>\"\{\n")
      for point in pointCoords
        outputFile |> df_puts("    p:p2={point}\n")
      outputFile |> df_puts("  \}\n")
      outputFile |> df_puts("\}\n\n")
    console_print("Region <{region_name}> added to <{filename}>.")
  clear_region_creation_points()

  find_query() <| $ [es] (eid : EntityId; custom_region__name : string)
    if custom_region__name == region_name
      destroyEntity(eid)
      return true
    return false
  createEntity(regionType) <| $(var init)
    init |> set("custom_region__name", region_name)
    init |> set("custom_region__points", pointCoords)


[es(tag=dev, on_appear)]
def region_creation_point_appear(evt : Event; var region_creation_point__idx : int&)
  var maxId = -1
  var selectedIdx = -1
  query() <| $ [es(REQUIRE=daeditor__selected)] (region_creation_point__idx : int)
    selectedIdx = region_creation_point__idx
  if selectedIdx == -1
    query() <| $ [es] (region_creation_point__idx : int)
      maxId = max(maxId, region_creation_point__idx)
  else
    maxId = selectedIdx
  region_creation_point__idx = maxId + 1


[es(tag=dev, no_order)]
def draw_creation_point_region(act : UpdateStageInfoRenderDebug)
  var points : array<tuple<int; float3>>
  query() <| $ [es] (region_creation_point__idx : int; var transform : float3x4&; daeditor__selected : Tag const?)
    points |> push((region_creation_point__idx, transform[3]))
    if daeditor__selected != null
      transform[3] = point3D(float2(transform[3].x, transform[3].z))
  points |> sort() <| $(a, b)
    return a._0 < b._0
  if length(points) < 3
    return
  let color = E3DCOLOR(0xffffffff)
  let upOffset = float3(0.0, 10.0, 0.0)
  for i in iter_range(points)
    let endIdx = i == length(points) - 1 ? 0 : i + 1
    draw_debug_quad_buffered(points[i]._1 + upOffset, points[i]._1, points[endIdx]._1, points[endIdx]._1 + upOffset, color, 1)
