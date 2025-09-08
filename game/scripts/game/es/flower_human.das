require ecs
require ecs.safe
require net
require DngNet
require math.base
require math.random
require ecs.common
require DagorMath
require DagorRandom
require game.events.events
require app
require pathfinder
require RendInst
require game.events.events_game
require game.es.ecs_common
require AnimV20
require GeomNodeTree
require DagorSystem
require CollRes
require DngDm
require DagorMathUtils
require game.events.events_active_matter
require game.es.equipment_common
require game.es.ai.agent_position_mapping_common


[es(tag=server, on_appear)]
def flower_human_with_root_apeear(evt : Event; transform : float3x4; flower_human__rootTemplate : string; anomaly_zone__ownerZoneEid = INVALID_ENTITY_ID)
  createEntity(flower_human__rootTemplate) <| $(ini)
    ini |> set("transform", transform)
    ini |> set("anomaly_zone__ownerZoneEid", anomaly_zone__ownerZoneEid)


[es(tag=server, on_appear, REQUIRE=objectsGenerationIsDone)]
def generate_flower_humans(evt : Event)
  find_query() <| $ [es] (flower_human_config__templateName : string;
                          flower_human_config__filling : float)

    if flower_human_config__filling <= 0f
      return true

    query() <| $ [es(REQUIRE=flowerHumanSpot)] (transform : float3x4)
      if gfrnd() < flower_human_config__filling
        createEntity(flower_human_config__templateName) <| $(init)
          init |> set("transform", transform)

    return true


[es(tag=server, on_appear, REQUIRE=flowerShell)]
def flower_shell_created_es(evt : Event;
                            slot_attach__attachedTo : EntityId;
                            item__armoredParts : ecs::Array;
                            var flower_shell__collNodeId : int&)
  ecs::query(slot_attach__attachedTo) <| $ [es] (collres : CollisionResource)
    for it in item__armoredParts
      let partName = get_string(it, "")
      if partName != ""
        flower_shell__collNodeId = collres_get_node_index_by_name(collres, partName)
        break


def remove_shell_armor(item__armorAmount : float;
                       item__armoredParts : Array;
                       dm_parts__parts : Object;
                       var dm_parts__partsArmor : FloatList;
                       var dm_parts__partsArmorMin : FloatList?;
                       var dm_parts__armorItemEids : EidList?)
  if item__armorAmount > 0.0
    for part in item__armoredParts
      let partId = get_part_data_node_id(dm_parts__parts, get_string(part, ""))
      if partId >= 0 && partId < length(dm_parts__partsArmor)
        dm_parts__partsArmor[partId] = 0.0
      if dm_parts__partsArmorMin != null && partId >= 0 && partId < length(*dm_parts__partsArmorMin)
        (*dm_parts__partsArmorMin)[partId] = 0.0
      if dm_parts__armorItemEids != null && partId >= 0 && partId < length(*dm_parts__armorItemEids)
        (*dm_parts__armorItemEids)[partId] = INVALID_ENTITY_ID


def remove_flower_shell(flower_human_eid : EntityId;
                        flower_shell_eid : EntityId;
                        direction : float3;
                        dm_parts__parts : Object;
                        var dm_parts__partsArmor : FloatList;
                        var dm_parts__partsArmorMin : FloatList?;
                        var dm_parts__armorItemEids : EidList?)
  query(flower_shell_eid) <| $ [es] (item__armorAmount : float;
                                     slot_attach__slotId : int;
                                     item__armoredParts : Array;
                                     var flower_shell__removed : bool&)
    send_net_event(flower_human_eid, EventFlowerFall(slotId = slot_attach__slotId, direction = direction))
    remove_shell_armor(item__armorAmount, item__armoredParts, dm_parts__parts,
                        dm_parts__partsArmor, dm_parts__partsArmorMin, dm_parts__armorItemEids)
    flower_shell__removed = true
    addSubTemplate(flower_shell_eid, "server_destroy_in_5_sec")


def process_flower_shells(flower_human_eid : EntityId;
                          hit_coll_node_id : int = -1;
                          hit_dir : float3 = float3())
  query(flower_human_eid) <| $ [es] (hitpoints__hp : float;
                                     hitpoints__maxHp : float;
                                     flower_human__initialAttachments : StringList;
                                     dm_parts__parts : Object;
                                     var dm_parts__partsArmor : FloatList;
                                     var dm_parts__partsArmorMin : FloatList?;
                                     var dm_parts__armorItemEids : EidList?)
    var attachments : array<EntityId>
    var hitAttachmentId = -1

    query() <| $ [es(REQUIRE=flowerShell)] (eid aka flower_shell_eid : EntityId;
                                            slot_attach__attachedTo : EntityId;
                                            flower_shell__collNodeId : int;
                                            flower_shell__removed : bool)
      if slot_attach__attachedTo != flower_human_eid || flower_shell__removed
        return

      if hit_coll_node_id != -1 && hit_coll_node_id == flower_shell__collNodeId
        hitAttachmentId = length(attachments)

      attachments |> push(flower_shell_eid)

    let hpRatio = hitpoints__hp / hitpoints__maxHp
    var attachmentsRatio = safediv(float(length(attachments)), float(length(flower_human__initialAttachments)))

    if attachmentsRatio > hpRatio && hitAttachmentId != -1
      remove_flower_shell(flower_human_eid, attachments[hitAttachmentId], hit_dir != float3() ? hit_dir : rnd_dir3(),
                          dm_parts__parts, dm_parts__partsArmor, dm_parts__partsArmorMin, dm_parts__armorItemEids)
      attachments |> erase(hitAttachmentId)
      attachmentsRatio = safediv(float(length(attachments)), float(length(flower_human__initialAttachments)))

    while attachmentsRatio > hpRatio && length(attachments) > 0
      let attachmentId = rnd_int(0, length(attachments) - 1)
      remove_flower_shell(flower_human_eid, attachments[attachmentId], hit_dir != float3() ? hit_dir : rnd_dir3(),
                          dm_parts__parts, dm_parts__partsArmor, dm_parts__partsArmorMin, dm_parts__armorItemEids)
      attachments |> erase(attachmentId)
      attachmentsRatio = safediv(float(length(attachments)), float(length(flower_human__initialAttachments)))


[es(tag=server, REQUIRE=flowerHuman)]
def flower_shell_hit_es(evt : EventOnEntityHit;
                        eid aka flower_human_eid : EntityId)
  if evt.victim != eid
    return

  process_flower_shells(flower_human_eid, evt.collNodeId, evt.hitNorm)


[es(tag=gameClient)] // don't process on server cause it's just visual effect
def fall_flower_on_event(evt : EventFlowerFall;
                         eid aka flowerman_eid : EntityId;
                         animchar : AnimcharBaseComponent)
  find_query() <| $ [es] (eid aka flower_eid : EntityId;
                          slot_attach__attachedTo : EntityId;
                          slot_attach__slotId : int;
                          flower_shell__addTemplateOnDestroy : string)
    if slot_attach__attachedTo == flowerman_eid && slot_attach__slotId == evt.slotId
      var tm = IDENT_TM
      tm[3] = *animchar.nodeTree |> geomtree_getNodeWpos(slot_attach__slotId)
      if distance_sq(tm[3], get_hidden_pos()) < 100.0
        return true // Don't creat phys actors in net stash
      let templ = is_server() ? flower_shell__addTemplateOnDestroy : "{flower_shell__addTemplateOnDestroy}+client_side"
      addSubTemplate(eid, templ) <| $(init)
        init |> set("phys_obj_thrust__direction", evt.direction)
        init |> set("slot_attach__attachedTo", INVALID_ENTITY_ID)
        init |> set("transform", tm)
      return true
    return false


[es(tag=server, REQUIRE=flowerHuman, no_order)]
def flower_human_destroy_doors(act : ParallelUpdateFrameDelayed; door_obstacle_handler__immediateDoor : EntityId)
  query(door_obstacle_handler__immediateDoor) <| $ [es] (eid : EntityId; ri_extra : RiExtraComponent; transform : float3x4)
    sendEvent(eid, CmdRendinstDamage(handle = ri_extra.handle, damage = 100000.0, pos = transform[3], impulse = float3(), time = get_sync_time()))


[es(tag=server, REQUIRE=flowerHuman)]
def flower_human_death_decor(evt : EventAnyEntityDied; eid : EntityId; flower_human__killSpawnTemplates : StringList)
  if evt.offender == eid
    query(evt.victim) <| $ [es] (transform : float3x4)
      for templateName in flower_human__killSpawnTemplates
        createEntity(string(templateName)) <| $(ini)
          var tm = IDENT_TM
          tm[3] = transform[3]
          ini |> set("transform", tm)


[es(tag=server, on_appear)]
def flower_human_delayed_spawner_appear(evt : Event; flower_human_delayer__spawnDelay : float2; var flower_human_delayer__spawnAt : float&)
  flower_human_delayer__spawnAt = get_sync_time() + rnd_float(flower_human_delayer__spawnDelay)


[es(tag=server, after=flower_human_delayed_spawner_appear)]
def flower_human_delayed_spawner_update(act : ParallelUpdateFrameDelayed;
                                        eid : EntityId;
                                        transform : float3x4;
                                        flower_human_delayer__spawnAt : float;
                                        flower_human_delayer__spawnTemplate : string)
  if flower_human_delayer__spawnAt > 0. && act.curTime > flower_human_delayer__spawnAt
    eid |> destroyEntity()
    createEntity(flower_human_delayer__spawnTemplate) <| $(ini)
      ini |> set("transform", transform)


[es(on_appear)]
def flower_human_initial_attachments(evt : Event; eid : EntityId; flower_human__initialAttachments : StringList)
  for templateName in flower_human__initialAttachments
    createEntity(string(templateName)) <| $(init)
      init |> set("slot_attach__attachedTo", eid)


[es(tag=server, on_appear, REQUIRE=(flower_human_bush, deadEntity))]
def flower_human_bush_on_death(evt : Event;
                               eid aka flower_human_eid : EntityId;
                               dm_parts__parts : Object;
                               var dm_parts__partsArmor : FloatList;
                               var dm_parts__partsArmorMin : FloatList?;
                               var dm_parts__armorItemEids : EidList?)
  query() <| $ [es(REQUIRE=flowerShell)] (slot_attach__attachedTo : EntityId;
                                          slot_attach__slotId : int;
                                          item__armorAmount : float;
                                          item__armoredParts : Array)
    if slot_attach__attachedTo != flower_human_eid
      return

    send_net_event(flower_human_eid, EventFlowerFall(slotId = slot_attach__slotId, direction = rnd_dir3()))
    remove_shell_armor(item__armorAmount, item__armoredParts, dm_parts__parts,
                        dm_parts__partsArmor, dm_parts__partsArmorMin, dm_parts__armorItemEids)

  addSubTemplate(flower_human_eid, "server_destroy_in_5_sec")


[es(tag=server, on_appear, REQUIRE=flowerHuman, after=navmeshmapping_init)]
def ensure_flowermen_are_on_navmesh(evt : Event; eid : EntityId; position_mapping__isOnSphere : bool; var transform : float3x4)
  let coordianteBefore = transform[3]
  var navPos = transform[3]
  var success = false
  if !position_mapping__isOnSphere
    success = project_to_nearest_navmesh_point(navPos, float3(2.0, 10.0, 2.0))
  else
    let mappingZone = navmesh_mapping_find_best_zone_for_position(coordianteBefore)
    navPos = navmesh_map_position_in_zone(coordianteBefore, mappingZone)
    success = project_to_nearest_navmesh_point(navPos, float3(2.0, 10.0, 2.0))
    navPos = navmesh_unmap_position_in_zone(navPos, mappingZone)
    validate_gameplay_position(navPos) <| $()
      return <- "coordianteBefore={coordianteBefore}, mappingZone={mappingZone}"
  transform[3] = navPos

  if !success
    logerr("Flowerman too far from navmesh. <{eid}>({getEntityTemplateName(eid)}). spawnedAt:[{coordianteBefore}]. No navmesh in sight.")
  elif distance_sq(coordianteBefore, transform[3]) > 5.0
    logerr("Flowerman too far from navmesh. <{eid}>({getEntityTemplateName(eid)}). spawnedAt:[{coordianteBefore}] dst:{distance(coordianteBefore, transform[3])}")