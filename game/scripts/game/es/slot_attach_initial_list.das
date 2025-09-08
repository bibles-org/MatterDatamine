require ecs
require DagorRandom


[es(on_appear, tag=server)]
def slot_attach_initial_attachments_init(evt : Event; eid : EntityId;
                                         slot_attach__initialAttachments : Object;
                                         var slot_attach__initialAttachmentEids : EidList)
  for attachment in slot_attach__initialAttachments
    let avaliableAnimcharNames = get_ecs_StringList(attachment.value)
    if avaliableAnimcharNames == null || length(*avaliableAnimcharNames) == 0
      continue
    let idx = rnd_int(0, length(*avaliableAnimcharNames) - 1)
    let animcharName = string((*avaliableAnimcharNames)[idx])
    if empty(animcharName)
      continue
    let attachmentEid = createEntity("attachable_dynamic_char") <| $(init)
      init |> set("slot_attach__attachedTo", eid)
      init |> set("animchar__res", animcharName)
      init |> set("slot_attach__slotName", attachment.key)
    slot_attach__initialAttachmentEids |> push(attachmentEid)


[es(on_disappear, tag=server)]
def slot_attach_initial_attachments_destroy(evt : Event; slot_attach__initialAttachmentEids : EidList)
  for attachmentEid in slot_attach__initialAttachmentEids
    destroyEntity(attachmentEid)
