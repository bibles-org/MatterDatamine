require ecs
require strings
require AnimV20
require GeomNodeTree


[es(tag=gameClient, on_appear, REQUIRE=human)]
def apply_violence_settings_to_humans(evt : Event; eid : EntityId)
  query() <| $ [es] (isGoreEnabled : bool)
    if isGoreEnabled
      addSubTemplate(eid, "human_broken_bones")
    else
      removeSubTemplate(eid, "human_broken_bones")

[es(tag=gameClient, on_appear, REQUIRE=attachableBrokenBonesWear, before=preload_projective_wounds_index_es)]
def apply_violence_settings_to_attachable_wear(evt : Event; eid : EntityId)
  query() <| $ [es] (isGoreEnabled : bool; isBloodEnabled : bool)
    if isGoreEnabled
      addSubTemplate(eid, "attachable_wear_broken_bones_data")
    else
      removeSubTemplate(eid, "attachable_wear_broken_bones_data")

    if isBloodEnabled
      addSubTemplate(eid, "attachable_wear_projective_wounds_data")
    else
      removeSubTemplate(eid, "attachable_wear_projective_wounds_data")


[es(tag=render, on_appear, after=apply_violence_settings_to_attachable_wear)]
def preload_projective_wounds_index_es(evt : Event;
                                       animchar : AnimcharBaseComponent;
                                       var projective_wounds__allowedSkeletonNodes : IntList&)
  for i in range(animchar.nodeTree.nodeCount)
    let nodeName = *animchar.nodeTree |> geomtree_getNodeName(i)
    if -1 != nodeName |> find("Bip01")
      projective_wounds__allowedSkeletonNodes |> push(i)
