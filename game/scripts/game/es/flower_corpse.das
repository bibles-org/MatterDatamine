require ecs
require ecs.safe
require DngPhysObj
require DagorMath
require game.events.events_active_matter
require game.es.ecs_common


[es(tag=server, on_appear, REQUIRE=(deadEntity, human_net_phys))]
def dead_by_flowerhuman(evt : Event;
                        eid, killer : EntityId)
  if has(killer, "flowerHuman")
    addSubTemplate(eid, "flower_corpse")


[es(tag=server, after=phys_obj_phys_es)]
def flower_corpse_act(info : UpdateStageInfoAct;
                      eid : EntityId;
                      transform : float3x4;
                      ragdoll_phys_obj__physObjEid : EntityId;
                      var flower_corpse__decorData : Array;
                      var flower_corpse__flowersData : Array)
  query(ragdoll_phys_obj__physObjEid) <| $ [es] (phys_obj_net_phys : PhysObjActor)
    assume state = phys_obj_net_phys.phys.currentState
    // decor
    var idx = length(flower_corpse__decorData) - 1
    assume decor = flower_corpse__decorData[idx]
    while idx >= 0
      var obj = getRW_ecs_object(decor)
      if obj == null
        continue
      var timer = getRW_float(obj, "timer")
      if timer == null
        return
      *timer -= info.dt
      if *timer <= 0f
        let templateName = obj.templateName ?? ""
        let scaleTm = obj.scaleTm ?? 1f
        createEntity(templateName) <| $(init)
          var tm = transform
          tm[0] *= scaleTm
          tm[1] *= scaleTm
          tm[2] *= scaleTm
          tm[3] = float3(state.location.P)
          set(init, "transform", tm)
        erase(flower_corpse__decorData, idx)
      idx--
    // flowers
    idx = length(flower_corpse__flowersData) - 1
    assume flower = flower_corpse__flowersData[idx]
    while idx >= 0
      var obj = getRW_ecs_object(flower)
      if obj == null
        continue
      var timer = getRW_float(obj, "timer")
      if timer == null
        return
      *timer -= info.dt
      if *timer <= 0f
        let templateName = obj.templateName ?? ""
        let slot = obj.slot ?? ""
        let animchar = obj.animchar ?? ""
        createEntity(templateName) <| $(init)
          set(init, "slot_attach__slotName", slot)
          set(init, "slot_attach__attachedTo", eid)
          set(init, "animchar__res", animchar)
        erase(flower_corpse__flowersData, idx)
      idx--


// turning on ragdoll so that the flowers attachment can be attached to the corpse
[es(tag=render, on_appear, REQUIRE=attachedFlowerCorpse, before=(force_slot_attach_on_appear, force_slot_attach_on_parent_change_state))]
def attached_flower_corpse_enable_animchar_updatable(evt : Event;
                                                     slot_attach__attachedTo : EntityId)
  if isLoadingEntity(slot_attach__attachedTo)
    print("[FLOWER CORPSE] {get_entity_info(slot_attach__attachedTo)} is loading - enabling ragdoll async.")
    sendEvent(slot_attach__attachedTo, CmdEnableRagdoll())
  else
    sendEventImmediate(slot_attach__attachedTo, CmdEnableRagdoll())