require ecs
require ecs.safe
require ecs.common
require game.events.events
require DagorMath
require DagorDebug3D
require strings
require game.es.client.build_mode_common
require game.es.client.build_mode_power_common
require game.es.client.build_mode_preview_common


[es(no_order)]
def power_station_radius_debug(info : UpdateStageInfoAct;
                               transform aka station_transform : float3x4;
                               power_station__range : float)
  if !is_build_mode_active()
    return
  find_query() <| $ [es(REQUIRE=base_build_mode_active_grid)] (transform : float3x4; base_build_mode_grid__yDrawOffset : float)
    let drawHeight = base_build_mode_grid__yDrawOffset + transform[3].y
    var drawPos = station_transform[3]
    drawPos.y = drawHeight
    draw_debug_circle_buffered(drawPos, float3(0, 1, 0), power_station__range, E3DCOLOR(0xff00ffff), int(power_station__range + 1.0) * 5, 1)
    return true


[es(no_order)]
def power_station_connections_debug(info : UpdateStageInfoAct;
                                    transform aka power_station_transform : float3x4;
                                    power_station__connectedBuildingIds : StringList)
  if !is_build_mode_active()
    return
  for id in power_station__connectedBuildingIds
    let controller = find_preview_by_id(string(id))
    query(controller) <| $ [es] (transform aka controller_transform : float3x4)
      draw_debug_arrow_buffered(power_station_transform[3], controller_transform[3], E3DCOLOR(0xFFFFA914), 1)


[es(no_order, REQUIRE=powered_part)]
def reattach_preview_power(info : UpdateStageInfoAct;
                           construction_part__controller : EntityId)
  let isPreview = has(construction_part__controller, "base_build_mode_controller_preview")
  if !isPreview
    return
  var isPowered = false
  // if controller is already powered, then check if it still can be attached to that station
  query(construction_part__controller) <| $ [es] (powered_controller__attachedTo : string)
    let powerStationController = find_preview_by_id(powered_controller__attachedTo)
    let station = get_construction_power_station(powerStationController)
    isPowered = can_attach_power(construction_part__controller, station)
    if !isPowered
      detach_power(construction_part__controller, station)
  if isPowered
    return
  try_power_controller(construction_part__controller)


[es(on_event=CmdUpdateActiveBuildings, on_event=CmdUpdateBasePower, after=update_active_buildings)]
def update_base_power(evt : Event;
                      player_profile__basePower : Object)
  query() <| $ [es(REQUIRE_NOT=base_build_mode_controller_preview, REQUIRE=powered_controller__attachedTo)] (eid : EntityId)
    removeSubTemplate(eid, "powered_controller")

  for it in player_profile__basePower
    let controllerId = it.key
    let stationId = get_string(it.value, "0")
    let controller = find_controller_by_id(controllerId)
    addSubTemplate(controller, "powered_controller") <| $(init)
      set(init, "powered_controller__attachedTo", stationId)


[es(on_disappear, REQUIRE=powered_controller__attachedTo)]
def disable_part_on_depower(evt : Event; eid : EntityId)
  query(eid) <| $ [es] (construction_controller__parts : EidList)
    for part in construction_controller__parts
      query(part) <| $ [es(REQUIRE=powered_part)] (var powered_part__isPowered : bool&)
        powered_part__isPowered = false


[es(on_appear, REQUIRE=powered_controller__attachedTo)]
def enable_part_on_power(evt : Event; eid : EntityId)
  query(eid) <| $ [es] (construction_controller__parts : EidList)
    for part in construction_controller__parts
      query(part) <| $ [es(REQUIRE=powered_part)] (var powered_part__isPowered : bool&)
        powered_part__isPowered = true


[es(track=powered_part__isPowered, on_appear, after=init_powered_building_part)]
def track_console_power(evt : Event;
                        powered_part__isPowered : bool;
                        var use_object__enabled : bool&)
  use_object__enabled = powered_part__isPowered


[es(on_disappear, REQUIRE=power_station)]
def on_power_plant_preview_disappear(evt : Event;
                                     power_station__connectedBuildingIds : StringList)
  query() <| $ [es(REQUIRE=base_build_mode_controller_preview, REQUIRE=powered_controller__attachedTo)] (eid : EntityId;
                                                                                                         construction_controller__instanceId : string)
    if has_value(power_station__connectedBuildingIds, construction_controller__instanceId)
      removeSubTemplate(eid, "powered_controller")


[es(on_appear, REQUIRE=power_station)]
def on_power_plant_preview_appear(evt : Event;
                                  construction_part__controller : EntityId;
                                  var power_station__connectedBuildingIds : StringList)
  query(construction_part__controller) <| $ [es(REQUIRE = base_build_mode_controller_preview)] (construction_controller__instanceId aka construction_controller__instanceIdStation : string)
    query() <| $ [es(REQUIRE=base_build_mode_controller_preview)] (powered_controller__attachedTo : string;
                                                                   construction_controller__instanceId : string)
      if construction_controller__instanceIdStation == powered_controller__attachedTo
        let index = find_index_if(each(power_station__connectedBuildingIds)) <| $(id : das_string)
          return string(id) == construction_controller__instanceId
        if index == -1
          push(power_station__connectedBuildingIds, construction_controller__instanceId)


[es(on_appear, track=powered_part__isPowered, after=init_powered_building_part)]
def track_unpowered_previews(evt : Event; powered_part__isPowered : bool; construction_part__controller : EntityId)
  if !has(construction_part__controller, "base_build_mode_controller_preview")
    return
  find_query() <| $ [es] (var base_build_mode__unpoweredPreviews : EidList)
    let index = find_index(base_build_mode__unpoweredPreviews |> each, construction_part__controller)
    if powered_part__isPowered
      if index != -1
        erase(base_build_mode__unpoweredPreviews, index)
    else
      if index ==  -1
        push(base_build_mode__unpoweredPreviews, construction_part__controller)
    return true


[es(on_appear, REQUIRE=base_build_mode_controller_preview)]
def on_powered_controller_preview_appear(evt : Event;
                                         eid : EntityId;
                                         powered_controller__attachedTo : string)
  let stationController = find_preview_by_id(powered_controller__attachedTo)
  let station = get_construction_power_station(stationController)
  attach_power(eid, station)


// Need EventEntityDestroyed instead of on_disappear
// because detach_power removes powered_controller
// subtemplate and triggers detach again
[es(REQUIRE=base_build_mode_controller_preview)]
def on_powered_controller_preview_disappear(evt : EventEntityDestroyed;
                                            eid : EntityId;
                                            powered_controller__attachedTo : string)
  let stationController = find_preview_by_id(powered_controller__attachedTo)
  let station = get_construction_power_station(stationController)
  detach_power(eid, station)
