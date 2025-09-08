require ecs
require ecs.common
require ecs.safe
require math.random
require strings


let
  EMPTY_PART_NAME = "EMPTY"


def attach_human_animchar_part(part_template : string;
                               human_eid : EntityId;
                               animchar_res : string)
  return createEntity(part_template) <| $ [es] (var init : ComponentsInitializer)
    init |> set("skeleton_attach__attached", true)
    init |> set("slot_attach__attachedTo", human_eid)
    init |> set("skeleton_attach__attachedTo", human_eid)
    init |> set("animchar__res", animchar_res)


[es(tag=gameClient, on_appear)]
def human_animchar_parts_init(evt : Event;
                              eid : EntityId;
                              human_animchar_parts__partTemplate : string;
                              @shared_comp human_animchar_parts__partsGenerator : Object;
                              human_animchar_parts__ignoreParts : StringList;
                              human_animchar_parts__enabled : bool = true)
  if !human_animchar_parts__enabled
    return

  for partData in human_animchar_parts__partsGenerator
    if human_animchar_parts__ignoreParts |> has_value(partData.key)
      continue

    let partInfo = partData.value as Object
    if partInfo == null
      continue

    var totalWeight = 0.0
    for part in *partInfo
      if part.key == EMPTY_PART_NAME && human_animchar_parts__enabled
        totalWeight += get_float(part.value) ?? 0.0
        continue
      totalWeight += get_float(part.value) ?? 0.0

    let rnd = eid_frnd(eid) * totalWeight

    var weigth = 0.0
    for part in *partInfo
      if part.key == EMPTY_PART_NAME && !human_animchar_parts__enabled
        continue
      weigth += get_float(part.value) ?? 0.0
      if weigth >= rnd
        if part.key == EMPTY_PART_NAME
          break
        attach_human_animchar_part(human_animchar_parts__partTemplate, eid, part.key)
        break

