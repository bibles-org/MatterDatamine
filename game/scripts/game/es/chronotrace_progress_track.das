require ecs
require ecs.common
require game.events.events_game
require game.events.events_active_matter
require DngDm
require danetlibs.weapons.melee_events
require game.es.chronotrace_progress_track_common


[es(tag=server, REQUIRE=raid_mode)]
def chronotrace_progress_on_kill(evt : EventAnyEntityDied)
  if evt.offender == evt.victim
    return

  query(evt.offenderPlayer) <| $ [es(REQUIRE_NOT=playerIsBot)] (var player__chronotracesProgression : Object)
    query(evt.victim) <| $ [es] (possessedByPlr : EntityId const?;
                                 hitpoints__lastOffenderWeapon : EntityId = INVALID_ENTITY_ID)
      let prefix = identify_victim(possessedByPlr, null)
      let gunTemplate = get_gun_template_by_props_id(evt.gunPropsId)
      var mainTemplate = split_template(gunTemplate)[0]
      if mainTemplate == "xvp_grenade_thrower"
        mainTemplate = split_template(get_shell_template_by_shell_id(evt.shellId))[0]

      item_add_progress(player__chronotracesProgression, mainTemplate, "{prefix}_kills")
      if hitpoints__lastOffenderWeapon != INVALID_ENTITY_ID
        let eidGunTemplate = split_template(getEntityTemplateName(hitpoints__lastOffenderWeapon))[0]
        if eidGunTemplate == mainTemplate
          query(hitpoints__lastOffenderWeapon) <| $ [es] (gun_mods__curModInSlots : Object)
            for mod in gun_mods__curModInSlots
              let modEid = get_Eid(mod.value) ?? INVALID_ENTITY_ID
              let modTemplate = getEntityTemplateName(modEid)
              let mainModeTemplate = split_template(modTemplate)[0]
              item_add_progress(player__chronotracesProgression, mainModeTemplate, "{prefix}_kills")


[es(tag=server, REQUIRE=raid_mode)]
def chronotrace_progress_on_hit_entity_with_hp(evt : ProjectileOnHitEntityWithHp)
  if evt.offender == evt.victim
    return

  query(evt.offender) <| $ [es] (possessedByPlr : EntityId)
    query(possessedByPlr) <| $ [es(REQUIRE_NOT=playerIsBot)] (var player__chronotracesProgression : Object)
      query(evt.victim) <| $ [es(REQUIRE_NOT=deadEntity)] (possessedByPlr : EntityId const?; anomaly_trap : Tag const?)
        let prefix = identify_victim(possessedByPlr, anomaly_trap)
        let gunEid = evt.gun_eid
        let gunTemplate = getEntityTemplateName(gunEid)
        let mainTemplate = split_template(gunTemplate)[0]
        item_add_progress(player__chronotracesProgression, mainTemplate, "{prefix}_hits")
        query(gunEid) <| $ [es] (gun_mods__curModInSlots : Object)
          for mod in gun_mods__curModInSlots
            let modEid = get_Eid(mod.value) ?? INVALID_ENTITY_ID
            let modTemplate = getEntityTemplateName(modEid)
            let mainModeTemplate = split_template(modTemplate)[0]
            item_add_progress(player__chronotracesProgression, mainModeTemplate, "{prefix}_hits")


[es(tag=server)]
def chronotrace_progress_on_shell_hit(evt : EventShellExplodedServer;
                                      eid : EntityId;
                                      shell__owner : EntityId;
                                      shell__affectedEntities : EidList)
  let mainTemplate = split_template(getEntityTemplateName(eid))[0]
  query(shell__owner) <| $ [es] (possessedByPlr : EntityId)
    query(possessedByPlr) <| $ [es(REQUIRE_NOT=playerIsBot)] (var player__chronotracesProgression : Object)
      for victim in shell__affectedEntities
        if victim == shell__owner
          continue // we don't promote self-harm!
        query(victim) <| $ [es(REQUIRE_NOT=deadEntity)] (possessedByPlr : EntityId const?; anomaly_trap : Tag const?)
          let prefix = identify_victim(possessedByPlr, anomaly_trap)
          item_add_progress(player__chronotracesProgression, mainTemplate, "{prefix}_hits")


[es(tag=server, REQUIRE_NOT=deadEntity)]
def chronotrace_progress_on_fire_damage(evt : EventEntityDamagedByFireZone;
                                        eid aka victim_eid : EntityId;
                                        possessedByPlr : EntityId const?; anomaly_trap : Tag const?)
  let prefix = identify_victim(possessedByPlr, anomaly_trap)
  query(evt.zone) <| $ [es] (dmgzone__burningOffender : EntityId;
                             fire_source__gunPropsId : int = -1;
                             fire_source__shellId : int = -1)
    var itemTemplate = ""
    if fire_source__shellId != -1
      itemTemplate = split_template(get_shell_template_by_shell_id(fire_source__shellId))[0]
    elif fire_source__gunPropsId != -1
      itemTemplate = split_template(get_gun_template_by_props_id(fire_source__gunPropsId))[0]
    else
      return

    if victim_eid == dmgzone__burningOffender
      return
    query(dmgzone__burningOffender) <| $ [es] (possessedByPlr : EntityId)
      query(possessedByPlr) <| $ [es(REQUIRE_NOT=playerIsBot)] (var player__chronotracesProgression : Object)
        item_add_progress(player__chronotracesProgression, itemTemplate, "{prefix}_hits")


[es(tag=server)]
def chronotrace_progress_on_shell_launched(evt : CmdLaunchShell; possessedByPlr : EntityId)
  query(evt.gunEid) <| $ [es(REQUIRE=grenade_thrower__projectileEntity)] ()
    query(possessedByPlr) <| $ [es(REQUIRE_NOT=playerIsBot)] (var player__chronotracesProgression : Object)
      let itemTemplate = split_template(get_shell_template_by_shell_id(int(evt.launchDesc.shellId.shellId)))[0]
      item_add_progress(player__chronotracesProgression, itemTemplate, "uses")


[es(tag=server)]
def chronotrace_progress_on_heal_item_used(evt : EventHealItemUsed; eid : EntityId; item__humanOwnerEid : EntityId)
  let itemTemplate = split_template(getEntityTemplateName(eid))[0]
  query(item__humanOwnerEid) <| $ [es] (possessedByPlr : EntityId)
    query(possessedByPlr) <| $ [es(REQUIRE_NOT=playerIsBot)] (var player__chronotracesProgression : Object)
      item_add_progress(player__chronotracesProgression, itemTemplate, "uses")


[es(tag=server)]
def chronotrace_progress_on_armor_block_damage(evt : CmdDamageItem; eid : EntityId; item__humanOwnerEid : EntityId)
  let itemTemplate = split_template(getEntityTemplateName(eid))[0]
  query(item__humanOwnerEid) <| $ [es] (possessedByPlr : EntityId)
    query(possessedByPlr) <| $ [es(REQUIRE_NOT=playerIsBot)] (var player__chronotracesProgression : Object)
      item_add_progress(player__chronotracesProgression, itemTemplate, "damaged", int(evt.damage))


[es(tag=server)]
def chronotrace_progress_on_melee_hit(evt : EventMeleeAttackHit; possessedByPlr : EntityId; human_weap__currentGunEid : EntityId)
  query(possessedByPlr) <| $ [es(REQUIRE_NOT=playerIsBot)] (var player__chronotracesProgression : Object)
    query(evt.targetEid) <| $ [es] (possessedByPlr : EntityId const?; anomaly_trap : Tag const?)
      let prefix = identify_victim(possessedByPlr, anomaly_trap)
      let itemTemplate = split_template(getEntityTemplateName(human_weap__currentGunEid))[0]
      item_add_progress(player__chronotracesProgression, itemTemplate, "{prefix}_hits")
