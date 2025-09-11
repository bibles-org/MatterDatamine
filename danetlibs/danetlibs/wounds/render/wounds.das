require ecs
require DngWounds
require danetlibs.wounds.wounds_events

[es(tag=render, REQUIRE=human__breakable_bones)]
def reset_bones_damage_cmd_es(evt : CmdResetTornWoundBoneDamage)
  ecs::query(evt.eid) <| $ [es] (var attaches_list : ecs::EidList)
    for eid in attaches_list
      ecs::query(eid) <| $ [es] (var broken_bones_nodes : BrokenBonesNodes)
        for breakInst in broken_bones_nodes.breaks
          breakInst.accumulatedDamage = 0.0


[es(tag=render, on_disappear, REQUIRE=human__breakable_bones)]
def destroy_attached_gibs_es(evt : Event; eid : EntityId)
  let ownerBodyEid = eid
  ecs::query() <| $ [es(REQUIRE=attachable_gibs)] (eid, animchar_attach__attachedTo : EntityId)
    if animchar_attach__attachedTo == ownerBodyEid
      destroyEntity(eid)
