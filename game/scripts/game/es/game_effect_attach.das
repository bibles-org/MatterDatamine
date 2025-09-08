require ecs
require game.events.events_game
require game.events.events_active_matter


[es(on_appear, track=game_effect__attachedTo)]
def game_effect_attached_es(evt : Event; eid, game_effect__attachedTo : EntityId; var game_effect__lastAttachedTo : EntityId&)
  if game_effect__attachedTo != INVALID_ENTITY_ID
    game_effect__lastAttachedTo = game_effect__attachedTo
    sendEventImmediate(eid, GameEffectStateChanged(attachedTo = game_effect__attachedTo, activated = true))


[es(track=game_effect__attachedTo)]
def game_effect_detached_es(evt : Event; eid, game_effect__attachedTo : EntityId; var game_effect__lastAttachedTo : EntityId&)
  if !game_effect__attachedTo && game_effect__lastAttachedTo != INVALID_ENTITY_ID
    sendEventImmediate(eid, GameEffectStateChanged(attachedTo = game_effect__lastAttachedTo, activated = false))
    game_effect__lastAttachedTo = INVALID_ENTITY_ID


[es(on_disappear)]
def game_effect_destroyed_es(evt : Event; eid, game_effect__attachedTo : EntityId)
  sendEventImmediate(eid, GameEffectStateChanged(attachedTo = game_effect__attachedTo, activated = false))


[es(on_event=EventEntityRecreated)]
def game_effect_recreated_es(evt : Event; eid, game_effect__attachedTo : EntityId; var game_effect__lastAttachedTo : EntityId&)
  if game_effect__attachedTo != INVALID_ENTITY_ID
    sendEventImmediate(eid, GameEffectStateChanged(attachedTo = game_effect__attachedTo, activated = true))
  if game_effect__attachedTo != game_effect__lastAttachedTo && game_effect__lastAttachedTo != INVALID_ENTITY_ID
    sendEventImmediate(eid, GameEffectStateChanged(attachedTo = game_effect__lastAttachedTo, activated = false))
    game_effect__lastAttachedTo = game_effect__attachedTo


[es(tag=server, on_appear)]
def game_effect_initial_attachments_server(evt : Event; eid : EntityId; game_effect__initialAttachmentsServer : StringList)
  for it in game_effect__initialAttachmentsServer
    createEntity(string(it)) <| $(init)
      init |> set("game_effect__attachedTo", eid)


[es(on_appear)]
def game_effect_initial_attachments(evt : Event; eid : EntityId; game_effect__initialAttachments : StringList)
  for it in game_effect__initialAttachments
    createEntity(string(it)) <| $(init)
      init |> set("game_effect__attachedTo", eid)


[es(tag=server)]
def game_effect_attachments_after_teleport_server(evt : EventNPhysTeleported;
                                                  eid : EntityId;
                                                  game_effect__attachmentsAfterTeleportServer : StringList)
  for it in game_effect__attachmentsAfterTeleportServer
    createEntity(string(it)) <| $(init)
      init |> set("game_effect__attachedTo", eid)


[es(tag=server, track=beh_tree__enabled)]
def game_effect_beh_tree_state_attachments(evt : Event;
                                           eid : EntityId;
                                           beh_tree__enabled : bool;
                                           game_effect__behTreeStateAttachments : StringList;
                                           var game_effect__behTreeStateAttachmentsEids : EidList)
  if beh_tree__enabled
    for it in game_effect__behTreeStateAttachments
      let effectEid = createEntity(string(it)) <| $(init)
        init |> set("game_effect__attachedTo", eid)
      game_effect__behTreeStateAttachmentsEids |> push(effectEid)
  else
    for effectEid in game_effect__behTreeStateAttachmentsEids
      destroyEntity(effectEid)
    game_effect__behTreeStateAttachmentsEids |> clear()
