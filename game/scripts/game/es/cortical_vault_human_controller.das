require ecs
require ecs.safe
require ecs.common
require app
require math.base
require math.random
require DagorRandom
require game.events.events
require game.events.events_active_matter
require game.es.cortical_vault_human_controller_common
require game.es.inventory_item_common
require game.es.ecs_common
require game.es.grav_zones_common
require game.utils.team
require DngNet
require DagorMath
require Dacoll
require game.events.events_game
require DngDm
require DaWeaponProps


def start_hacking_cortical_vault_server(actor_eid : EntityId;
                                        militant_ragdoll_phys_obj_eid : EntityId;
                                        var cortical_vault_human_controller__hackingProcessEid : EntityId&)
  destroyEntity(cortical_vault_human_controller__hackingProcessEid)
  cortical_vault_human_controller__hackingProcessEid = INVALID_ENTITY_ID

  if is_hacking_cortical_vault_process_exists(militant_ragdoll_phys_obj_eid)
    return false

  cortical_vault_human_controller__hackingProcessEid = createEntitySync("hacking_cortical_vault_process") <| $(var init : ComponentsInitializer)
    init |> set("hacking_cortical_vault_process__ragdollPhysObjEid", militant_ragdoll_phys_obj_eid)
    init |> set("hacking_cortical_vault_process__hackerActorEid", actor_eid)

  return true


[es(tag=server)]
def cortical_vault_human_controller_use(evt : CmdUseAlt;
                                        eid aka militant_ragdoll_phys_obj_eid : EntityId)
  let useOption = calculate_militant_ragdoll_phys_obj_use_option(evt.requesterEid, militant_ragdoll_phys_obj_eid)

  if useOption == CorticalVaultHumanControllerUseOption.HACK_CORTICAL_VAULT
    query(evt.requesterEid) <| $ [es] (var cortical_vault_human_controller__hackingProcessEid : EntityId&)
      start_hacking_cortical_vault_server(evt.requesterEid, militant_ragdoll_phys_obj_eid,
                                          cortical_vault_human_controller__hackingProcessEid)


[es(tag=server, on_appear)]
def hacking_cortical_vault_process_appear(evt : Event;
                                          var hacking_cortical_vault_process__startedAt : float&)
  hacking_cortical_vault_process__startedAt = get_sync_time()


[es(tag=server, on_disappear, REQUIRE=hacking_cortical_vault_process)]
def hacking_cortical_vault_process_disappear(evt : Event;
                                             eid aka process_eid : EntityId)
  find_query() <| $ [es] (var cortical_vault_human_controller__hackingProcessEid : EntityId&)
    if cortical_vault_human_controller__hackingProcessEid == process_eid
      cortical_vault_human_controller__hackingProcessEid = INVALID_ENTITY_ID
      return true
    return false


[es(tag=server, no_order)]
def hacking_cortical_vault_process_update(act : UpdateStageInfoAct;
                                          eid aka process_eid : EntityId;
                                          hacking_cortical_vault_process__startedAt : float;
                                          hacking_cortical_vault_process__hackTime : float;
                                          hacking_cortical_vault_process__hackerActorEid : EntityId;
                                          hacking_cortical_vault_process__ragdollPhysObjEid : EntityId;
                                          hacking_cortical_vault_process__hackingDistancSqeMax : float = square(2.5))
  var isHackingProcessValid = false

  query(hacking_cortical_vault_process__hackerActorEid) <| $ [es(REQUIRE_NOT=deadEntity)] (transform aka hacker_transform : float3x4)
    query(hacking_cortical_vault_process__ragdollPhysObjEid) <| $ [es] (transform aka ragdoll_transform : float3x4;
                                                                        var am_storage__hacked : bool&)
      if distance_sq(hacker_transform[3], ragdoll_transform[3]) >= hacking_cortical_vault_process__hackingDistancSqeMax
        return

      if !am_storage__hacked

        if get_sync_time() - hacking_cortical_vault_process__startedAt >= hacking_cortical_vault_process__hackTime
          am_storage__hacked = true
          broadcast_net_event(EventAmStorageHacked(hackerActorEid = hacking_cortical_vault_process__hackerActorEid,
                                                          ragdollPhysObjEid = hacking_cortical_vault_process__ragdollPhysObjEid))

        isHackingProcessValid = true
  if !isHackingProcessValid
    destroyEntity(process_eid)


[es(tag=server)]
def cmd_human_stop_hacking_cortical_vault_request(evt : CmdHumanStopHackingCorticalVaultRequest;
                                                  cortical_vault_human_controller__hackingProcessEid : EntityId)
  destroyEntity(cortical_vault_human_controller__hackingProcessEid)


[es(tag=server)]
def hacked_cortical_vault_create_dogtag(evt : EventAmStorageHacked)
  query(evt.ragdollPhysObjEid) <| $ [es] (ragdoll_phys_obj__attachedTo : EntityId)
    query(ragdoll_phys_obj__attachedTo) <| $ [es] (possessedByPlr : EntityId;
                                                   cortical_vault_human_controller__dogtagItemTemplate : string;
                                                   cortical_vault_human_controller__dogtagDeathReason : string;
                                                   cortical_vault_human_controller__dogtagKilledByPlayerEid : EntityId;
                                                   cortical_vault_human_controller__dogtagKilledByPlayer : string;
                                                   cortical_vault_human_controller__dogtagKilledByWeapon : string;
                                                   createdByPlr = INVALID_ENTITY_ID)
      let ragdollPlayerEid = createdByPlr != INVALID_ENTITY_ID ? createdByPlr : possessedByPlr
      query(ragdollPlayerEid) <| $ [es] (name : string)
        create_item_in_inventory_container(cortical_vault_human_controller__dogtagItemTemplate, evt.hackerActorEid) <| $(var init : ComponentsInitializer)
          init |> set("playerItemOwner", ragdollPlayerEid)
          init |> set("cortical_vault_inactive__ownerNickname", name)
          init |> set("cortical_vault_inactive__killerPlayerEid", cortical_vault_human_controller__dogtagKilledByPlayerEid)
          init |> set("cortical_vault_inactive__killerNickname", cortical_vault_human_controller__dogtagKilledByPlayer)
          init |> set("cortical_vault_inactive__killedByWeapon", cortical_vault_human_controller__dogtagKilledByWeapon)
          init |> set("cortical_vault_inactive__deathReason", cortical_vault_human_controller__dogtagDeathReason)


[es(tag=server)]
def get_info_about_victim_for_dogtag(evt : EventAnyEntityDied;
                                     eid aka human_eid : EntityId;
                                     var cortical_vault_human_controller__dogtagDeathReason : das_string&;
                                     var cortical_vault_human_controller__dogtagKilledByPlayerEid : EntityId&;
                                     var cortical_vault_human_controller__dogtagKilledByPlayer : das_string&;
                                     var cortical_vault_human_controller__dogtagKilledByWeapon : das_string&)
  if evt.victim != human_eid
    return
  cortical_vault_human_controller__dogtagDeathReason := string(int(evt.damageType))
  query(evt.offender) <| $[es] (possessedByPlr : EntityId)
    cortical_vault_human_controller__dogtagKilledByPlayerEid = possessedByPlr
    query(possessedByPlr) <| $[es] (name : string)
      cortical_vault_human_controller__dogtagKilledByPlayer := name
  var weaponTempl := ""
  if evt.damageType == int(DamageType.DM_PROJECTILE) || evt.damageType == int(DamageType.DM_MELEE) || evt.damageType == int(DamageType.DM_BACKSTAB)
    weaponTempl := split_template(get_gun_template_by_props_id(evt.gunPropsId))[0]
  elif evt.damageType == int(DamageType.DM_EXPLOSION)
    shell_entity_get_props(int(evt.shellId)) <| $(entProps : ShellEntityTypeProps)
      weaponTempl := entProps.templName
  elif evt.damageType == int(DamageType.DM_FIRE)
    if !empty(get_gun_template_by_props_id(evt.gunPropsId))
      weaponTempl := split_template(get_gun_template_by_props_id(evt.gunPropsId))[0]
    elif int(evt.shellId) > -1
      shell_entity_get_props(int(evt.shellId)) <| $(entProps : ShellEntityTypeProps)
        weaponTempl := entProps.templName
  if !empty(weaponTempl)
    let weapTempl = getOrBuildTemplateByName(string(weaponTempl))
    if weapTempl != null
      cortical_vault_human_controller__dogtagKilledByWeapon := getTemplateComponent(*weapTempl, "item__name") ?? ""


[es(tag=server)]
def hacked_cortical_vault_map_mark(evt : EventAmStorageHacked)
  query(evt.ragdollPhysObjEid) <| $ [es] (transform aka ragdoll_transform : float3x4)
    let markTemplateName = "hacked_cortical_vault_map_mark"
    let markTemplate = getOrBuildTemplateByName(markTemplateName)
    if markTemplate != null
      var tm = IDENT_TM

      let markRadius = getTemplateComponent(*markTemplate, "map_object_zone__radius") ?? 0.0
      let offsetMult = getTemplateComponent(*markTemplate, "hacked_cortical_vault_map_mark__offsetMult") ?? float2(0.0)

      var horzOffsVec : float3
      sincos(rnd_float(0.0, TWOPI), horzOffsVec.z, horzOffsVec.x)
      horzOffsVec *= rnd_float(offsetMult) * markRadius

      tm[3] = ragdoll_transform[3] + horzOffsVec

      createEntity(markTemplateName) <| $(var init : ComponentsInitializer)
        init |> set("transform", tm)


[es(tag=server)]
def drop_am_on_cortical_vault_hacked(evt : EventAmStorageHacked)
  query(evt.ragdollPhysObjEid) <| $ [es] (transform : float3x4; am_storage__hackedAmPileTemplate : string; var am_storage__value : int&)
    if !empty(am_storage__hackedAmPileTemplate) && am_storage__value > 0
      let pileCount = max(1, am_storage__value |> float() |> sqrt() |> int())
      let avgRadius = cvt(float(pileCount), 0.0, 10.0, 0.0, 0.7)
      let startingAngle = gfrnd() * 2.0 * PI
      let angleStep = 2.0 * PI / float(pileCount)
      let up = -get_grav_dir(transform[3])
      let ax1 = get_normal(up)
      let ax2 = normalize(cross(up, ax1))
      for i in range(pileCount)
        let thisCount = (i + 1) * am_storage__value / pileCount - i * am_storage__value / pileCount
        let thisRadius = 0.1 + sqrt(gfrnd()) * avgRadius
        let thisAngle = startingAngle + angleStep * (float(i) + gfrnd() * 0.3)
        var norm : float3
        var t = 0.15 + gfrnd() * 0.75
        var s, c : float
        sincos(thisAngle, s, c)
        traceray_normalized(transform[3], up, t, norm, ETF_ALL)
        let from = transform[3] + up * t
        t = thisRadius
        let dir = normalize(ax1 * c + ax2 * s)
        traceray_normalized(from, dir, t, norm, ETF_ALL)
        var tm = IDENT_TM
        tm[3] = from + dir * t
        createEntity(am_storage__hackedAmPileTemplate) <| $(init)
          init |> set("transform", tm)
          init |> set("item__count", thisCount)
      am_storage__value = 0


[es(tag=server)]
def aim_punach_on_cortical_vault_hacked(evt : EventAmStorageHacked)
  query(evt.ragdollPhysObjEid) <| $ [es] (am_storage__hackAimPunchStrength : float; transform : float3x4)
    query(evt.hackerActorEid) <| $ [es] (var human_aim_punch__queuedEvents : Point3List; var human_aim_punch__curPower : float&)
      assume pwr = am_storage__hackAimPunchStrength
      human_aim_punch__queuedEvents |> push(float3(get_sync_time() + 0.3, pwr * 0.5 * (gfrnd() - 0.5), pwr * 0.5))
      human_aim_punch__curPower = max(human_aim_punch__curPower, pwr)
    find_query() <| $ [es(REQUIRE=msg_sink)] (eid : EntityId)
      sendEvent(
        eid,
        EventFlashExploded(
          pos = transform[3],
          tinnitusRad = float2(1.0, 2.0),
          flashRad = float2(5.0, 12.0),
          tinnitusPower = float2(1.5, 1.01),
          flashPower = float2(55, 17.01),
          flashDistExp = 1.0,
          tinnitusDistExp = 1.0,
          ignoreEid = INVALID_ENTITY_ID))
      return true


def update_ragdoll_phys_obj_am_provider_state(ragdoll_phys_obj_eid : EntityId)
  query(ragdoll_phys_obj_eid) <| $ [es] (ragdoll_phys_obj__attachedTo : EntityId;
                                         am_storage__value : int;
                                         am_storage__hacked : bool;
                                         var active_matter_pile_provider__amSourceEid : EntityId?;
                                         var active_matter_pile_provider__team : int?)

    let amProviderExists = active_matter_pile_provider__team != null
    var amProviderTeam = TEAM_UNASSIGNED

    if !am_storage__hacked
      query(ragdoll_phys_obj__attachedTo) <| $ [es] (createdByPlr : EntityId;
                                                     possessedByPlr : EntityId)
        let ragdollPlayerEid = createdByPlr != INVALID_ENTITY_ID ? createdByPlr : possessedByPlr
        amProviderTeam = get_int(ragdollPlayerEid, "team") ?? TEAM_UNASSIGNED

    // Add am provider
    if am_storage__value > 0
      if amProviderExists
        *active_matter_pile_provider__amSourceEid = ragdoll_phys_obj_eid
        *active_matter_pile_provider__team = amProviderTeam
      else
        addSubTemplate(ragdoll_phys_obj_eid, "active_matter_pile_provider") <| $(var init)
          init |> set("active_matter_pile_provider__amSourceEid", ragdoll_phys_obj_eid)
          init |> set("active_matter_pile_provider__team", amProviderTeam)
    elif am_storage__value <= 0 && amProviderExists
      removeSubTemplate(ragdoll_phys_obj_eid, "active_matter_pile_provider")


[es(on_appear, track=itemContainer, REQUIRE=(itemContainer, militant_ragdoll_phys_obj))]
def militant_ragdoll_phys_obj_track_item_container(evt : Event;
                                                   eid aka militant_ragdoll_phys_obj_eid : EntityId)
  update_ragdoll_phys_obj_am_provider_state(militant_ragdoll_phys_obj_eid)


[es(REQUIRE=militant_ragdoll_phys_obj)]
def on_active_matter_pile_provider_exhausted(evt : EventActiveMatterPileProviderExhausted;
                                             active_matter_pile_provider__amSourceEid : EntityId;
                                             eid aka militant_ragdoll_phys_obj_eid : EntityId)
  if !is_server()
    query(active_matter_pile_provider__amSourceEid) <| $ [es] (var am_storage__value : int&)
      am_storage__value = 0
  update_ragdoll_phys_obj_am_provider_state(militant_ragdoll_phys_obj_eid)


[es]
def cortical_vault_hacked(evt : EventAmStorageHacked)
  update_ragdoll_phys_obj_am_provider_state(evt.ragdollPhysObjEid)


[unused_argument(am_storage__value), es(on_appear, track=am_storage__value, REQUIRE=militant_ragdoll_phys_obj)]
def militant_ragdoll_phys_obj_track_cortical_vault_state(evt : Event; eid : EntityId; am_storage__value : int)
  update_ragdoll_phys_obj_am_provider_state(eid)
