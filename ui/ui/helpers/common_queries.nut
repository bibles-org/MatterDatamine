from "dagor.math" import Point3

from "%sqstd/ecs.nut" import *


let get_transformQuery = SqQuery("get_transformQuery", {
  comps_ro=[
    ["transform", TYPE_MATRIX]
  ]
})

function get_transform(eid) {
  return get_transformQuery.perform(eid, @(_eid, comp) comp)?.transform
}

function get_pos(eid) {
  let transform = get_transform(eid)
  return transform?[3] ?? Point3(0, 0, 0)
}

let get_animcharAttachAttachedToQuery = SqQuery("get_animcharAttachAttachedToQuery", {
  comps_ro=[
    ["animchar_attach__attachedTo", TYPE_EID]
  ]
})

function get_animchar_attach__attachedTo(eid) {
  return get_animcharAttachAttachedToQuery.perform(eid, @(_eid, comp) comp)?.animchar_attach__attachedTo
}

return {
  get_transform
  get_pos
  get_animchar_attach__attachedTo
}
