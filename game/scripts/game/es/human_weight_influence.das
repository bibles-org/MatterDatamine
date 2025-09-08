require ecs
require DngHuman
require math
require DagorMath
require game.es.entity_mods_common


def human_weight_influence_update(var human_net_phys : HumanActor;
                                  entity_mod_values : Object;
                                  human_inventory__currentWeight;
                                  human_weight_influence__minWeight;
                                  human_weight_influence__maxWeight;
                                  human_weight_influence__maxWeightAccelerationMult;
                                  human_weight_influence__maxWeightSpeedMult;
                                  human_weight_influence__staminaDrainMult;
                                  human_weight_influence__maxWeightJumpMult;
                                  entity_mods__weightRunSpeedMult)
  let curLerpFactor = cvt(human_inventory__currentWeight * entity_mods__weightRunSpeedMult,
                          human_weight_influence__minWeight, human_weight_influence__maxWeight,
                          0.f, 1.f)
  let weightPenaltyReduction = get_mod_value("weightPenaltyReduction", entity_mod_values, 1.0)
  human_net_phys.phys.currentState.accelerationMult *= lerp(1.f, human_weight_influence__maxWeightAccelerationMult * weightPenaltyReduction, curLerpFactor)
  human_net_phys.phys.currentState.moveSpeedMult *= lerp(1.f, human_weight_influence__maxWeightSpeedMult * weightPenaltyReduction, curLerpFactor)
  human_net_phys.phys.currentState.staminaDrainMult *= lerp(1.f, human_weight_influence__staminaDrainMult * weightPenaltyReduction, curLerpFactor)
  human_net_phys.phys.currentState.jumpSpeedMult *= lerp(1.f, human_weight_influence__maxWeightJumpMult * weightPenaltyReduction, curLerpFactor)


[es(tag=server, after=after_entity_mods_apply_sync_point, REQUIRE_NOT=sleeping_monster)]
def human_weight_influence_server_es(info : UpdateStageInfoAct;
                                     var human_net_phys : HumanActor;
                                     entity_mod_values : Object;
                                     human_inventory__currentWeight : float;
                                     human_weight_influence__minWeight : float = 4.f;
                                     human_weight_influence__maxWeight : float  = 15.f;
                                     human_weight_influence__maxWeightAccelerationMult : float = 0.5f;
                                     human_weight_influence__maxWeightSpeedMult : float = 1.f;
                                     human_weight_influence__maxWeightJumpMult : float = 1.f;
                                     human_weight_influence__staminaDrainMult : float = 1.f;
                                     entity_mods__weightRunSpeedMult : float = 1.f)
  human_weight_influence_update(human_net_phys, entity_mod_values, human_inventory__currentWeight, human_weight_influence__minWeight,
                                  human_weight_influence__maxWeight, human_weight_influence__maxWeightAccelerationMult,
                                  human_weight_influence__maxWeightSpeedMult, human_weight_influence__staminaDrainMult,
                                  human_weight_influence__maxWeightJumpMult, entity_mods__weightRunSpeedMult)


[es(tag=netClient, REQUIRE=watchedByPlr, after=after_entity_mods_apply_sync_point)]
def human_weight_influence_client_es(info : UpdateStageInfoAct;
                                     var human_net_phys : HumanActor;
                                     entity_mod_values : Object;
                                     human_inventory__currentWeight : float;
                                     human_weight_influence__minWeight : float = 4.f;
                                     human_weight_influence__maxWeight : float  = 15.f;
                                     human_weight_influence__maxWeightAccelerationMult : float = 0.5f;
                                     human_weight_influence__maxWeightSpeedMult : float = 1.f;
                                     human_weight_influence__maxWeightJumpMult : float = 1.f;
                                     human_weight_influence__staminaDrainMult : float = 1.f;
                                     entity_mods__weightRunSpeedMult : float = 1.f)
  human_weight_influence_update(human_net_phys, entity_mod_values, human_inventory__currentWeight, human_weight_influence__minWeight,
                                  human_weight_influence__maxWeight, human_weight_influence__maxWeightAccelerationMult,
                                  human_weight_influence__maxWeightSpeedMult, human_weight_influence__staminaDrainMult,
                                  human_weight_influence__maxWeightJumpMult, entity_mods__weightRunSpeedMult)
