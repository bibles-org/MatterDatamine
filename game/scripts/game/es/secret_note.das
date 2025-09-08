require ecs
require DagorRandom
require DngNet
require game.events.inventory_events
require game.events.events

[es(tag=server, on_appear)]
def init_secret_lootable_ri_msg(evt : Event; secret_lootable_rendinst__questMsgOptions : StringList; var secret_lootable_rendinst__questMsg : das_string&)
  secret_lootable_rendinst__questMsg := secret_lootable_rendinst__questMsgOptions[grnd() % length(secret_lootable_rendinst__questMsgOptions)]


[es(tag=server)]
def on_secret_note_picked_up(evt : EventOnItemPickup; transform aka hero_transform : float3x4)
  query(evt.itemEid) <| $ [es] (var key__tags : StringList; var secret_note__linkedContainerEid : EntityId&; var item__useMessage : das_string&)
    print("Secret_note <{evt.itemEid}> picked up. linkedContainerEid {secret_note__linkedContainerEid}")
    if secret_note__linkedContainerEid == INVALID_ENTITY_ID
      var bestRiEid = INVALID_ENTITY_ID
      var bestDst = FLT_MAX
      query() <| $ [es(REQUIRE=(secret_lootable_rendinst, secret_lootable_rendinst__questMsg))] (eid : EntityId;
                                                                                                 locked__keyTags : StringList;
                                                                                                 transform aka ri_transform : float3x4)
        if empty(locked__keyTags)
          let dst = distance_sq(hero_transform[3], ri_transform[3])
          if dst < bestDst
            bestDst = dst
            bestRiEid = eid
      print("Secret_note <{evt.itemEid}>. bestRiEid {bestRiEid} best dst: {bestDst}")
      query(bestRiEid) <| $ [es] (var locked__keyTags : StringList; secret_lootable_rendinst__questMsg : string)
        let keyTag = "secret_note{evt.itemEid}"
        key__tags |> push(keyTag)
        locked__keyTags |> push(keyTag)
        secret_note__linkedContainerEid = bestRiEid
        item__useMessage := secret_lootable_rendinst__questMsg
    query(evt.toInventoryEid) <| $ [es] (eid : EntityId; item__humanOwnerEid : EntityId = INVALID_ENTITY_ID; possessedByPlr : EntityId = INVALID_ENTITY_ID)
      var qEid = INVALID_ENTITY_ID
      if item__humanOwnerEid != INVALID_ENTITY_ID
        qEid = item__humanOwnerEid
      elif possessedByPlr != INVALID_ENTITY_ID
        qEid = eid
      else
        print("Picked up secret note by the actor doesn't have player. A bot? Or a bug? <{evt.toInventoryEid}>({getEntityTemplateName(evt.toInventoryEid)})")
      query(qEid) <| $ [es] (possessedByPlr : EntityId)
        query(possessedByPlr) <| $ [es] (connid : int)
          if connid != INVALID_CONNECTION_ID && get_client_connection(connid) != null
            broadcastEventImmediate(CmdAddEntityInNetScope(connid = connid, entityEid = secret_note__linkedContainerEid))


[es(tag=gameClient, on_appear, track=secret_note__linkedContainerEid)]
def sync_secret_note_message(evt : Event; eid, secret_note__linkedContainerEid : EntityId; var item__useMessage : das_string&)
  var qSuccess = false
  query(secret_note__linkedContainerEid) <| $ [es] (secret_lootable_rendinst__questMsg : string)
    item__useMessage := secret_lootable_rendinst__questMsg
    qSuccess = true
  print("Secret note <{eid}> appeared or changed. linked to {secret_note__linkedContainerEid}. qSuccess={qSuccess}")


[es(tag=gameClient, on_appear, REQUIRE=secret_lootable_rendinst)]
def sync_secret_note_message_on_ri_spawned(evt : Event; eid aka ri_eid : EntityId; secret_lootable_rendinst__questMsg : string)
  var qSuccess = false
  var noteEid = INVALID_ENTITY_ID
  find_query() <| $ [es] (secret_note__linkedContainerEid : EntityId; eid aka note_eid : EntityId; var item__useMessage : das_string&)
    if secret_note__linkedContainerEid == ri_eid
      noteEid = note_eid
      item__useMessage := secret_lootable_rendinst__questMsg
      qSuccess = true
      return true
    return false
  print("Secret lootable rendinst <{eid}> appeared. note: <{noteEid}> qSuccess: {qSuccess}")