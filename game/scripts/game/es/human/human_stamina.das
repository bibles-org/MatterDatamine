require ecs
require HumanPhys
require DngHuman

[es(track=entity_mods__staminaBoostMult, on_appear)]
def entity_stamina_boost_mult_applier(evt : Event;
                                      var human_net_phys : HumanActor;
                                      entity_mods__staminaBoostMult : float)
  human_net_phys.phys.currentState.staminaBoostMult = entity_mods__staminaBoostMult

[es(after=entity_stamina_boost_mult_applier, on_appear, REQUIRE=entity_mods__staminaBoostMult)]
def human_update_stamina_on_spawn(evt : Event;
                                  var human_net_phys : HumanActor)
  human_phys_state_reset_stamina(human_net_phys.phys.currentState, human_net_phys.phys.maxStamina)
