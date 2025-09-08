require ecs
require game.events.events
require HumanPhys
require DngHuman
require math.base
require DagorMath
require game.events.events_active_matter


[es(tag=(ui, render, gameClient), REQUIRE=watchedByPlr, REQUIRE_NOT=aircraftCrew, after=after_net_phys_sync)]
def hero_stamina_es(info : ParallelUpdateFrameDelayed;
                    human_net_phys : HumanActor;
                    var view_lowStamina : bool&;
                    var view_stamina : int&)
  let canStartSprint = human_net_phys.phys.canStartSprint
  view_lowStamina = !canStartSprint

  view_stamina = ceili(human_net_phys.phys.currentState.stamina
    * safeinv(human_net_phys.phys.maxStamina / 100.f * human_net_phys.phys.currentState.maxStaminaMult
    * human_net_phys.phys.currentState.staminaBoostMult))

[es(tag=(ui, render, gameClient), REQUIRE=(watchedByPlr, aircraftCrew))]
def aircraft_crew_stamina_view(info : ParallelUpdateFrameDelayed;
                               aircraft_crew__stamina : float;
                               entity_mods__aircraftCrewMaxStaminaMult : float = 1.0;
                               var view_stamina : int&)
  view_stamina = ceili(100.0 * aircraft_crew__stamina * safeinv(entity_mods__aircraftCrewMaxStaminaMult))
