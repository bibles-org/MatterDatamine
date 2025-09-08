require ecs
require ecs.safe
require app
require math.base
require game.utils.team
require DngHuman
require HumanPhys
require DagorMath
require Grid
require BehNodes
require Dacoll
require PhysMat
require game.es.ai.agent_position_mapping_common


[es(tag=server, on_appear)]
def command_attack_ability_appear(evt : Event;
                                  command_attack_ability__traceRayMat : string;
                                  var command_attack_ability__traceRayMatId : int&)
  command_attack_ability__traceRayMatId = get_material_id(command_attack_ability__traceRayMat)


def destroy_all_walk_marks(owner : EntityId)
  query() <| $ [es] (eid aka minion_walk_mark_eid : EntityId;
                     minion_walk_mark__owner : EntityId)
    if minion_walk_mark__owner == owner
      destroyEntity(minion_walk_mark_eid)


def create_minion_walk_mark(owner : EntityId;
                            pos : float3)
  createEntity("minion_walk_mark") <| $(var init : ComponentsInitializer)
    var tm = IDENT_TM
    tm[3] = pos
    init |> set("transform", tm)
    init |> set("minion_walk_mark__owner", owner)


def destroy_all_attack_marks(owner : EntityId)
  query() <| $ [es] (eid aka minion_attack_mark_eid : EntityId;
                     minion_attack_mark__owner : EntityId)
    if minion_attack_mark__owner == owner
      destroyEntity(minion_attack_mark_eid)


def reset_minion_beh_trees(master_eid : EntityId)
  query() <| $ [es] (eid aka minion_eid : EntityId;
                     minion_creature__masterEid : EntityId;
                     beh_tree__interruptDisabled : bool = false;
                     var beh_tree : BehaviourTree)
    if minion_creature__masterEid == master_eid
      if beh_tree__interruptDisabled
        createEntitySync("beh_tree_interrupter") <| $(var init : ComponentsInitializer)
          init |> set("beh_tree_interrupter__target", minion_eid)
      else
        beh_tree_reset(beh_tree)


[es(tag=server, no_order)]
def beh_tree_interrupter(act : UpdateStageInfoAct;
                         eid aka interrtupter_eid : EntityId;
                         beh_tree_interrupter__target : EntityId)
  var destroyInterrupter = true
  query(beh_tree_interrupter__target) <| $ [es] (beh_tree__interruptDisabled : bool = false;
                                                 var beh_tree : BehaviourTree&)
    if beh_tree__interruptDisabled
      destroyInterrupter = false
    else
      beh_tree_reset(beh_tree)

  if destroyInterrupter
    destroyEntity(interrtupter_eid)


[es(tag=server, on_appear, REQUIRE=monster_changed_command_attack_affect)]
def command_attack_affect_on_appear(evt : Event;
                                    game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (human_net_phys : HumanActor;
                                            team aka master_team : int;
                                            command_attack_ability__traceBackwardOffset : float = 0.3;
                                            command_attack_ability__traceRayMatId : int;
                                            command_attack_ability__traceDist : float;
                                            command_attack_ability__traceEnemyMinDot : float)

    assume curState = human_net_phys.phys.currentState
    assume phys = human_net_phys.phys

    var minionEids : array<EntityId>
    query() <| $ [es] (eid aka minion_eid : EntityId;
                       minion_creature__masterEid : EntityId)
      if minion_creature__masterEid == game_effect__attachedTo
        minionEids |> push(minion_eid)

    if length(minionEids) == 0
      return

    var locationTm : float3x4
    location_toTM(curState.location, locationTm)

    var gunTM : float3x4
    human_phys_calcGunTm(human_net_phys.phys, PrecomputedPresetMode.TPV, locationTm, curState.gunAngles.y, curState.leanPosition, curState.height, gunTM)

    let traceDir = gunTM[0]
    let tracePos = gunTM[3] - (traceDir * command_attack_ability__traceBackwardOffset)

    var targetEnemyEid = INVALID_ENTITY_ID
    var targetEnemyDot = command_attack_ability__traceEnemyMinDot

    let enemiesSpherePos = tracePos + traceDir * command_attack_ability__traceDist * 0.5
    let enemiesSphere = BSphere3(enemiesSpherePos, command_attack_ability__traceDist * 0.5)
    for_each_entity_in_grid(ecs_hash("humans"), enemiesSphere, GridEntCheck.BOUNDING) <| $(enemy_eid : EntityId;
                                                                                           enemy_pos : float3)
      query(enemy_eid) <| $ [es(REQUIRE_NOT=deadEntity)] (team aka enemy_team : int)
        if is_teams_friendly(master_team, enemy_team)
          return

        let toEnemy = enemy_pos - tracePos
        let toEnemyLenSq = length_sq(toEnemy)
        if toEnemyLenSq > VERY_SMALL_NUMBER
          let toEnemyLen = sqrt(toEnemyLenSq)
          let toEnemyDir = toEnemy / toEnemyLen

          let enemyDot = dot(toEnemyDir, traceDir)
          if enemyDot > targetEnemyDot
            targetEnemyDot = enemyDot
            targetEnemyEid = enemy_eid

    destroy_all_walk_marks(game_effect__attachedTo)
    if targetEnemyEid != INVALID_ENTITY_ID

      let enemyHasAttackMark = find_query() <| $ [es] (minion_attack_mark__owner : EntityId;
                                                       minion_attack_mark__target : EntityId;
                                                       minion_attack_mark__removeTimeout : float;
                                                       var minion_attack_mark__piority : int&;
                                                       var minion_attack_mark__removeAt : float&)
        if minion_attack_mark__owner != game_effect__attachedTo || minion_attack_mark__target != targetEnemyEid
          return false

        if minion_attack_mark__piority < 2
          minion_attack_mark__piority++
        minion_attack_mark__removeAt = get_sync_time() + minion_attack_mark__removeTimeout
        return true

      if !enemyHasAttackMark
        createEntitySync("minion_attack_mark") <| $ [es] (var init : ComponentsInitializer)
          init |> set("minion_attack_mark__owner", game_effect__attachedTo)
          init |> set("minion_attack_mark__target", targetEnemyEid)

      // Decrease priority of all other marks
      query() <| $ [es] (minion_attack_mark__owner : EntityId;
                         minion_attack_mark__target : EntityId;
                         var minion_attack_mark__piority : int&)
        if minion_attack_mark__owner != game_effect__attachedTo || minion_attack_mark__target == targetEnemyEid
          return

        if minion_attack_mark__piority > 0
          --minion_attack_mark__piority

      reset_minion_beh_trees(game_effect__attachedTo)
    else

      destroy_all_attack_marks(game_effect__attachedTo)

      for minionEid in minionEids
        query(minionEid) <| $ [es] (var walker_agent__targetEid : EntityId&;
                                    var minion_creature__lastDangerEid : EntityId&)
          walker_agent__targetEid = INVALID_ENTITY_ID
          minion_creature__lastDangerEid = INVALID_ENTITY_ID


      // There is no enemy - place walk
      var t = command_attack_ability__traceDist
      var norm : float3
      var pmid = -1
      var riDesc = RendInstDesc()

      traceray_normalized(tracePos, traceDir, t, pmid, norm, ETF_ALL, riDesc, command_attack_ability__traceRayMatId)
      var pos = tracePos + traceDir * t

      if project_to_nearest_navmesh_point_with_navmesh_mapping(pos, float3(5.0))
        create_minion_walk_mark(game_effect__attachedTo, pos)


[es(tag=server, no_order)]
def minion_walk_mark_update(act : UpdateStageInfoAct;
                            eid aka minion_walk_mark_eid : EntityId;
                            minion_walk_mark__owner : EntityId;
                            minion_walk_mark__updateInterval : float = 0.5;
                            minion_walk_mark__distToDestroySq : float;
                            transform aka mark_transform : float3x4;
                            var minion_walk_mark__updateAt : float&)
  if act.curTime < minion_walk_mark__updateAt
    return

  minion_walk_mark__updateAt = act.curTime + minion_walk_mark__updateInterval

  query(minion_walk_mark__owner) <| $ [es] (transform aka owner_transform : float3x4)
    let distToOwnerSq = distance_sq(mark_transform[3], owner_transform[3])
    if distToOwnerSq > minion_walk_mark__distToDestroySq
      destroyEntity(minion_walk_mark_eid)


[es(tag=server, on_appear)]
def minion_attack_mark_init(evt : Event;
                            minion_attack_mark__removeTimeout : float;
                            var minion_attack_mark__removeAt : float&)
  minion_attack_mark__removeAt = get_sync_time() + minion_attack_mark__removeTimeout


[es(tag=server, no_order)]
def minion_attack_mark_update(act : UpdateStageInfoAct;
                              eid aka minion_attack_mark_eid : EntityId;
                              minion_attack_mark__owner : EntityId;
                              minion_attack_mark__target : EntityId;
                              minion_attack_mark__updateInterval : float = 0.5;
                              minion_attack_mark__distToDestroySq : float;
                              minion_attack_mark__removeAt : float;
                              var minion_attack_mark__updateAt : float&)
  if act.curTime < minion_attack_mark__updateAt
    return

  minion_attack_mark__updateAt = act.curTime + minion_attack_mark__updateInterval

  if act.curTime >= minion_attack_mark__removeAt
    destroyEntity(minion_attack_mark_eid)
    return

  query(minion_attack_mark__owner) <| $ [es] (transform aka owner_transform : float3x4)
    query(minion_attack_mark__target) <| $ [es] (transform aka enemy_transform : float3x4)
      let distToOwnerSq = distance_sq(enemy_transform[3], owner_transform[3])
      if distToOwnerSq > minion_attack_mark__distToDestroySq
        destroyEntity(minion_attack_mark_eid)