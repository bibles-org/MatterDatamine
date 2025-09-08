module spawn shared

require app
require ecs
require ecs.safe
require math
require math.base
require DagorMath
require Dacoll
require DagorRandom
require DagorSystem
require pathfinder
require game.es.player_profile_common
require game.es.ecs_common
require game.es.stat_bq_common
require game.utils.spawn_base
require game.events.player_events
require game.es.item_equip_common
require DngHuman
require game.utils.team


def trace_binary_search(pos : float3; max_ht : float; err_term : float) : float3
  var len = max_ht - pos.y
  var norm : float3
  if traceray_normalized(float3(pos.x, (max_ht + pos.y) * 0.5, pos.z), float3(0.0, -1.0, 0.0), len, norm)
    let resHt = (max_ht + pos.y) * 0.5 - len
    if resHt - pos.y < err_term
      return float3(pos.x, resHt, pos.z)
    return trace_binary_search(pos, resHt, err_term)
  return float3(pos.x, max_ht, pos.z)


def trace_search(pos : float3; top_offs : float) : float3
  let t = top_offs
  let dir = float3(0.0, -1.0, 0.0)
  if !rayhit_normalized(pos, dir, t, ETF_DEFAULT, -1)
    var len = top_offs
    var norm : float3
    if traceray_normalized(pos + float3(0.0, top_offs, 0.0), float3(0.0, -1.0, 0.0), len, norm)
      let maxHt = pos.y + top_offs - len
      return trace_binary_search(pos, maxHt, 0.4)
  return pos


def validate_tm(var tm : float3x4; horz_extents : float = 0.75)
  var wishPos = tm[3]
  let extents = float3(0.25, FLT_MAX, 0.25)
  traceray_navmesh(tm[3], tm[3], extents, wishPos)
  wishPos = trace_search(wishPos, 1000.0)
  let projExtents = float3(horz_extents, horz_extents, horz_extents)
  var navmeshPos = wishPos
  project_to_nearest_navmesh_point_no_obstacles(navmeshPos, projExtents)
  let pathExtents = float3(0.1, FLT_MAX, 0.1)
  let resPos = check_path(navmeshPos, wishPos, pathExtents, 0.5, 1.5, null, int(PolyFlag.POLYFLAG_GROUND) | int(PolyFlag.POLYFLAG_JUMP)) ? wishPos : navmeshPos
  orthonormalize(tm)
  tm[3] = float3(resPos)


def select_random_template(templates : Object) : string
  var totalWt = 0.0
  var res : string
  using() <| $(var templateList : Array)
    for templ in templates
      totalWt += templ.value ?? 0.0
      using() <| $(var obj : Object)
        set(obj, "key", templ.key)
        set(obj, "wt", totalWt)
        templateList |> push(obj)
    if length(templateList) > 0
      let curWt = gfrnd() * totalWt
      for templ in templateList
        let templObj = templ |> get_ecs_object()
        if templObj != null
          if curWt <= (*templObj).wt ?? 0.0
            res := (*templObj).key ?? ""
            break
  return res


def get_team_unit_template_name(team : int; playerEid : EntityId) : string
  let playerPossessedTemplate = get_string(playerEid, "possessedTemplate", "")
  if playerPossessedTemplate != ""
    return playerPossessedTemplate
  let teamEid = get_team_eid(team)
  let templates = get_ecs_object(teamEid, "team__unitTemplates")
  let templ = templates != null ? select_random_template(*templates) : ""
  if !empty(templ)
    return templ
  let unitTemplate = get_string(teamEid, "team__unitTemplate", "")
  return unitTemplate


def init_item_container(eid : EntityId)
  let itemContainer = get_ecs_EidList(eid, "itemContainer")
  for itemEid in *itemContainer
    if doesEntityExist(itemEid)
      query(itemEid) <| $ [es] (var item__lastContainerOwnerEid : EntityId&)
        item__lastContainerOwnerEid = eid


def set_phys_from_transform(eid : EntityId)
  query(eid) <| $ [es] (var human_net_phys : HumanActor; transform : float3x4)
    assume ct = human_net_phys.phys.appliedCT
    ct |> human_control_state_set_wish_look_dir(transform[0])
    ct |> human_control_state_set_wish_shoot_dir(transform[0])
    ct |> set_chosen_weapon(HUWeaponSlots.EWS_UNARMED)
    human_net_phys.phys.currentState.gunDir = normalize(transform[0])
    human_net_phys.phys.currentState.weapEquipState.curSlot = HUWeaponSlots.EWS_UNARMED
    human_net_phys.phys.currentState.weapEquipState.nextSlot = HUWeaponSlots.EWS_UNARMED


def get_player_positions_by_team(player_team : int) : table<int; array<float3>>
  var positions : table<int; array<float3>>
  query() <| $ [es(REQUIRE=player)] (possessed : EntityId;
                                     team : int)
    if !doesEntityExist(possessed) || player_team != team
      return
    let tm = get_TMatrix(possessed, "transform")
    let isAlive = get_bool(possessed, "isAlive") ?? false
    positions[isAlive ? 0 : 1] |> push((*tm)[3])
  return <- positions


def calc_best_spawn_tm_for_team(team : int; var wishTm : float3x4)
  let positions <- get_player_positions_by_team(team)
  for p in values(positions)
    if length(p) > 0
      wishTm[3] = p[rnd_int(0, length(p) - 1)]
      break


def mk_spawn_params_by_team(team : int; wishSpawnPlaceId : int; var params : Object) : bool
  let findSpawnBaseResult = find_spawn_base(team, wishSpawnPlaceId)
  let baseEid = findSpawnBaseResult.baseEid
  if baseEid == INVALID_ENTITY_ID
    return false

  params |> set("baseEid", baseEid)
  params |> set("team", team)

  var tm = IDENT_TM
  query(baseEid) <| $ [es] (transform : float3x4;
                            spawnBase__spawnRadius : float;
                            respbase__skipSpawnPosValidation = false;
                            spawnBase__teamSpawn = false)
    tm = transform
    orthonormalize(tm)

    if spawnBase__teamSpawn
      calc_best_spawn_tm_for_team(team, tm)

    let rotation = rnd_float(0.0, TWOPI)
    var s, c : float
    sincos(rotation, s, c)
    let dirFromSpawn = float3(s, 0.0, c)
    tm[3] += dirFromSpawn * spawnBase__spawnRadius
    if !respbase__skipSpawnPosValidation
      validate_tm(tm)

  params |> set("transform", tm)
  return true


def start_delayed_entity_spawn_for_player(player_eid : EntityId;
                                          spawnAt : float)
  createEntity("spawn_entity_for_player_at_time") <| $(var init : ComponentsInitializer)
    init |> set("spawn_entity_for_player_at_time__player", player_eid)
    init |> set("spawn_entity_for_player_at_time__spawnAt", spawnAt)


def stop_delayed_entity_spawn_for_player(player_eid : EntityId)
  query() <| $ [es] (eid aka spawn_entity_eid : EntityId;
                     spawn_entity_for_player_at_time__player : EntityId)
    if spawn_entity_for_player_at_time__player == player_eid
      destroyEntity(spawn_entity_eid)


def spawn_soldier(team : int;
                  playerEid : EntityId;
                  var spawnParams : Object)
  let transform = get_TMatrix(spawnParams, "transform") ?? IDENT_TM
  print("[SPAWN_SOLDIER] {get_entity_info(playerEid)}: Create single soldier squad for team {team} at ({transform[3].x},{transform[3].y},{transform[3].z})")
  if abs(det(transform)) < FLT_EPSILON
    error("[SPAWN_SOLDIER] Ignoring request to spawn soldier with degenerate matrix: {transform}")
    return

  spawnParams |> set("transform", transform)
  spawnParams |> set("createdByPlr", playerEid)

  let baseEid = get_Eid(spawnParams, "baseEid") ?? INVALID_ENTITY_ID

  var templateName = get_team_unit_template_name(team, playerEid)
  if templateName == ""
    logerr("spawn_soldier: templateName is empty")
    return

  var squadSize = -1
  query(playerEid) <| $ [es] (userid : uint64)
    find_query() <| $ [es] (squad__memberUserIds : UInt64List)
      if !has_value(squad__memberUserIds, userid)
        return false
      squadSize = length(squad__memberUserIds)
      return true
  if squadSize > 0
    print("[SPAWN_SOLDIER] <{playerEid}> has squad of size {squadSize}")
  else
    print("[SPAWN_SOLDIER] <{playerEid}> has no squad.")
    squadSize = 3
  mark_respawn_base(team, baseEid, squadSize)

  var suitType = 0 // SuitType MALE

  let suitTypeWasSet = find_query() <| $ [es] (player_profile__allItems : Array)
    suitType = get_suit_type(player_profile__allItems)
    return true

  query(playerEid) <| $ [es] (initialHeroItems : Array;
                              var possessedTemplate : das_string?)
    if possessedTemplate != null
      *possessedTemplate := templateName

    if !suitTypeWasSet
      suitType = get_suit_type(initialHeroItems)

    spawnParams |> set("attachable_suit_controller__suitType", suitType)

    let templ = getOrBuildTemplateByName(templateName)
    if templ != null
      let mainAnimcharConfig = *templ |> getTemplateComponent("attachable_suit_controller__mainAnimcharConfig") ?as Array

      if mainAnimcharConfig != null
        if suitType < length(*mainAnimcharConfig)
          let soldierSexData = (*mainAnimcharConfig)[suitType] as Object
          spawnParams |> set("animchar__res", soldierSexData?.animchar ?? "")
          spawnParams |> set("collres__res", soldierSexData?.collres ?? "")
        else
          logerr("[SPAWN_SOLDIER] suitType({suitType}) is out of config range({length(*mainAnimcharConfig)})!")

  spawnParams |> set("human_net_phys__isSimplifiedPhys", has(playerEid, "playerIsBot"))

  let callback <- @ <| (eid : EntityId)
    sendEvent(playerEid, CmdPossessEntity(possessedEid = eid))
    init_item_container(eid)
    set_phys_from_transform(eid)

  stop_delayed_entity_spawn_for_player(playerEid)

  let createEntityExtraTemplate = spawnParams.createEntityExtraTemplate ?? ""
  if createEntityExtraTemplate != ""
    templateName = add_sub_template_name(templateName, createEntityExtraTemplate)

  createEntity(templateName, callback) <| $(var init)
    for comp in spawnParams
      set(init, comp.key, comp.value)


def spawn_soldier(team : int; playerEid : EntityId)
  using() <| $(var params : Object)
    let teamSpawnPlaceId = get_team_eid(team) |> get_int("team__spawnGroupId") ?? -1
    let wishSpawnPlaceId = playerEid |> get_int("player__spawnPlaceId") ?? teamSpawnPlaceId
    if !mk_spawn_params_by_team(team, wishSpawnPlaceId, params)
      logerr("spawn_soldier: no respawn base for team {team}")
      return
    spawn_soldier(team, playerEid, params)


def spawn_monster_soldier(playerEid : EntityId;
                          monster_template : string;
                          transform : float3x4;
                          am_storage__value : int)
  let callback <- @ <| (eid : EntityId)
    sendEvent(playerEid, CmdPossessEntity(possessedEid = eid))
    set_phys_from_transform(eid)

  query(playerEid) <| $ [es] (team : int)
    createEntity(monster_template, callback) <| $(var init)
      init |> set("transform", transform)
      init |> set("team", team)
      init |> set("human_net_phys__isSimplifiedPhys", false)
      init |> set("beh_tree__enabled", false)
      init |> set("am_storage__value", am_storage__value)
      init |> set("createdByPlr", playerEid)