options no_aot
require ecs
require math.base
require game.es.ecs_common
require DagorMath
require DagorDebug3D
require DagorSystem
require DagorConsole
require game.es.dev_common
require game.es.human.human_gun_common
require game.utils.net_utils
require game.es.net_console_macro
require game.es.server_debug_common
require game.es.trace_common
require Dacoll
require AnimV20
require GeomNodeTree
require Grid


[es(tag=dev, no_order)]
def draw_dev_tm_trajectory(act : UpdateStageInfoAct;
                           transform : float3x4;
                           draw_tm_trajectory__color : E3DCOLOR;
                           draw_tm_trajectory__duration : int;
                           var draw_tm_trajectory__prevPos : float3&)
  if draw_tm_trajectory__prevPos != transform[3]
    if draw_tm_trajectory__prevPos != float3()
      draw_debug_line_buffered(draw_tm_trajectory__prevPos, transform[3], draw_tm_trajectory__color, draw_tm_trajectory__duration)
    draw_tm_trajectory__prevPos = transform[3]


[es(tag=server, no_order)]
def gather_statistics_on_active_entities(act : UpdateStageInfoAct; var statistics__updateAt : float&; statistics__interval : float)
  if statistics__updateAt < act.curTime
    statistics__updateAt = act.curTime + statistics__interval
    print("Statistics at {act.curTime}. dt: {act.dt}")
    var countActive, countInactive : int

    countActive = 0
    countInactive = 0
    query() <| $ [es(REQUIRE=changed)] (sleeping_monster : Tag const?)
      if sleeping_monster == null
        countActive++
      else
        countInactive++
    print("\tChanged (active, total):\t{countActive}\t{countActive + countInactive}")

    countActive = 0
    countInactive = 0
    query() <| $ [es(REQUIRE=anomaly_trap)] ()
      countActive++
    print("\tTraps:\t{countActive}")

    countActive = 0
    countInactive = 0
    query() <| $ [es(REQUIRE=firefly)] (sleeping_monster : Tag const?)
      if sleeping_monster == null
        countActive++
      else
        countInactive++
    print("\tFirefly (active, total):\t{countActive}\t{countActive + countInactive}")

    countActive = 0
    countInactive = 0
    query() <| $ [es(REQUIRE=item_in_world)] ()
      countActive++
    print("\tItems in world:\t{countActive}")

    var activePhys = 0
    var simplifiedPhys = 0
    var humanPlayer = 0
    var botPlayer = 0
    var totalPhys = 0
    var activeGuards = 0
    var sleepingGuards = 0
    query() <| $ [es(REQUIRE=human_net_phys)] (disableUpdate : Tag const?;
                                               playerIsBot : Tag const?;
                                               heroForPlayer : Tag const?;
                                               encounter_guard : Tag const?;
                                               human_net_phys__isSimplifiedPhys : bool)
      totalPhys++
      if disableUpdate == null
        activePhys++
      if heroForPlayer != null && playerIsBot == null
        humanPlayer++
      if heroForPlayer != null && playerIsBot != null
        botPlayer++
      if human_net_phys__isSimplifiedPhys
        simplifiedPhys++
      if encounter_guard != null && disableUpdate == null
        activeGuards++
      if encounter_guard != null && disableUpdate != null
        sleepingGuards++
    print("\tPlayers (human, bots):\t{humanPlayer}\t{botPlayer}")
    print("\tGuards (active, total):\t{activeGuards}\t{sleepingGuards + activeGuards}")
    print("\tPhys (simplified, active, total):\t{simplifiedPhys}\t{activePhys}\t{totalPhys}")

[es(tag=(gameClient, dev), no_order)]
def draw_draw_me(act : UpdateStageInfoAct; draw_me__color : E3DCOLOR; transform : float3x4)
  draw_debug_circle_buffered(transform[3], transform[0], 0.5 * length(transform[0]), draw_me__color, 4, 1)
  draw_debug_circle_buffered(transform[3], transform[1], 0.5 * length(transform[1]), draw_me__color, 4, 1)
  draw_debug_circle_buffered(transform[3], transform[2], 0.5 * length(transform[2]), draw_me__color, 4, 1)
  draw_debug_line_buffered(transform[3], transform[3] + float3(0, 100, 0), draw_me__color, 1)
  draw_debug_line_buffered(transform[3], transform[3] + normalize(transform[0]), E3DCOLOR(0xffff0000), 1)
  draw_debug_line_buffered(transform[3], transform[3] + normalize(transform[1]), E3DCOLOR(0xff00ff00), 1)
  draw_debug_line_buffered(transform[3], transform[3] + normalize(transform[2]), E3DCOLOR(0xff0000ff), 1)


[es(tag=(gameClient, dev), no_order, REQUIRE=magnet_sphere_debug_draw)]
def magnet_sphere_debug_draw(act : UpdateStageInfoAct;
                             transform aka magnet_sphere_transform : float3x4;
                             sphere_zone__radius : float;
                             magnet_sphere__innerSphereRadiusFactor : float;
                             magnet_sphere__innerPushForce : float)
  find_query() <| $ [es] (camera__active : bool;
                          transform aka camera_transform : float3x4)
    if !camera__active
      return false

    let distSq = distance_sq(magnet_sphere_transform[3], camera_transform[3])
    if distSq >= square(100.0)
      return true

    let innerRadius = sphere_zone__radius * magnet_sphere__innerSphereRadiusFactor

    if magnet_sphere__innerPushForce > 0.0
      draw_debug_sphere_buffered(magnet_sphere_transform[3], innerRadius, E3DCOLOR(0xffff0000), 12, 1)
      draw_debug_sphere_buffered(magnet_sphere_transform[3], sphere_zone__radius, E3DCOLOR(0xffff0000), 12, 1)
    else
      draw_debug_sphere_buffered(magnet_sphere_transform[3], innerRadius, E3DCOLOR(0xff00ff00), 12, 1)
      draw_debug_sphere_buffered(magnet_sphere_transform[3], sphere_zone__radius, E3DCOLOR(0xff00ff00), 12, 1)

    return true


def calculate_gun_total_ammo_for_validation(gun_eid : EntityId;
                                            var out_ammo : int&;
                                            var out_max_ammo : int&)
  var result = false

  query(gun_eid) <| $ [es] (gun__ammo : int;
                            gun__maxAmmo : int;
                            gun_mods__curModInSlots : Object)
    let magazineEid = get_Eid(gun_mods__curModInSlots["magazine"]) ?? INVALID_ENTITY_ID
    if magazineEid != INVALID_ENTITY_ID && isLoadingEntity(magazineEid)
      return

    out_ammo = gun__ammo
    out_max_ammo = gun__maxAmmo
    query(magazineEid) <| $ [es] (item__currentBoxedItemCount : int;
                                  item_holder__maxItemCount : int)
      out_ammo += item__currentBoxedItemCount
      out_max_ammo += item_holder__maxItemCount
      result = true

  return result


def validate_gun_ammo(gun_eid : EntityId;
                      event_name : string = "")
  query(gun_eid) <| $ [es] (gun__ammo : int;
                            gun__maxAmmo : int;
                            gun__owner : EntityId;
                            gun_mods__curModInSlots : Object)
    var totalAmmo : int
    var totalMaxAmmo : int
    if !calculate_gun_total_ammo_for_validation(gun_eid, totalAmmo, totalMaxAmmo)
      return

    if totalAmmo > totalMaxAmmo
      logerr("[DEV] Gun ammo overflow!
gun_eid={get_entity_info(gun_eid)}
evt={event_name}
totalAmmo={totalAmmo}
totalMaxAmmo={totalMaxAmmo}
gun__ammo={gun__ammo}
gun__maxAmmo={gun__maxAmmo}
magazineEid={get_entity_info(get_Eid(gun_mods__curModInSlots["magazine"]) ?? INVALID_ENTITY_ID)}
gun_owner={get_entity_info(gun__owner)}")


[es(tag=(dev, server), track=gun__ammo, on_appear, REQUIRE=(gun__ammo, gun__maxAmmo))]
def dev_validate_gun_ammo(evt : Event;
                          eid : EntityId)
  validate_gun_ammo(eid, evt.eventName)


[es(tag=(dev, server), track=item__currentBoxedItemCount, on_appear)]
def dev_validate_current_boxed_item_count(evt : Event;
                                          eid : EntityId;
                                          item__currentBoxedItemCount : int;
                                          item_holder__maxItemCount : int;
                                          item__containerOwnerEid : EntityId = INVALID_ENTITY_ID;
                                          item__humanOwnerEid : EntityId = INVALID_ENTITY_ID;
                                          item__lastContainerOwnerEid :  EntityId = INVALID_ENTITY_ID;
                                          slot_attach__attachedTo : EntityId = INVALID_ENTITY_ID)
  if item_holder__maxItemCount != -1 && item__currentBoxedItemCount > item_holder__maxItemCount
    logerr("[DEV] {get_entity_info(eid)}: Item count overflow!
event={evt.eventName}
slot_attach__attachedTo={get_entity_info(slot_attach__attachedTo)}
item__currentBoxedItemCount={item__currentBoxedItemCount}
item_holder__maxItemCount={item_holder__maxItemCount}
item__containerOwnerEid={get_entity_info(item__containerOwnerEid)}
item__humanOwnerEid={get_entity_info(item__humanOwnerEid)}
item__lastContainerOwnerEid={get_entity_info(item__lastContainerOwnerEid)}")

  query(slot_attach__attachedTo) <| $ [es] (gun__ammo : int)
    var totalAmmo : int
    var totalMaxAmmo : int
    if !calculate_gun_total_ammo_for_validation(slot_attach__attachedTo, totalAmmo, totalMaxAmmo)
      return

    if totalAmmo > totalMaxAmmo
      logerr("[DEV] {get_entity_info(eid)}: Gun with attached magazine ammo overflow!
event={evt.eventName}
totalAmmo={totalAmmo}
totalMaxAmmo={totalMaxAmmo}
slot_attach__attachedTo={get_entity_info(slot_attach__attachedTo)}
gun__ammo={gun__ammo}
item__currentBoxedItemCount={item__currentBoxedItemCount}
item_holder__maxItemCount={item_holder__maxItemCount}
item__containerOwnerEid={get_entity_info(item__containerOwnerEid)}
item__humanOwnerEid={get_entity_info(item__humanOwnerEid)}
item__lastContainerOwnerEid={get_entity_info(item__lastContainerOwnerEid)}")


[console_cmd(name="am.test_client_human_cam_magnification_curve_affect")]
def console_test_client_human_cam_magnification_curve_affect()
  query() <| $ [es(REQUIRE=hero)] (eid : EntityId)
    createEntity("client_human_cam_magnification_curve_affect") <| $(var init : ComponentsInitializer)
      init |> set("game_effect__attachedTo", eid)


struct AmSourceData
  eid : EntityId
  am : int
  amFactor : float


[console_cmd(name="resources_gatherer.debug_log")]
def am_pile_debug_log_cmd()
  query() <| $ [es(REQUIRE=hero)] (eid aka hero_eid : EntityId)
    print("[RESOURCES GATHERER] DEBUG!")
    query(hero_eid) <| $ [es] (resources_gatherer_hero__enabled : bool;
                               resources_gatherer__eid : EntityId;
                               human_inventory__entityToUse : EntityId;
                               human_use_object__selectedObject : EntityId;
                               human_input__use : int;
                               resources_gatherer_hero_debug : Tag const?)

      print(
"resources_gatherer_hero__enabled={resources_gatherer_hero__enabled}
resources_gatherer__eid={get_entity_info(resources_gatherer__eid)}
human_inventory__entityToUse ={get_entity_info(human_inventory__entityToUse)}
human_use_object__selectedObject ={get_entity_info(human_use_object__selectedObject)}
human_input__use={human_input__use}
resources_gatherer_hero_debug={resources_gatherer_hero_debug}")

      if (resources_gatherer_hero_debug == null)
        addSubTemplate(hero_eid, "resources_gatherer_hero_debug")

      query(resources_gatherer__eid) <| $ [es] (resources_gatherer_device__tickAt : float)
        print(
"resources_gatherer_device__tickAt={resources_gatherer_device__tickAt}")

    if !is_server()
      exec_server_cmd("resources_gatherer.debug_log_server {eid}")


[console_cmd(name="resources_gatherer.debug_log_server")]
def am_pile_debug_log_cmd_server(hero_eid : int)
  let heroEid = EntityId(uint(hero_eid))
  query(heroEid) <| $ [es] (resources_gatherer__eid : EntityId;
                            animchar : AnimcharBaseComponent;
                            resources_gatherer_hero__enabled : bool;
                            resources_gatherer_hero__nodeIdx : int;
                            human__aimTm : float3x4;
                            am_storage__maxValue : int;
                            team aka owner_team : int = TEAM_UNASSIGNED;
                            am_storage__value : int;
                            resources_gatherer_hero_debug : Tag const?)
    if (resources_gatherer_hero_debug == null)
      addSubTemplate(heroEid, "resources_gatherer_hero_debug")

    query(resources_gatherer__eid) <| $ [es] (resources_gatherer_device__affectEid : EntityId;
                                              resources_gatherer_device__range : float;
                                              resources_gatherer_device__coneAngleCos : float;
                                              resources_gatherer_device__pointBlankDist : float;
                                              resources_gatherer_device__gatherRatePerTick : float;
                                              resources_gatherer_device__gatherMultiplier : float;
                                              resources_gatherer_device__tickAt : float)
      var nodeTm : float3x4
      geomtree_getNodeWtmScalar(*animchar.nodeTree, resources_gatherer_hero__nodeIdx, nodeTm)
      let sphere = BSphere3(nodeTm[3], resources_gatherer_device__range)

      var amSources : array<AmSourceData>
      var totalAvailableForGatherAm = 0.0
      for_each_entity_in_grid(ecs_hash("loot"), sphere, GridEntCheck.POS) <| $ [unused_argument(pos)] (loot_eid : EntityId; pos : float3)
        query(loot_eid) <| $ [es(REQUIRE=item__am)] (transform aka am_transform : float3x4;
                                                     active_matter_pile__locked : bool;
                                                     item__count : int;
                                                     am_pile__visualItemPosOffset : float3 = float3(0, 0, 0))
          if active_matter_pile__locked
            print("[RESOURCES GATHERER] loot am source unavailable:
eid={get_entity_info(loot_eid)}
active_matter_pile__locked={active_matter_pile__locked}")
            return

          let amTracePos = am_transform[3] + rotate(am_transform, am_pile__visualItemPosOffset)
          let tracePos = nodeTm[3]
          let traceRay = amTracePos - nodeTm[3]
          let traceRayDist = length(traceRay)
          let traceRayDir = traceRay * safeinv(traceRayDist)
          let isRayAngleValid = dot(human__aimTm[0], traceRayDir) > resources_gatherer_device__coneAngleCos
          let isPointBlankDist = traceRayDist < resources_gatherer_device__pointBlankDist

          let traceResult = traceray_exclude_non_phys_collidable(tracePos, traceRayDir, traceRayDist, ETF_RI)

          if (isRayAngleValid || isPointBlankDist) && !traceResult
            if item__count > 0
              amSources |> push(AmSourceData(eid = loot_eid, am = item__count))
              totalAvailableForGatherAm += float(item__count)
            else
              print("[RESOURCES GATHERER] loot am source unavailable:
eid={get_entity_info(loot_eid)}
item__count={item__count}")
          else
            print("[RESOURCES GATHERER] loot am source unavailable:
eid={get_entity_info(loot_eid)}
isRayAngleValid={isRayAngleValid}
isPointBlankDist={isPointBlankDist}
traceResult={traceResult}
tracePos={tracePos}
am_transform={am_transform}
amTracePos={amTracePos}")

      for_each_entity_in_grid(ecs_hash("interactable"), sphere, GridEntCheck.POS) <| $ [unused_argument(pos)] (interactable_eid : EntityId; pos : float3)
        query(interactable_eid) <| $ [es] (active_matter_pile_provider__amSourceEid : EntityId;
                                           active_matter_pile_provider__team : int = TEAM_UNASSIGNED)
          if active_matter_pile_provider__team == TEAM_UNASSIGNED || active_matter_pile_provider__team == owner_team
            query(active_matter_pile_provider__amSourceEid) <| $ [es] (am_storage__value : int)
              if am_storage__value > 0
                amSources |> push(AmSourceData(eid = interactable_eid, am = am_storage__value))
                totalAvailableForGatherAm += float(am_storage__value)
              else
                print("[RESOURCES GATHERER] interactable am source unavailable:
eid={get_entity_info(interactable_eid)}
am_storage__value={am_storage__value}")
          else
            print("[RESOURCES GATHERER] interactable am source unavailable:
eid={get_entity_info(interactable_eid)}
active_matter_pile_provider__team={active_matter_pile_provider__team}
owner_team={owner_team}")


      let gatherRate = resources_gatherer_device__gatherRatePerTick * resources_gatherer_device__gatherMultiplier
      let gatherLeft = ceili(gatherRate)
      let amStorageCapacityLeft = am_storage__maxValue - am_storage__value

      if length(amSources) > 0
        for amSource in amSources
          amSource.amFactor = float(amSource.am) / totalAvailableForGatherAm
        sort(amSources) <| $(lhs, rhs : AmSourceData)
          return lhs.am < rhs.am


      print("[RESOURCES GATHERER]
hero={get_entity_info(heroEid)}
resources_gatherer__eid={get_entity_info(resources_gatherer__eid)}
resources_gatherer_device__affectEid={get_entity_info(resources_gatherer_device__affectEid)}
resources_gatherer_hero__enabled={resources_gatherer_hero__enabled}
resources_gatherer_device__tickAt={resources_gatherer_device__tickAt}
resources_gatherer_device__gatherMultiplier={resources_gatherer_device__gatherMultiplier}
am_storage__value={am_storage__value}
amStorageCapacityLeft={amStorageCapacityLeft}
gatherLeft={gatherLeft}
totalAvailableForGatherAm={totalAvailableForGatherAm}
amSources={amSources}")

      for amSource in amSources
        query(amSource.eid) <| $ [es] (item__count : int const?;
                                       active_matter_pile_provider__amSourceEid : EntityId const?;
                                       transform aka am_transform : float3x4 const?)
          print("[AM SOURCE]
eid={get_entity_info(amSource.eid)}
item__count={item__count}
active_matter_pile_provider__amSourceEid={active_matter_pile_provider__amSourceEid}
am_transform={am_transform}")