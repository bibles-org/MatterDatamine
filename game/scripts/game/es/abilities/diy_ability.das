require ecs
require ecs.safe
require ecs.common
require net
require math.base
require strings
require DagorMath
require DagorMathUtils
require DagorSystem
require Dacoll
require RendInst
require Grid
require DngNet
require game.events.events
require game.events.events_active_matter
require game.es.riextra_damage_common
require game.es.ecs_common
require active_matter.game.es.abilities.diy_ability_common
require active_matter.game.es.ability_common
require CollRes
require DagorDataBlock
require game.utils.sound_utils
require game.events.events_game
require game.es.grav_zones_common
require game.es.objectives.objective_common
require game.es.objectives.objective_utils_common
require game.es.inventory_item_common
require game.es.validation_common
require game.es.human_weap_common
require DngHuman


def check_available_quest_device_preview_pos(pos : float3;
                                             player_eid : EntityId;
                                             objective_eids : EidList const?;
                                             var out_target_eid : EntityId&)
  var result = false
  var hasPlace = false
  var hasObjectivePutDevice = false

  if objective_eids == null
    for_each_player_objective(player_eid) <| $(objective_eid : EntityId)
      if result
        return
      query(objective_eid) <| $ [es(REQUIRE=objectivePutDevice)] (objective__staticTargetsList : EidList)
        hasObjectivePutDevice = true
        for targetEid in objective__staticTargetsList
          hasPlace = true
          query(targetEid) <| $ [es(REQUIRE=placeForDeviceTarget)] ()
            result ||= is_point_in_objective_target_geometry(pos, targetEid)

          if result
            out_target_eid = targetEid
            break
  else
    for objectiveEid in *objective_eids
      query(objectiveEid) <| $ [es(REQUIRE=objectivePutDevice)] (objective__staticTargetsList : EidList)
        hasObjectivePutDevice = true
        for targetEid in objective__staticTargetsList
          hasPlace = true
          result ||= is_point_in_objective_target_geometry(pos, targetEid)

          if result
            out_target_eid = targetEid
            break
      if result
        break

  return result || (hasObjectivePutDevice && !hasPlace)


def check_available_quest_device_preview_pos(pos : float3;
                                             player_eid : EntityId;
                                             objective_eids : EidList const?)
  var targetEid : EntityId
  return check_available_quest_device_preview_pos(pos, player_eid, objective_eids, targetEid)


def throw_config_logerr(msg : string; eid : EntityId; param : int)
  logerr("DIY. {msg} \neid:{eid} <{getEntityTemplateName(eid)}> param={param}")


[es(tag=gameClient, no_order, REQUIRE=hero)]
def track_diy_area(act : UpdateStageInfoAct; eid : EntityId; transform : float3x4&; quick_use__objectiveCheckTime : float;
                   possessedByPlr : EntityId; var quick_use__objective : das_string&; var quick_use__objectiveNextCheckAt : float&)
  if act.curTime < quick_use__objectiveNextCheckAt
    return

  quick_use__objectiveNextCheckAt = act.curTime + quick_use__objectiveCheckTime

  var questItemTemplate = ""
  find_query() <| $ [es] (eid aka objective_eid : EntityId;
                          objective__staticTargetsList : EidList; objective__playerEid : EntityId;
                          objective__params : Array; objective__isCompleted : bool;
                          objective__questItemTemplateNameInParams : string;
                          objective_put_device__deviceCount : int = 1)
    if (objective__playerEid != possessedByPlr) || objective__isCompleted || objective_put_device__deviceCount <= 0
      return false

    for targetEid in objective__staticTargetsList
      if targetEid |> has("useObjectTarget") && is_point_in_objective_target_geometry(transform[3], targetEid)
        questItemTemplate = get_single_objective_item_from_params(objective__params,
                                                                  objective__questItemTemplateNameInParams,
                                                                  objective_eid,
                                                                  objective__playerEid)
        return true
    return false

  if !empty(questItemTemplate)
    let itemsInInventory <- find_items_in_inventory_by_template_name(questItemTemplate, eid)
    if !empty(itemsInInventory)
      quick_use__objective := questItemTemplate
  else
    quick_use__objective := ""


[es(tag=server, on_appear, REQUIRE=diy__previewEid)]
def on_diy_planning_phase_server(evt : Event;
                                 game_effect__attachedTo : EntityId;
                                 hero_ability__name : string)
  query(game_effect__attachedTo) <| $ [es] (diy__config : Array;
                                            hero_ability__abilities : Array;
                                            var diy__resultTempl : das_string;
                                            var diy__previewTempl : das_string;
                                            var diy__abilityName : das_string)
    diy__abilityName := hero_ability__name

    var param = -1 //Meaning: index  in diy__config
    for it in hero_ability__abilities
      let abilityObj = get_ecs_object(it)
      let abilityName = get_string(abilityObj, "name", "")
      if abilityName == hero_ability__name
        param = get_int(abilityObj, "param") ?? -1
    if param < 0
      logerr("Diy ability broken. Requested to create something but param is {param}.")
      return

    var skipPresets = param
    for it in diy__config
      skipPresets--
      if skipPresets < 0
        let preset = get_ecs_object(it)
        diy__resultTempl := get_string(*preset, "template", "")
        if !empty(diy__resultTempl)
          diy__previewTempl := get_string(*preset, "preview", "")
        else
          throw_config_logerr("misconfigured option. Contains neither 'template', nor 'event'.", game_effect__attachedTo, param)
        return

    throw_config_logerr("Ability param is outside of config. skipPresets left:{skipPresets}.", game_effect__attachedTo, param)


[es(tag=gameClient, on_appear)]
def create_diy_preview_on_effect_appear(evt : Event; game_effect__attachedTo : EntityId;
                                        var diy__previewEid : EntityId&)
  query(game_effect__attachedTo) <| $ [es(REQUIRE=watchedByPlr)] (diy__previewTempl : string)
    if empty(diy__previewTempl)
      return
    diy__previewEid = createEntity(diy__previewTempl)


[es(tag=gameClient, on_appear, track=diy__previewTempl, REQUIRE=watchedByPlr)]
def create_diy_preview_on_preview_sync(evt : Event; eid : EntityId; diy__previewTempl : string)
  find_query() <| $ [es] (game_effect__attachedTo : EntityId; var diy__previewEid : EntityId&)
    if game_effect__attachedTo == eid
      destroyEntity(diy__previewEid)
      if diy__previewTempl != ""
        diy__previewEid = createEntity(diy__previewTempl)
      else
        diy__previewEid = INVALID_ENTITY_ID
    return game_effect__attachedTo == eid


[es(on_disappear)]
def on_diy_planning_phase_out(evt : Event; diy__previewEid : EntityId; game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (var diy__previewTempl : das_string)
    diy__previewTempl := ""
  destroyEntity(diy__previewEid)


def private check_available_preview_pos(preview_tm : float3x4;
                                        vert_dir,
                                        human_pos,
                                        start_offset : float3;
                                        max_radius,
                                        max_angle : float;
                                        collobj : CollisionObject;
                                        collobj_pos : float3;
                                        collres : CollisionResource const?)
  let conflictWithWorld = is_diy_conflict_with_world(preview_tm, collobj, collres)
  let distanceTest = distance_sq(preview_tm[3], human_pos) <= square(max_radius + length(start_offset))
  let rootDir = get_some_normal(vert_dir)
  let angleTest = abs(basis_aware_dir_to_angles(preview_tm[1], vert_dir, rootDir).y) * RAD_TO_DEG >= max_angle
  let standTest = test_diy_available_stand(preview_tm)
  let isDiyVisible = is_diy_visible(preview_tm * collobj_pos, human_pos)
  return !conflictWithWorld && distanceTest && angleTest && standTest && isDiyVisible


def private make_preview_tm(start_pos,
                            look_dir : float3;
                            radius : float;
                            angle_limit : float;
                            diyNormalizeGround : Tag const?;
                            diyNormalizeWall : Tag const?;
                            var out_tm : float3x4&)
  let gravDir = get_grav_dir(start_pos)
  var lookDir = look_dir

  let gravLookDot = dot(gravDir, lookDir)
  if abs(gravLookDot) < 1.0
    // Clamp look dir angle
    let gravAngle = acos(gravLookDot)
    if gravAngle <= angle_limit
      let rotAxis = normalize(cross(lookDir, gravDir))
      let q = quat(rotAxis, -angle_limit)
      var tm : float3x4
      make_tm(q, tm)
      lookDir = tm |> rotate(gravDir)


  let normalizeRelativeGround = diyNormalizeGround != null
  let normalizeRelativeWall = diyNormalizeWall != null
  var dirUp : float3
  var dirT = radius
  traceray_normalized(start_pos, normalize(lookDir), dirT, dirUp)
  var previewPos = start_pos + lookDir * (dirT - 0.0001)
  let blockGroundNormalize = normalizeRelativeWall && dirT < radius
  if normalizeRelativeGround && !blockGroundNormalize
    let subDirTStep = 0.1f
    while dirT >= 0f
      var height = 300f
      previewPos = start_pos + lookDir * dirT
      dirUp = -dirUp

      if traceray_normalized(previewPos - dirUp * 0.0001, gravDir, height, dirUp, ETF_DEFAULT)
        previewPos += gravDir * height
      if distance_sq(previewPos, start_pos) <= square(radius)
        break
      dirT -= subDirTStep
  if !normalizeRelativeWall && !normalizeRelativeGround
    dirUp = -gravDir

  var tm = IDENT_TM
  tm[1] = dirUp
  tm[0] = normalize_default(cross(tm[1], float3(0f, 0f, 1f)), float3(1, 0, 0))
  tm[2] = normalize_default(cross(tm[0], tm[1]), float3(0, 0, 1))

  var quat : quat
  let angle = HALF_PI - dir_to_angles(-tm[2]).x
  euler_to_quat(angle, 0f, 0f, quat)
  quat = DagorMath::quat(tm) * quat
  make_tm(quat, previewPos, out_tm)


[es(tag=gameClient, no_order)]
def update_diy_preview(act : UpdateStageInfoAct; game_effect__attachedTo, diy__previewEid : EntityId)
  query(game_effect__attachedTo) <| $ [es] (human__aimTm, transform aka hero_transform : float3x4;
                                            camera__lookDir : float3; possessedByPlr : EntityId;
                                            human_inventory__lastUsedItemDevice : EntityId;
                                            human_net_phys : HumanActor;
                                            hero : Tag const?)
    query(diy__previewEid) <| $ [es] (var transform aka preview_transform : float3x4;
                                      preview__validColor : float3;
                                      preview__invalidColor : float3;
                                      preview__spectatingColor : float3;
                                      preview__angleLimit : float = 0.1;
                                      preview__radius : float;
                                      preview__allowedMinAngle : float;
                                      additionalYawRotation : float;
                                      preview__offset = float3();
                                      previewCollobj : CollisionObject;
                                      previewCollobjPos : float3;
                                      previewCollres : CollisionResource const?;
                                      diyNormalizeGround : Tag const?;
                                      diyNormalizeWall : Tag const?;
                                      questDevicePreview : Tag const?;
                                      var semi_transparent__placingColor : float3&;
                                      var area_of_visibility__color1 : E3DCOLOR?)
      let isSpectating = hero == null
      let lookDir = isSpectating ? human__aimTm[0] : camera__lookDir
      let startPos = human__aimTm[3]

      make_preview_tm(startPos, lookDir, preview__radius, preview__angleLimit,
                      diyNormalizeGround, diyNormalizeWall, preview_transform)


      var rotTM : float3x4
      rotyTM(deg_to_rad(additionalYawRotation) - dir_to_angles(hero_transform[0]).x, rotTM)
      preview_transform = preview_transform * rotTM
      preview_transform[3] = preview_transform[3] + rotate(preview_transform, preview__offset)

      var isValid = isSpectating || check_available_preview_pos(preview_transform,
                                                                human_net_phys.phys.currentState.vertDirection,
                                                                startPos,
                                                                preview__offset,
                                                                preview__radius,
                                                                preview__allowedMinAngle,
                                                                previewCollobj,
                                                                previewCollobjPos,
                                                                previewCollres)

      if questDevicePreview != null
        query(human_inventory__lastUsedItemDevice) <| $ [es] (quest_item__objectiveEids : EidList const?)
          isValid &&= check_available_quest_device_preview_pos(preview_transform[3], possessedByPlr, quest_item__objectiveEids)

      semi_transparent__placingColor = isSpectating ? preview__spectatingColor : (isValid ? preview__validColor : preview__invalidColor)
      if area_of_visibility__color1 != null
        *area_of_visibility__color1 = E3DCOLOR(isValid ? 0x0000FF00 : 0x00FF0000)


[es(tag=server)]
def on_diy_rq_create(evt : RqDiyCreate;
                     eid : EntityId;
                     diy__previewTempl : string)
  if !is_client_value_valid(evt.previewTransform)
    logwarn("[DIY] {get_entity_info(eid)}: client event validation failed! evt={evt}")
    return

  if getTemplateByName(string(diy__previewTempl)) == null
    logerr("DIY: unable to get preview template by name '{string(diy__previewTempl)}'")
    return
  let previewTm = evt.previewTransform
  createEntity("{diy__previewTempl}+diy_preview_server") <| $(init)
    set(init, "diy_preview_server__ownerEid", eid)
    set(init, "transform", previewTm)


[es(tag=server, on_appear, after=(diy_preview_animchar_collobj_init, diy_preview_rendinst_collobj_init), REQUIRE=diyPreviewServer)]
def on_diy_preview_appear_server(evt : Event;
                                 eid : EntityId;
                                 transform : float3x4;
                                 diy_preview_server__ownerEid : EntityId;
                                 preview__radius : float;
                                 preview__allowedMinAngle : float;
                                 previewCollobj : CollisionObject;
                                 previewCollobjPos : float3;
                                 previewCollres : CollisionResource const?;
                                 preview__offset = float3();
                                 questDevicePreview : Tag const?)
  query(diy_preview_server__ownerEid) <| $ [es] (human__aimTm : float3x4;
                                                 human_net_phys : HumanActor;
                                                 possessedByPlr : EntityId;
                                                 team : int;
                                                 diy__resultTempl : string;
                                                 diy__abilityName : string;
                                                 diy__cancelAfterUse : bool;
                                                 human_inventory__lastUsedItemDevice : EntityId;
                                                 human_weap__previousGunSlot : int;
                                                 var diy__enabled : bool?)
    if diy__enabled != null && !*diy__enabled
      return

    let startPos = human__aimTm * preview__offset
    let delayCompensation = 0.1f
    let radius = preview__radius + delayCompensation

    var avaliablePreviewPos = false
    var avaliablePreviewPosTargetEid : EntityId
    query(human_inventory__lastUsedItemDevice) <| $ [es] (quest_item__objectiveEids : EidList const?)
      avaliablePreviewPos = check_available_quest_device_preview_pos(transform[3], possessedByPlr, quest_item__objectiveEids, avaliablePreviewPosTargetEid)

    if questDevicePreview != null && !avaliablePreviewPos
      send_net_event(diy_preview_server__ownerEid, ShowStatusTip(statusTip = "status_tip_on_diy_rq_create_error_out_of_zone"))
      return

    if !check_available_preview_pos(transform,
                                    human_net_phys.phys.currentState.vertDirection,
                                    startPos,
                                    preview__offset,
                                    radius,
                                    preview__allowedMinAngle,
                                    previewCollobj,
                                    previewCollobjPos,
                                    previewCollres)
      send_net_event(diy_preview_server__ownerEid, ShowStatusTip(statusTip = "status_tip_on_diy_rq_create_error_wrong_place"))
      return


    objectives_print_log("{get_player_info_by_possessed(diy_preview_server__ownerEid)}: Quest Device planted ({diy__resultTempl})
  targetEid = {get_entity_info(avaliablePreviewPosTargetEid)} (transform={get_TMatrix(avaliablePreviewPosTargetEid, "transform") ?? IDENT_TM})
  objective_static_target__tag = {get_string(avaliablePreviewPosTargetEid, "objective_static_target__tag", "")}
  transform = {transform}
  startPos = {startPos}, preview__offset = {preview__offset}, radius = {radius}")


    createEntity(diy__resultTempl) <| $(init)
      init |> set("transform", transform)
      init |> set("ownerEid", diy_preview_server__ownerEid)
      init |> set("playerOwnerEid", possessedByPlr)
      let templ = getTemplateByName(diy__resultTempl)
      if templ != null && templateHasComponent(*templ, "set_teammate")
        init |> set("team", team)
    sendEvent(diy_preview_server__ownerEid, CmdSkipActiveAbility(ability_name = diy__abilityName))
    broadcast_net_sound(diy_preview_server__ownerEid, "use_repairkit", transform[3])
    send_net_event(diy_preview_server__ownerEid, DiyAbilityAppearEffect(pos = transform[3]))

    if diy__cancelAfterUse && diy__enabled != null
      *diy__enabled = false

    deselect_slot_and_try_switch_to_previous_slot(diy_preview_server__ownerEid, int(HUWeaponSlots.EWS_UNARMED), human_weap__previousGunSlot, human_net_phys)
  destroyEntity(eid)