options no_aot
require app
require ecs
require ecs.safe
require net
require game.utils.net_utils
require game.es.ecs_common
require DagorConsole
require DagorDataBlock
require Grid
require DngWalkerai
require BehNodes
require pathfinder
require game.es.net_console_macro
require game.events.events_active_matter
require game.es.nesting_swarm_common
require game.es.monster_common


[net_console_cmd(name="invisible_man.test_invisibility")]
def invisible_man_test_invis_cmd(invisible : bool = true)
  query() <| $ [es(REQUIRE=invisibleMan)] (var another_dimension_visitor__inside : bool&)
    another_dimension_visitor__inside = invisible


[console_cmd(name="stalker_statue.death_vfx_test")]
def stalker_statue_death_vfx_test(value : bool = true)
  query() <| $ [es(REQUIRE=stalker_statue_death_vfx_test)] (eid aka stalker_statue_eid : EntityId;
                                                            stalker_statue_death_vfx_test__effect : string;
                                                            var animchar_render__enabled : bool&)
    animchar_render__enabled = true

    if value
      createEntity(stalker_statue_death_vfx_test__effect) <| $(var init : ComponentsInitializer)
        init |> set("game_effect__attachedTo", stalker_statue_eid)


[net_console_cmd(name="flowerhuman.debug_log")]
def flowerhuman_debug_log_cmd(@net_hero eid : EntityId)
  var affectedCount = 0
  query(eid) <| $ [es] (transform aka hero_transform : float3x4)
    let sphere = BSphere3(hero_transform[3], 9.0)
    for_each_entity_in_grid(ecs_hash("humans"), sphere, GridEntCheck.BOUNDING) <| $(human_eid : EntityId)
      query(human_eid) <| $ [es(REQUIRE=flowerHuman, REQUIRE_NOT=(flower_human_debug_log, deadEntity))]
        addSubTemplate(human_eid, "flower_human_debug_log") <| $(var init : ComponentsInitializer)
          init |> set("flower_human_debug_log__heroEid", eid)
        ++affectedCount
  console_print("Affected {affectedCount} flowerhumans")
  send_net_event(eid, CmdHeroLogExEvent(event = "", key = "Affected {affectedCount} flowerhumans"), target_entity_conn(eid))


[es(tag=server, REQUIRE=flower_human_debug_log, REQUIRE_NOT=deadEntity, no_order)]
def flower_human_debug_log_server(act : UpdateStageInfoAct;
                                  eid : EntityId;
                                  transform : float3x4;
                                  beh_tree__enabled : bool;
                                  beh_tree : BehaviourTree;
                                  isAlive : bool;
                                  walker_agent__potentialTargetEid : EntityId;
                                  walker_agent__targetEid : EntityId;
                                  walker_agent__targetPos : float3;
                                  flower_human_debug_log__heroEid : EntityId;
                                  navmesh_phys__climbJumpMaxUpHeight : float const?;
                                  sleep_mode_preparing_for_sleep_server_sleepAt : float const?;
                                  sleep_mode_preparing_for_sleep_server_sleepDelay : float const?;
                                  sleep_mode__triggered : bool;
                                  sleep_mode__isSleeping : bool;
                                  sleep_mode__firstWakeUp : bool;
                                  sleep_mode__nextUpdateAt : float;
                                  sleep_mode__triggerPoint : float3;
                                  sleeping_monster : Tag const?)
  let extents = float3(1)
  let resPath = find_path(transform[3], walker_agent__targetPos, extents, 1.0, 1.0)

  var checkPathRes = false
  using(transform[3], walker_agent__targetPos, extents) <| $(var req : FindRequest#)
    if navmesh_phys__climbJumpMaxUpHeight != null
      req.includeFlags |= int(PolyFlag.POLYFLAG_JUMP)
    req.maxJumpUpHeight = navmesh_phys__climbJumpMaxUpHeight ?? 0.f
    checkPathRes = check_path(req, extents.x, extents.x)


  var behState = beh_tree__enabled ? beh_tree |> beh_tree_current_name(true) : "<N/A>"

  if beh_tree__enabled
    if beh_tree.changeNodeReason != null
      let changeNodeReason = (*beh_tree.changeNodeReason) |> beh_node_hierarchy_name(true)
      behState = "{behState}; changeNodeReason={changeNodeReason}"
    if beh_tree.resetReason != null
      let resetReason = (*beh_tree.resetReason) |> beh_node_hierarchy_name(true)
      behState = "{behState}; resetReason={resetReason}"


  print("[FLOWERHUMAN]
eid = {get_entity_info(eid)}
heroEid = {get_entity_info(flower_human_debug_log__heroEid)}
curTime = {act.curTime}
pos = {transform[3]}
beh_tree__enabled = {beh_tree__enabled}
isAlive = {isAlive}
walker_agent__potentialTargetEid = {get_entity_info(walker_agent__potentialTargetEid)}
walker_agent__targetEid = {get_entity_info(walker_agent__targetEid)}
walker_agent__targetPos = {walker_agent__targetPos}
beh = {behState}
sleeping_monster = {sleeping_monster}
sleep_mode_preparing_for_sleep_server_sleepAt = {sleep_mode_preparing_for_sleep_server_sleepAt}
sleep_mode_preparing_for_sleep_server_sleepDelay = {sleep_mode_preparing_for_sleep_server_sleepDelay}
sleep_mode__triggered = {sleep_mode__triggered}
sleep_mode__triggerPoint = {sleep_mode__triggerPoint}
sleep_mode__isSleeping = {sleep_mode__isSleeping}
sleep_mode__firstWakeUp = {sleep_mode__firstWakeUp}
sleep_mode__nextUpdateAt = {sleep_mode__nextUpdateAt}
resPath (pos -> targetPos) = {resPath}
checkPathRes = {checkPathRes}")


[net_console_cmd(name="wormhuman.debug_log")]
def wormhuman_debug_log_cmd(@net_hero eid : EntityId)
  var affectedCount = 0
  query(eid) <| $ [es] (transform aka hero_transform : float3x4)
    let sphere = BSphere3(hero_transform[3], 25.0)
    for_each_entity_in_grid(ecs_hash("humans"), sphere, GridEntCheck.BOUNDING) <| $(human_eid : EntityId)
      query(human_eid) <| $ [es(REQUIRE=nesting_swarm_nest, REQUIRE_NOT=(wormhuman_debug_log, deadEntity))]
        addSubTemplate(human_eid, "wormhuman_debug_log") <| $(var init : ComponentsInitializer)
          init |> set("wormhuman_debug_log__heroEid", eid)
        ++affectedCount
  console_print("Affected {affectedCount} wormhumans")
  send_net_event(eid, CmdHeroLogExEvent(event = "", key = "Affected {affectedCount} wormhumans"), target_entity_conn(eid))


[es(tag=server, REQUIRE=wormhuman_debug_log, REQUIRE_NOT=deadEntity, no_order)]
def wormhuman_debug_log_server(act : UpdateStageInfoAct;
                               eid : EntityId;
                               transform aka nest_transform : float3x4;
                               isAlive aka nest_isAlive : bool;
                               nesting_swarm_nest__warriorEid : EntityId;
                               wormhuman_debug_log__heroEid : EntityId)
  var warrionText = ""

  query(nesting_swarm_nest__warriorEid) <| $ [es] (beh_tree__enabled : bool;
                                                   beh_tree : BehaviourTree;
                                                   isAlive aka snake_isAlive : bool = true;
                                                   transform aka snake_transform : float3x4;
                                                   nesting_swarm_snake__targetPos : float3;
                                                   nesting_swarm_snake__targetSavedPos : float3;
                                                   nesting_swarm_snake__state : int;
                                                   nesting_swarm_snake__requiredSpeed : float;
                                                   swarm_warrior__primaryNest : EntityId;
                                                   swarm_warrior__investigationsLeft : int;
                                                   swarm_warrior__targetPos : float3;
                                                   swarm_warrior__teleportDesire : float;
                                                   walker_agent__targetEid : EntityId;
                                                   flyer__wishLookDir : float3;
                                                   flyer__velocityDir : float3;
                                                   nesting_swarm_snake__collisionSpeedCurrentSlowdown : float)
    var behState = beh_tree__enabled ? beh_tree |> beh_tree_current_name(true) : "<N/A>"

    if beh_tree__enabled
      if beh_tree.changeNodeReason != null
        let changeNodeReason = (*beh_tree.changeNodeReason) |> beh_node_hierarchy_name(true)
        behState = "{behState}; changeNodeReason={changeNodeReason}"
      if beh_tree.resetReason != null
        let resetReason = (*beh_tree.resetReason) |> beh_node_hierarchy_name(true)
        behState = "{behState}; resetReason={resetReason}"

    let bestTarget = find_nesting_swarm_snake_best_target(nesting_swarm_nest__warriorEid, 25.0)

    let distanceToNest = distance(nest_transform[3], snake_transform[3])

    warrionText = "behState={behState}
warriorBlackboard=[
{string(beh_tree.blackBoard)}
]
isAlive={snake_isAlive}
swarm_warrior__primaryNest={get_entity_info(swarm_warrior__primaryNest)}
distanceToNest={distanceToNest}
swarm_warrior__investigationsLeft={swarm_warrior__investigationsLeft}
swarm_warrior__targetPos={swarm_warrior__targetPos}
swarm_warrior__teleportDesire={swarm_warrior__teleportDesire}
snake_transform={snake_transform}
nesting_swarm_snake__targetPos={nesting_swarm_snake__targetPos}
nesting_swarm_snake__targetSavedPos={nesting_swarm_snake__targetSavedPos}
nesting_swarm_snake__state={nesting_swarm_snake__state}
nesting_swarm_snake__requiredSpeed={nesting_swarm_snake__requiredSpeed}
nesting_swarm_snake__collisionSpeedCurrentSlowdown={nesting_swarm_snake__collisionSpeedCurrentSlowdown}
walker_agent__targetEid={get_entity_info(walker_agent__targetEid)}
bestTarget={get_entity_info(bestTarget)}
flyer__wishLookDir={flyer__wishLookDir}
flyer__velocityDir={flyer__velocityDir}"


  print("[WORMHUMAN]
eid = {get_entity_info(eid)}
heroEid = {get_entity_info(wormhuman_debug_log__heroEid)}
curTime = {act.curTime}
nest_transform = {nest_transform}
isAlive = {nest_isAlive}
nesting_swarm_nest__warriorEid={get_entity_info(nesting_swarm_nest__warriorEid)}
[WARRIOR DATA]
{warrionText}")