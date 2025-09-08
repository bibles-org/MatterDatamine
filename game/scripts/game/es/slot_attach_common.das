module slot_attach_common shared
require ecs
require DngNet
require AnimV20
require DagorMath
require DagorSystem
require GeomNodeTree


def show_bad_slot_error(eid : EntityId;
                        slot_attach__slotId : int;
                        slot_attach__attachedTo : EntityId)
  let slotName = get_string(eid, "slot_attach__slotName", "")
  var slotDetails : string
  if slotName != ""
    slotDetails := " (slot_attach__slotName={slotName})"
  var potentialReason = "Did you forget to add a slot attachment in animchar blk?"
  if has_network()
    potentialReason := "{potentialReason} Or we have different slot indexes on the client and on the server? (@see anim::init_attachements)"
  logerr("{eid}<{getEntityTemplateName(eid)}>: Invalid attachment slotId={slot_attach__slotId}{slotDetails} (slot_attach__attachedTo={slot_attach__attachedTo}<{getEntityTemplateName(slot_attach__attachedTo)}>). {potentialReason}")


def slot_attach_init_tms_impl(dt : float;
                              eid : EntityId;
                              slot_attach__slotId : int;
                              slot_attach__attachedTo : EntityId;
                              var attachmentAnimChar : AnimcharBaseComponent&;
                              disableUpdate : Tag const?;
                              var animchar_node_wtm : AnimcharNodesMat44?;
                              var animchar_render__root_pos : vec4f?;
                              animchar__visible : bool = true;
                              slot_attach__calcAnim : bool = true;
                              force_update : bool = false;
                              force_animchar_act : bool = false)
  if slot_attach__slotId < 0 || !slot_attach__attachedTo
    return

  query(slot_attach__attachedTo) <| $ [es] (animchar : AnimcharBaseComponent;
                                            sleeping_animchar_update_toggle : Tag const?;
                                            animchar__actOnDemand : Tag const?;
                                            animchar__updatable : bool = true)
    if !force_update && sleeping_animchar_update_toggle != null
      return

    if animchar__updatable || animchar__actOnDemand != null
      var tmpTm : mat44f
      if !animchar_initAttachmentTmAndNodeWtm(animchar, slot_attach__slotId, tmpTm)
        show_bad_slot_error(eid, slot_attach__slotId, slot_attach__attachedTo)

      let wtmOfs = *animchar.nodeTree |> geomtree_getWtmOfs()
      animchar_setTmWithOfs(attachmentAnimChar, tmpTm, wtmOfs)
      if animchar__visible
        animchar_act(attachmentAnimChar, dt, (disableUpdate == null && slot_attach__calcAnim) || force_animchar_act)
      else
        animchar_recalc_wtm(attachmentAnimChar)
      if (animchar_node_wtm != null && animchar_render__root_pos != null)
        animchar_copy_nodes(attachmentAnimChar, *animchar_node_wtm, *animchar_render__root_pos)
