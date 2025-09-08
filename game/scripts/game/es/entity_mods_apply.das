require ecs
require DngHuman
require DagorMath
require game.es.entity_mods_common
require game.events.events_active_matter


[es(after=before_entity_mods_apply_sync_point, before=(human_phys_es, after_entity_mods_apply_sync_point))]
def entity_speed_mod_apply(info : ParallelUpdateFrameDelayed;
                           entity_mod_values : Object;
                           var human_net_phys : HumanActor&)
  assume moveSpeedMult = human_net_phys.phys.currentState.moveSpeedMult
  moveSpeedMult *= get_mod_value("speedMult", entity_mod_values, 1.0)


[es(after=before_entity_mods_apply_sync_point, before=(human_phys_es, after_entity_mods_apply_sync_point))]
def entity_sprint_stamina_drain_mod_apply(info : ParallelUpdateFrameDelayed;
                                          entity_mod_values : Object;
                                          var human_net_phys : HumanActor&)
  assume staminaSprintDrainMult = human_net_phys.phys.currentState.staminaSprintDrainMult
  staminaSprintDrainMult *= get_mod_value("sprintStaminaDrain", entity_mod_values, 1.0)


[es(after=before_entity_mods_apply_sync_point, before=(human_phys_es, after_entity_mods_apply_sync_point))]
def entity_breath_amplitude_mod_apply(info : ParallelUpdateFrameDelayed;
                                      entity_mod_values : Object;
                                      var human_net_phys : HumanActor&)
  assume breathAmplitudeMult = human_net_phys.phys.currentState.breathAmplitudeMult
  breathAmplitudeMult *= get_mod_value("breathAmplitudeMult", entity_mod_values, 1.0)


[es(on_appear)]
def entity_change_pose_speed_mod_apply(evt : Event;
                                       entity_mod_values : Object;
                                       var entity_mods__changePosModsMulti : float&)
  entity_mods__changePosModsMulti = get_mod_value("fasterChangePoseMult", entity_mod_values, entity_mods__changePosModsMulti)


[es(after=before_entity_mods_apply_sync_point, before=(human_phys_es, after_entity_mods_apply_sync_point))]
def entity_jump_speed_mod_apply(info : ParallelUpdateFrameDelayed;
                                entity_mod_values : Object;
                                var human_net_phys : HumanActor&)
  assume jumpSpeedMult = human_net_phys.phys.currentState.jumpSpeedMult
  jumpSpeedMult *= get_mod_value("jumpSpeedMult", entity_mod_values, 1.f)
