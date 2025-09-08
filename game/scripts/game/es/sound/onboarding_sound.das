require DngHuman
require ecs
require ecs.safe
require human_sounds.modules.human_steps_sound_common
require sound_utils.modules.sound_player_common


[es(tag=sound, on_event=EventDesiredHeroIrqHappened)]
def onboarding_play_step_on_irq(evt : Event; onboarding_play_step_on_irq__stepIrq : string)
  query() <| $ [es(REQUIRE=hero)] (eid : EntityId;
                                   transform : float3x4;
                                   human_steps_sound__traceStepOffsetLen : float2;
                                   human_sound_landmesh_queries__biomePhysMatId : int;
                                   human_sound_landmesh_queries__biomeOverridesWater : bool;
                                   human_sound_landmesh_queries__puddleDepth : float;
                                   sound_tags : Object;
                                   var human_steps_sound__waterDepth : float&;
                                   var human_steps_sound__smid : float&;
                                   var human_net_phys : HumanActor?;
                                   @shared_comp human_steps_sound__path : Object;
                                   @shared_comp human_steps_sound__irqs : Array)
    let irqIdx = find_index_if(each(human_steps_sound__irqs)) <| $(irqInfo : ChildComponent)
      let obj = irqInfo as Object
      let curIrq = obj?.irq ?? ""
      return curIrq == onboarding_play_step_on_irq__stepIrq

    let desc = human_steps_sound__irqs?[irqIdx] ?as Object
    if desc != null
      play_footstep(*desc,
                    human_steps_sound__path,
                    sound_tags,
                    1.0,
                    eid,
                    transform[3],
                    false,
                    true,
                    human_steps_sound__traceStepOffsetLen,
                    human_sound_landmesh_queries__biomePhysMatId,
                    human_sound_landmesh_queries__biomeOverridesWater,
                    human_sound_landmesh_queries__puddleDepth,
                    HUStandState.ESS_STAND,
                    human_steps_sound__smid,
                    human_steps_sound__waterDepth,
                    human_net_phys)


[es(tag=sound, on_event=EventDesiredHeroIrqHappened)]
def onboarding_play_step_from_desc_on_irq(evt : Event; onboarding_play_step_from_desc_on_irq__stepDescId : string)
  query() <| $ [es(REQUIRE=hero)] (eid : EntityId;
                                   transform : float3x4;
                                   human_steps_sound__traceStepOffsetLen : float2;
                                   human_sound_landmesh_queries__biomePhysMatId : int;
                                   human_sound_landmesh_queries__biomeOverridesWater : bool;
                                   human_sound_landmesh_queries__puddleDepth : float;
                                   sound_tags : Object;
                                   var human_steps_sound__waterDepth : float&;
                                   var human_steps_sound__smid : float&;
                                   var human_net_phys : HumanActor?;
                                   @shared_comp human_steps_sound__descs : Object;
                                   @shared_comp human_steps_sound__path : Object)
    let desc = sound_player_common::get_desc(human_steps_sound__descs, onboarding_play_step_from_desc_on_irq__stepDescId)
    if desc != null
      play_footstep(*desc,
                    human_steps_sound__path,
                    sound_tags,
                    1.0,
                    eid,
                    transform[3],
                    false,
                    true,
                    human_steps_sound__traceStepOffsetLen,
                    human_sound_landmesh_queries__biomePhysMatId,
                    human_sound_landmesh_queries__biomeOverridesWater,
                    human_sound_landmesh_queries__puddleDepth,
                    HUStandState.ESS_STAND,
                    human_steps_sound__smid,
                    human_steps_sound__waterDepth,
                    human_net_phys)
