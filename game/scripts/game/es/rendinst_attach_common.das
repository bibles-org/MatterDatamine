module rendinst_attach_common shared

require ecs
require RendInst
require Dacoll

def get_riex_attach_append_templates(riDesc : RendInstDesc | #;
                                     var out_eid : EntityId&;
                                     var out_is_destroyable, out_is_rotatable : bool&)
  var appendTemplates = ""
  if riDesc.isValid && riDesc.isRiExtra
    out_is_destroyable = riex_getInitialHP(riDesc.riExtraHandle) > 0.0
    if out_is_destroyable
      appendTemplates += "+rendinst_attach_destroyable"
    out_eid = find_ri_extra_eid(riDesc.riExtraHandle)
    out_is_rotatable = has(out_eid, "rendinst_axis_rotation__axis")
    if out_is_rotatable
      appendTemplates += "+rendinst_attach_rotatable"
  return <- appendTemplates
