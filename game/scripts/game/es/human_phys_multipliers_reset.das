require ecs
require DngHuman


def reset_human_phys_multipliers(var human_net_phys : HumanActor)
  human_net_phys.phys.currentState.accelerationMult = 1.f
  human_net_phys.phys.currentState.moveSpeedMult = 1.f
  human_net_phys.phys.currentState.crawlCrouchSpeedMult = 1.f
  human_net_phys.phys.currentState.staminaDrainMult = 1.f
  human_net_phys.phys.currentState.staminaSprintDrainMult = 1.f
  human_net_phys.phys.currentState.breathAmplitudeMult = 1.f
  human_net_phys.phys.currentState.jumpSpeedMult = 1.f


[es(tag=server, before=before_entity_mods_apply_sync_point)]
def human_phys_reset_multipliers(info : UpdateStageInfoAct;
                                 var human_net_phys : HumanActor)
  reset_human_phys_multipliers(human_net_phys)


[es(tag=netClient, REQUIRE=watchedByPlr, before=before_entity_mods_apply_sync_point)]
def human_phys_reset_multipliers_client(info : UpdateStageInfoAct;
                                        var human_net_phys : HumanActor)
  reset_human_phys_multipliers(human_net_phys)
