require ecs.ecs_quirrel
require game.es.onboarding_common


[quirrel_bind(module_name="das.onboarding")]
def is_onboarding()
  return onboarding_common::is_onboarding()
