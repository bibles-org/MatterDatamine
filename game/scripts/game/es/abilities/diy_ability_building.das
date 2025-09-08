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
require active_matter.game.es.abilities.diy_ability_common
require game.es.riextra_common
require CollRes
require DagorDataBlock
require game.utils.sound_utils
require game.events.events_game
require game.es.grav_zones_common


def get_ri_name(tmpl : string) : string
  var resultTemplate = getTemplateByName(tmpl)
  if resultTemplate == null
    resultTemplate = buildTemplateByName(tmpl)
  return resultTemplate != null ? *resultTemplate |> getTemplateComponent("ri_extra__name") |> get_string("") : ""


def private check_available_preview_pos(preview_tm : float3x4;
                                        collobj : CollisionObject;
                                        collres : CollisionResource const?)
  let conflictWithWorld = is_diy_conflict_with_world(preview_tm, collobj, collres)
  let standTest = test_diy_available_stand(preview_tm)
  return !conflictWithWorld && standTest


def private make_preview_tm(start_pos,
                            look_dir : float3;
                            radius : float;
                            normalizeRelativeGround : bool;
                            normalizeRelativeWall : bool;
                            var out_tm : float3x4&)
  var dirUp : float3
  var dirT = radius
  traceray_normalized(start_pos, look_dir, dirT, dirUp)
  var previewPos = start_pos + look_dir * (dirT - 0.0001f)
  let blockGroundNormalize = normalizeRelativeWall && dirT < radius
  if normalizeRelativeGround && !blockGroundNormalize
    let subDirTStep = 0.1f
    while dirT >= 0f
      var height = 300f
      previewPos = start_pos + look_dir * dirT
      if tracedown_normalized(previewPos, height, dirUp, ETF_DEFAULT)
        previewPos.y -= height
      if distance_sq(previewPos, start_pos) <= square(radius)
        break
      dirT -= subDirTStep
  if !normalizeRelativeWall && !normalizeRelativeGround
    dirUp = float3(0, 1, 0)

  var tm = IDENT_TM
  tm[1] = dirUp
  tm[0] = normalize_default(cross(tm[1], float3(0f, 0f, 1f)), float3(1, 0, 0))
  tm[2] = normalize_default(cross(tm[0], tm[1]), float3(0, 0, 1))

  var quat : quat
  let angle = HALF_PI - dir_to_angles(-tm[2]).x
  euler_to_quat(angle, 0f, 0f, quat)
  quat = DagorMath::quat(tm) * quat
  make_tm(quat, previewPos, out_tm)


def throw_config_logerr(msg : string; eid : EntityId = INVALID_ENTITY_ID)
  logerr("DIY. {msg} \neid:{eid} <{getEntityTemplateName(eid)}>")


def initialize_preview_coll_obj(collres : CollisionResource; height_add : float;
                                var preview_coll_obj : CollisionObject; var previewCollobjPos : float3&)
  using() <| $(var coll_props : DataBlock)
    datablock_add_block(coll_props, "box") <| $(box)
      var tm = IDENT_TM
      tm[3] = collres.boundingBox.center + float3(0f, height_add, 0f)
      previewCollobjPos = tm[3]
      add(box, "tm", tm)
      add(box, "width", collres.boundingBox.width)
    preview_coll_obj = add_dynamic_collision(coll_props)


[es(on_appear, REQUIRE_NOT=semi_transparent__resIdx)]
def diy_preview_animchar_collobj_init(evt : Event;
                                      preview__collHeightAdd : float;
                                      previewCollres : CollisionResource;
                                      var previewCollobj : CollisionObject;
                                      var previewCollobjPos : float3&)
  initialize_preview_coll_obj(previewCollres, preview__collHeightAdd, previewCollobj, previewCollobjPos)

[es(on_appear)]
def diy_preview_rendinst_collobj_init(evt : Event;
                                      preview__collHeightAdd : float;
                                      ri_preview__name : string;
                                      eid : EntityId;
                                      var previewCollobj : CollisionObject;
                                      var previewCollobjPos : float3&)
  var resIndex = get_rigen_extra_res_idx(ri_preview__name)
  if resIndex < 0
    resIndex = ensure_riextra_res_idx(ri_preview__name)
    if resIndex < 0
      logerr("Failed to add ri_preview__name=<{ri_preview__name}>({resIndex}) while creating entity {eid}<{getEntityTemplateName(eid)}>")
      return
  let previewCollres = get_rigen_extra_coll_res(resIndex)
  if previewCollres != null
    initialize_preview_coll_obj(*previewCollres, preview__collHeightAdd, previewCollobj, previewCollobjPos)


[es(on_disappear)]
def diy_preview_collobj_destroy(evt : Event; var previewCollobj : CollisionObject)
  destroy_dynamic_collision(previewCollobj)


[es(tag=server, on_appear, REQUIRE=diy__previewControllerEid)]
def on_diy_building_planning_phase_server(evt : Event;
                                          game_effect__attachedTo : EntityId;
                                          hero_ability__name : string)
  query(game_effect__attachedTo) <| $ [es] (diy__forcedBlueprintTemplate : string;
                                            var diy__activeBlueprintTemplate : das_string;
                                            var diy__abilityName : das_string)
    diy__abilityName := hero_ability__name
    diy__activeBlueprintTemplate := diy__forcedBlueprintTemplate


[es(on_appear, tag=dev)]
def diy_ability_validate_blueprints(evt : Event; @shared_comp diy_blueprint__data : Object; eid : EntityId)
  let items = diy_blueprint__data.items ?as Array
  if items == null
    throw_config_logerr("No 'items' in config", eid)
    return
  if length(*items) == 0
    throw_config_logerr("'items' array is empty", eid)
    return
  for item, k in *items, iter_range(*items)
    let iObj = item as Object
    let tmpl = iObj?["template"] ?? ""
    if empty(tmpl)
      throw_config_logerr("'template' is not set in item {k}.", eid)
      return


[es(tag=server, REQUIRE=eid)]
def remove_moved_building(evt : EventBuildPlaced)
  if evt.movedBuildingEid != INVALID_ENTITY_ID
    sendEventImmediate(evt.movedBuildingEid, CmdDestroyBuilding(reason = DestroyBuildingReason.MOVE))


[es(tag=server, on_appear, REQUIRE=completed_construction)]
def log_building_constructed(evt : Event; building_ctrl__blueprintTemplate : string)
  print("DIY: building constructed: '{building_ctrl__blueprintTemplate}'")


[es(tag=server)]
def on_cmd_destroy_building(evt : CmdDestroyBuilding; construction__instanceId aka ctrl_construction__instanceId : int)
  query() <| $ [es] (eid : EntityId; construction__instanceId aka child_construction__instanceId : int)
    if child_construction__instanceId == ctrl_construction__instanceId
      destroyEntity(eid)


[es(tag=gameClient, on_appear)]
def create_diy_building_preview_on_effect_appear(evt : Event;
                                                 game_effect__attachedTo : EntityId;
                                                 diy__previewControllerTempl : string;
                                                 var diy__previewControllerEid : EntityId&)
  query(game_effect__attachedTo) <| $ [es(REQUIRE=watchedByPlr)] (diy__activeBlueprintTemplate : string)
    diy__previewControllerEid = createEntity(add_sub_template_name(diy__previewControllerTempl, diy__activeBlueprintTemplate)) <| $(init)
      init |> set("preview__ownerEid", game_effect__attachedTo)


[es(tag=gameClient, track=diy__activeBlueprintTemplate, REQUIRE=watchedByPlr)]
def create_diy_building_preview_on_preview_sync(evt : Event; eid aka hero_eid : EntityId; diy__activeBlueprintTemplate : string)
  find_query() <| $ [es] (game_effect__attachedTo : EntityId;
                          diy__previewControllerTempl : string;
                          var diy__previewControllerEid : EntityId&)
    if game_effect__attachedTo == hero_eid
      diy__previewControllerEid |> destroyEntity()
      diy__previewControllerEid = createEntity(add_sub_template_name(diy__previewControllerTempl, diy__activeBlueprintTemplate)) <| $(init)
        init |> set("preview__ownerEid", game_effect__attachedTo)
    return game_effect__attachedTo == hero_eid


[es(on_disappear)]
def on_diy_building_planning_phase_out(evt : Event; diy__previewControllerEid : EntityId)
  destroyEntity(diy__previewControllerEid)


[es(on_disappear)]
def on_diy_preview_controller_destroyed(evt : Event; diy__previewEids : EidList)
  for eid in diy__previewEids
    destroyEntity(eid)


[es(on_appear)]
def diy_preview_controller_init(evt : Event;
                                eid : EntityId;
                                name : string;
                                @shared_comp diy_blueprint__data : Object;
                                diy__additionalPreviewTemplate = "";
                                preview__baseYawRotation : float;
                                var diy__previewEids : EidList;
                                var additionalYawRotation : float&)
  let items = diy_blueprint__data.items ?as Array
  if items != null
    for item in *items
      let itemObj = item as Object
      let templ = itemObj?["template"] ?? ""
      if empty(templ)
        throw_config_logerr("Empty template in blueprint '{name}'")
        return
      let move = itemObj?.move ?? float3()
      let rotate = itemObj?.rotate ?? float3()
      var tm = IDENT_TM
      var q : quat
      euler_to_quat(deg_to_rad(rotate.x), deg_to_rad(rotate.y), deg_to_rad(rotate.z), q)
      make_tm(q, move, tm)
      let blueprintPreview = itemObj?.preview ?? ""
      let riName = get_ri_name(templ)
      let RI_PREVIEW_BASE = "ri_preview_base"
      let preview = !empty(blueprintPreview) ? blueprintPreview : !empty(riName) ? RI_PREVIEW_BASE : "base_diy_building_preview"
      let previewTempl = empty(diy__additionalPreviewTemplate) ? preview : "{preview}+{diy__additionalPreviewTemplate}"
      let previewEid = createEntity(previewTempl) <| $(init)
        init |> set("diy__offsetTm", tm)
        init |> set("preview__result", templ)
        init |> set("preview__controllerEid", eid)
        if preview == RI_PREVIEW_BASE
          init |> set("ri_preview__name", riName)
      diy__previewEids |> push(previewEid)
  else
    throw_config_logerr("Can't find 'items' array in blueprint '{name}'")
  if length(diy__previewEids) == 0
    throw_config_logerr("Nothing was created from blueprint '{name}'")
    destroyEntity(eid)

  additionalYawRotation = preview__baseYawRotation


[es(tag=gameClient, no_order, REQUIRE_NOT=diyPreviewControllerServer)]
def update_diy_building_preview_controller_tm(act : UpdateStageInfoAct;
                                              preview__ownerEid : EntityId;
                                              preview__radius : float;
                                              additionalYawRotation : float;
                                              preview__diyNormalizeGround : bool;
                                              preview__diyNormalizeWall : bool;
                                              var transform aka controller_transform : float3x4)
  query(preview__ownerEid) <| $ [es] (human__aimTm, transform aka hero_transform : float3x4;
                                      camera__lookDir : float3;
                                      hero : Tag const?)
    let lookDir = hero == null ? human__aimTm[0] : camera__lookDir
    let startPos = human__aimTm[3]

    make_preview_tm(startPos, lookDir, preview__radius, preview__diyNormalizeGround, preview__diyNormalizeWall, controller_transform)
    var rotTM : float3x4
    rotyTM(deg_to_rad(additionalYawRotation) - dir_to_angles(hero_transform[0]).x, rotTM)
    controller_transform = controller_transform * rotTM


[es(tag=gameClient, after=update_diy_building_preview_controller_tm, REQUIRE_NOT=diyPreviewControllerServer)]
def update_diy_building_preview(act : UpdateStageInfoAct;
                                preview__ownerEid : EntityId;
                                diy__previewEids : EidList;
                                preview__validColor : float3;
                                preview__invalidColor : float3;
                                preview__spectatingColor : float3;
                                preview__allowedMinAngle : float;
                                transform aka controller_transform : float3x4)
  let isSpectating = !has(preview__ownerEid, "hero")
  let angleTest = abs(dir_to_angles(controller_transform[1]).y) * RAD_TO_DEG >= preview__allowedMinAngle

  for prevEid in diy__previewEids
    query(prevEid) <| $ [es] (var transform aka preview_transform : float3x4;
                              diy__offsetTm : float3x4;
                              previewCollobj : CollisionObject;
                              previewCollres : CollisionResource const?;
                              var semi_transparent__placingColor : float3&;
                              var area_of_visibility__color1 : E3DCOLOR?)

      preview_transform = controller_transform * diy__offsetTm

      let isValid = isSpectating || angleTest && check_available_preview_pos(preview_transform, previewCollobj, previewCollres)
      semi_transparent__placingColor = isSpectating ? preview__spectatingColor : (isValid ? preview__validColor : preview__invalidColor)
      if area_of_visibility__color1 != null
        *area_of_visibility__color1 = E3DCOLOR(isValid ? 0x0000FF00 : 0x00FF0000)


[es(tag=server)]
def on_diy_building_rq_create(evt : RqDiyCreate; eid aka hero_eid : EntityId; diy__activeBlueprintTemplate : string)
  find_query() <| $ [es] (game_effect__attachedTo : EntityId;
                          diy__previewControllerServerTempl : string;
                          var diy__serverPreviewControllerEid : EntityId&)
    if game_effect__attachedTo == hero_eid
      if diy__serverPreviewControllerEid == INVALID_ENTITY_ID
        find_query() <| $ [es] (var construction__nextId : int&)
          let instanceId = construction__nextId++
          diy__serverPreviewControllerEid = createEntity(add_sub_template_name(diy__previewControllerServerTempl, diy__activeBlueprintTemplate)) <| $(init)
            init |> set("preview__ownerEid", hero_eid)
            init |> set("transform", evt.previewTransform)
            init |> set("diy__buildingInstanceId", instanceId)
          return true
    return game_effect__attachedTo == hero_eid


[es(tag=server, on_appear)]
def init_building_controller(evt : Event;
                             eid aka ctrl_eid : EntityId;
                             construction__instanceId aka ctrl_construction__instanceId : int;
                             @shared_comp diy_blueprint__data : Object;
                             var building_ctrl__buildingsToInit : int&)
  let items = diy_blueprint__data.items ?as Array
  building_ctrl__buildingsToInit = length(*items)
  query() <| $ [es] (construction__instanceId aka building_construction__instanceId : int;
                     eid aka building_eid : EntityId)
    if ctrl_construction__instanceId == building_construction__instanceId && building_eid != ctrl_eid
      building_ctrl__buildingsToInit--
    //building_ctrl__buildingsToInit cannot reach 0 here because the controller itself is skipped
    if building_ctrl__buildingsToInit == 0
      logerr("DIY: something has gone terribly wrong.")


[es(tag=server, on_appear, after=init_building_controller)]
def register_building(evt : Event;
                      construction__instanceId aka building_construction__instanceId : int)
  find_query() <| $ [es] (construction__instanceId aka ctrl_construction__instanceId : int;
                          eid : EntityId;
                          var building_ctrl__buildingsToInit : int&)
    if ctrl_construction__instanceId == building_construction__instanceId
      building_ctrl__buildingsToInit--
      if building_ctrl__buildingsToInit == 0
        remote_add_sub_template(eid, "completed_construction")
    return ctrl_construction__instanceId == building_construction__instanceId


[es(tag=server, on_appear, after=(diy_preview_animchar_collobj_init, diy_preview_rendinst_collobj_init), REQUIRE=diyPreviewServer)]
def on_diy_building_preview_appear_server(evt : Event; preview__controllerEid aka preview__controllerEid_newlyCreated : EntityId)
  //when server preview is created - see if it's the last one we need
  query(preview__controllerEid_newlyCreated) <| $ [es] (var diy__previewsCreatedCount : int&;
                                                        diy__previewEids : EidList;
                                                        preview__ownerEid : EntityId;
                                                        preview__radius : float;
                                                        preview__allowedMinAngle : float;
                                                        transform : float3x4;
                                                        building_ctrl__blueprintTemplate : string;
                                                        diy__buildingInstanceId : int)
    diy__previewsCreatedCount++
    if diy__previewsCreatedCount == length(diy__previewEids)
      //If it's the last one - check that all previews are valid

      let angleTest = abs(dir_to_angles(transform[1]).y) * RAD_TO_DEG >= preview__allowedMinAngle
      var hasInvalid = !angleTest
      query(preview__ownerEid) <| $ [es] (human__aimTm : float3x4;
                                          team : int;
                                          diy__abilityName : string;
                                          var diy__forcedBlueprintStashIdx : int&;
                                          var diy__movedBuildEid : EntityId&)
        let delayCompensation = 0.1f
        let radius = preview__radius + delayCompensation
        let distanceTest = distance_sq(transform[3], human__aimTm[3]) <= square(radius)
        hasInvalid &&= !distanceTest
        find_query() <| $ [es(REQUIRE=diyPreviewServer)] (diy__offsetTm : float3x4;
                                                          preview__controllerEid aka preview__controllerEid_i : EntityId;
                                                          previewCollobj : CollisionObject;
                                                          previewCollres : CollisionResource const?)
          if preview__controllerEid_i == preview__controllerEid_newlyCreated
            let tm = transform * diy__offsetTm
            if !check_available_preview_pos(tm, previewCollobj, previewCollres)
              hasInvalid = true
              //TODO: check normalizeToGround/Wall too
          return hasInvalid
        if !hasInvalid
          //If all are valid - place them
          query() <| $ [es(REQUIRE=diyPreviewServer)] (eid : EntityId;
                                                       diy__offsetTm : float3x4;
                                                       preview__controllerEid aka preview__controllerEid_i : EntityId;
                                                       preview__result : string)
            if preview__controllerEid_i == preview__controllerEid_newlyCreated
              let tm = transform * diy__offsetTm
              let templ = getTemplateByName(preview__result)
              let templateName = templ != null && templateHasComponent(*templ, "building_ctrl__buildingsToInit") ? add_sub_template_name(preview__result, building_ctrl__blueprintTemplate) : preview__result
              createEntity(templateName) <| $(init)
                init |> set("transform", tm)
                init |> set("ownerEid", preview__ownerEid)
                init |> set("construction__instanceId", diy__buildingInstanceId)
                init |> set("building_ctrl__buildingsToInit", diy__previewsCreatedCount)
                init |> set("team", team)
              destroyEntity(eid)
          sendEvent(preview__ownerEid, EventBuildPlaced(blueprintName = building_ctrl__blueprintTemplate, movedBuildingEid = diy__movedBuildEid, stashIdx = diy__forcedBlueprintStashIdx))
          diy__movedBuildEid = INVALID_ENTITY_ID
          diy__forcedBlueprintStashIdx = -1
          sendEvent(preview__ownerEid, CmdSkipActiveAbility(ability_name = diy__abilityName))
          broadcast_net_sound(preview__ownerEid, "use_repairkit", transform[3])
          send_net_event(preview__ownerEid, DiyAbilityAppearEffect(pos = transform[3]))
        else
          send_net_event(preview__ownerEid, ShowStatusTip(statusTip = "status_tip_on_diy_rq_create_error_wrong_place"))
      find_query() <| $ [es] (game_effect__attachedTo : EntityId; var diy__serverPreviewControllerEid : EntityId&)
        if game_effect__attachedTo == preview__ownerEid
          diy__serverPreviewControllerEid = INVALID_ENTITY_ID
        return game_effect__attachedTo == preview__ownerEid
      destroyEntity(preview__controllerEid)


[es(tag=server, on_disappear, REQUIRE=diy_temporary_entity)]
def end_ability_on_drone_dead(evt : Event; drone__owner : EntityId)
  query(drone__owner) <| $ [es] (diy__abilityName : string)
    sendEvent(drone__owner, CmdSkipActiveAbility(ability_name = diy__abilityName))


[es(tag=gameClient, REQUIRE=hero, no_order)]
def select_diy_usable_device(act : UpdateStageInfoAct;
                             eid aka hero_eid : EntityId;
                             diy__activeDevice : EntityId;
                             diy__selectDeviceMinDot : float;
                             var diy__selectedDevice : EntityId&)
  if diy__activeDevice != INVALID_ENTITY_ID
    return
  find_query() <| $ [es] (camera__active : bool; transform aka camera_transform : float3x4)
    if camera__active
      diy__selectedDevice = INVALID_ENTITY_ID
      var bestDot = -1.0
      query() <| $ [es(REQUIRE=diy__usableDevice)] (eid aka device_eid : EntityId; transform : float3x4; ownerEid : EntityId)
        if ownerEid == hero_eid
          let deviceDot = dot(normalize(transform[3] - camera_transform[3]), camera_transform[2])
          if deviceDot >= diy__selectDeviceMinDot && deviceDot > bestDot
            diy__selectedDevice = eid
            bestDot = deviceDot
    return camera__active


[es(tag=gameClient, on_appear, REQUIRE=(watchedByPlr, diyAbility))]
def watch_diy_deviced_on_owner_became_watched(evt : Event; eid aka owner_eid : EntityId)
  query() <| $ [es(REQUIRE=diy__usableDevice)] (eid aka device_eid : EntityId; ownerEid : EntityId)
    if ownerEid == owner_eid
      addSubTemplate(device_eid, "diy_owned_by_watched")


[es(tag=gameClient, on_disappear, REQUIRE=(watchedByPlr, diyAbility))]
def stop_watching_diy_deviced_on_owner_not_watched(evt : Event; eid aka owner_eid : EntityId)
  query() <| $ [es(REQUIRE=(diy__usableDevice, ownedByWatched))] (eid aka device_eid : EntityId; ownerEid : EntityId)
    if ownerEid == owner_eid
      removeSubTemplate(device_eid, "diy_owned_by_watched")


[es(tag=gameClient, on_appear, REQUIRE=diy__usableDevice)]
def watch_diy_deviced_if_owner_is_watched(evt : Event; eid, ownerEid : EntityId)
  if has(ownerEid, "watchedByPlr")
    addSubTemplate(eid, "diy_owned_by_watched")


//This happens when loading scene with buildings
[es(tag=server, on_appear)]
def update_id_holder_on_building_appear(evt : Event; construction__instanceId : int)
  find_query() <| $ [es] (var construction__nextId : int&)
    construction__nextId = max(construction__nextId, construction__instanceId + 1)
    return true

