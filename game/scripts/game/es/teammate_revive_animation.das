require ecs
require math.base
require AnimV20
require GeomNodeTree
require PhysVars
require DngNet
require DagorMath
require DagorSystem
require Dacoll
require DngPhysObj
require game.events.events
require game.events.events_active_matter
require game.events.events_game
require game.es.grav_zones_common
require game.es.human_inventory_postponed_usage_common


[es(on_appear)]
def teammate_revive_register_var(evt : Event;
                                 game_effect__attachedTo : EntityId;
                                 var teammate_revive__progressVarId : int&;
                                 teammate_revive_client : Tag const?)
  query(game_effect__attachedTo) <| $ [es] (var phys_vars : PhysVars&; hero : Tag const?)
    if hero != null && teammate_revive_client == null
      return

    teammate_revive__progressVarId = registerVar(phys_vars, "action_progress", 0f)
    setVar(phys_vars, teammate_revive__progressVarId, 0.f)


[es(on_appear, before=teammate_revive_register_var)]
def teammate_revive_animation_create_animchar_on_appear(evt : Event;
                                                        game_effect__attachedTo : EntityId;
                                                        teammate_revive_effect__playerItemOwner : EntityId;
                                                        teammate_revive_effect__animcharTemplate : string;
                                                        var teammate_revive_effect__animcharEid : EntityId&;
                                                        teammate_revive_client : Tag const?)
  if has(game_effect__attachedTo, "hero") && teammate_revive_client == null
    return
  teammate_revive_effect__animcharEid = createEntity(teammate_revive_effect__animcharTemplate) <| $(init)
    init |> set("game_effect__attachedTo", game_effect__attachedTo)
    init |> set("cortical_vault_revive__spawnPlayerEid", teammate_revive_effect__playerItemOwner)


[es(on_appear)]
def teammate_revive_animation_start_sequence_on_appear(evt : Event;
                                                       eid : EntityId;
                                                       teammate_revive_effect__sequenceTemplate : string)
  createEntity(teammate_revive_effect__sequenceTemplate) <| $(init)
    init |> set("game_effect__attachedTo", eid)


[es(no_order)]
def process_teammate_revive_animation(act : ParallelUpdateFrameDelayed;
                                      game_effect__attachedTo : EntityId;
                                      teammate_revive__progressVarId : int;
                                      teammate_revive_client : Tag const?)
  query(game_effect__attachedTo) <| $ [es] (var phys_vars : PhysVars&;
                                            human_inventory__entityUseStart : float;
                                            human_inventory__entityUseEnd : float;
                                            animchar__updatable = true;
                                            hero : Tag const?)
    if hero != null && teammate_revive_client == null
      return
    if !animchar__updatable || human_inventory__entityUseEnd < act.curTime
      return

    let progress = cvt(act.curTime, human_inventory__entityUseStart, human_inventory__entityUseEnd, 0.f, 1.f)
    setVar(phys_vars, teammate_revive__progressVarId, progress)


[es(tag=gameClient, on_appear)]
def cortical_vault_revive_start_transfer(evt : Event;
                                         game_effect__attachedTo : EntityId;
                                         var cortical_vault_revive_am_transfer__effectEid : EntityId&)
  let target = game_effect__attachedTo
  query(game_effect__attachedTo) <| $ [es] (game_effect__attachedTo : EntityId)
    cortical_vault_revive_am_transfer__effectEid = createEntity("human_revive_cortical_vault_effect") <| $(init)
      init |> set("human_revive_cortical_vault_effect__owner", game_effect__attachedTo)
      init |> set("human_revive_cortical_vault_effect__target", target)


[es(no_order)]
def cortical_vault_revive_update_transfer(info : UpdateStageInfoAct;
                                          game_effect__attachedTo : EntityId;
                                          cortical_vault_revive_am_transfer__effectEid : EntityId)
  query(game_effect__attachedTo) <| $ [es] (game_effect__attachedTo : EntityId;
                                            slot_attach__slotId : int)
    query(game_effect__attachedTo) <| $ [es] (animchar : AnimcharBaseComponent)
      var tmpTm : mat44f
      if animchar_initAttachmentTmAndNodeWtm(animchar, slot_attach__slotId, tmpTm)
        let wtmOfs = *animchar.nodeTree |> geomtree_getWtmOfs()
        query(cortical_vault_revive_am_transfer__effectEid) <| $ [es] (var human_nexus_channeling_effect__goal : float3&)
          human_nexus_channeling_effect__goal = tmpTm.col3.xyz + wtmOfs


[es(tag=gameClient, on_disappear)]
def cortical_vault_revive_stop_transfer(evt : Event;
                                        cortical_vault_revive_am_transfer__effectEid : EntityId)
  destroyEntity(cortical_vault_revive_am_transfer__effectEid)


[es(on_appear)]
def throw_cortical_vault(evt : Event;
                         game_effect__attachedTo : EntityId;
                         cortical_vault_revive__attachSubtemplate : string;
                         cortical_vault_revive__physSubtemplate : string;
                         cortical_vault_revive__throwForce : float)
  var tm = IDENT_TM
  var isStashed = false
  query(game_effect__attachedTo) <| $ [es] (game_effect__attachedTo : EntityId;
                                            slot_attach__slotId : int)
    query(game_effect__attachedTo) <| $ [es] (animchar : AnimcharBaseComponent; net_stash_entity : Tag const?)
      isStashed = net_stash_entity != null
      var tmpTm : mat44f
      if animchar_initAttachmentTmAndNodeWtm(animchar, slot_attach__slotId, tmpTm)
        let wtmOfs = *animchar.nodeTree |> geomtree_getWtmOfs()
        tm = float3x4(tmpTm)
        tm[3] += wtmOfs
  removeSubTemplate(game_effect__attachedTo, cortical_vault_revive__attachSubtemplate)
  if isStashed
    return //no physics in net stash or it's a logerr
  let physTemplate = is_server() ? cortical_vault_revive__physSubtemplate : "{cortical_vault_revive__physSubtemplate}+client_side"
  addSubTemplate(game_effect__attachedTo, physTemplate) <| $(var init)
    init |> set("transform", tm)
    init |> set("start_vel", -tm[0] * cortical_vault_revive__throwForce)
    using() <| $(var hist : Point3List&)
      hist |> push(tm[3])
      init |> set("cortical_vault_revive__posHistory", hist)


[es(tag=server)]
def cortical_vault_save_phys_pos(evt : CmdPostPhysUpdate;
                                 phys_obj_net_phys : PhysObjActor;
                                 var cortical_vault_revive__posHistory : Point3List&)
  cortical_vault_revive__posHistory |> push(float3(phys_obj_net_phys.phys.currentState.location.P))


def check_revive_position(var wish_pos : float3&;
                          trace_params : float3)
  // trace down on trace_params.z + trace_params.y
  let gravDir = get_grav_dir(wish_pos)
  var t = trace_params.y + trace_params.z
  var norm = float3()
  traceray_normalized(wish_pos, gravDir, t, norm)
  wish_pos = wish_pos + gravDir * t

  // check place for hero
  let up = -get_grav_dir(wish_pos)
  var out = ShapeQueryOutput()
  return !sphere_cast(wish_pos + up * (trace_params.y + trace_params.x),
                      wish_pos + up * max(0f, trace_params.z - trace_params.x),
                      trace_params.x, out)


[es(tag=server, on_appear)]
def cortical_vault_revive_teammate(evt : Event;
                                   game_effect__attachedTo aka cortical_vault_game_effect__attachedTo : EntityId;
                                   cortical_vault_revive__traceParams : float3)
  let corticalVaultAnimcharEid = cortical_vault_game_effect__attachedTo
  query(corticalVaultAnimcharEid) <| $ [es] (cortical_vault_revive__spawnPlayerEid : EntityId;
                                             game_effect__attachedTo aka human_game_effect__attachedTo : EntityId;
                                             cortical_vault_revive__posHistory : Point3List)
    let humanEid = human_game_effect__attachedTo
    var isAlreadyAlive = false // already revived by other means
    query(cortical_vault_revive__spawnPlayerEid) <| $ [es] (possessed : EntityId)
      query(possessed) <| $ [es] (isAlive : bool)
        isAlreadyAlive = isAlive
    if isAlreadyAlive
      sendEventImmediate(humanEid, EventInterruptItemUse())
      return

    var tm : float3x4 = IDENT_TM
    var humanQueried = false
    query(humanEid) <| $[es] (transform : float3x4)
      humanQueried = true
      tm = transform

    print("[cortical_vault_revive_teammate]: <{humanEid}> reviving player <{cortical_vault_revive__spawnPlayerEid}> at {tm}")

    if !humanQueried
      logwarn("[cortical_vault_revive_teammate]: <{humanEid}> doesn't exist, aborting revive")
      return

    let n = length(cortical_vault_revive__posHistory)
    for i in iter_range(cortical_vault_revive__posHistory)
      var pos = cortical_vault_revive__posHistory[n - i - 1]
      if check_revive_position(pos, cortical_vault_revive__traceParams)
        tm[3] = pos
        break
    sendEvent(cortical_vault_revive__spawnPlayerEid, CmdSpawnEntity(tm = tm))
  destroyEntity(corticalVaultAnimcharEid)


[es(tag=netClient, on_appear, REQUIRE=cortical_vault_revive__traceParams)]
def cortical_vault_destroy_animchar(evt : Event;
                                    game_effect__attachedTo : EntityId)
  let corticalVaultAnimcharEid = game_effect__attachedTo
  destroyEntity(corticalVaultAnimcharEid)


def stop_animation(vault_eid : EntityId)
  find_query() <| $ [es(REQUIRE=cortical_vault_revive_sequence_affect)] (eid, game_effect__attachedTo : EntityId)
    if game_effect__attachedTo == vault_eid
      destroyEntity(eid)
      destroyEntity(vault_eid)
      return true
    return false


[es(tag=server, before=human_inventory_server_es)]
def delete_teammate_revive_animation_server(act : UpdateStageInfoAct; eid, game_effect__attachedTo, teammate_revive_effect__animcharEid : EntityId)
  query(game_effect__attachedTo) <| $ [es] (human_inventory__entityUseEnd : float; human_inventory_postponed_usage__state : int = 0)
    if human_inventory__entityUseEnd < act.curTime && human_inventory_postponed_usage__state != int(PostponedUsageState.WaitForSwapToUnarmed)
      destroyEntity(eid)
      if human_inventory__entityUseEnd < 0.f
        stop_animation(teammate_revive_effect__animcharEid)


[es(tag=gameClient, no_order)]
def delete_teammate_revive_animation_client(act : ParallelUpdateFrameDelayed;
                                            eid, game_effect__attachedTo, teammate_revive_effect__animcharEid : EntityId;
                                            teammate_revive_client : Tag const?)
  query(game_effect__attachedTo) <| $ [es] (human_inventory__entityUseEnd : float; human_inventory_postponed_usage__state : int = 0)
    if human_inventory__entityUseEnd < act.curTime && human_inventory_postponed_usage__state != int(PostponedUsageState.WaitForSwapToUnarmed)
      if teammate_revive_client != null
        destroyEntity(eid)
      if human_inventory__entityUseEnd < 0.f
        stop_animation(teammate_revive_effect__animcharEid)


[es(on_disappear, REQUIRE=human_inventory__entityUseEnd)]
def delete_teammate_revive_animation_on_initiator_disappear(evt : Event;
                                                            eid aka human_eid : EntityId)
  query() <| $ [es] (eid : EntityId;
                     game_effect__attachedTo : EntityId;
                     teammate_revive_effect__animcharEid : EntityId;
                     teammate_revive_client : Tag const?)
    if game_effect__attachedTo == human_eid
      stop_animation(teammate_revive_effect__animcharEid)
      if teammate_revive_client != null && !is_true_net_server()
        destroyEntity(eid)
