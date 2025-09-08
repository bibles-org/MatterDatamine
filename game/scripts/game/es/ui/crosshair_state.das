require ecs
require app
require game.utils.team
require game.utils.hero
require danetlibs.renderer.includes.render_events
require dm
require DagorSystem
require DagorMath
require CollRes
require RendInst
require HumanPhys
require DngHuman
require DngWeapon
require DngUI
require Gun


[es(tag=gameClient, after=human_weap_update_es)]
def ui_crosshair_state_es(info : RenderEventUI;
                          var ui_crosshair_state__isAiming : bool&)
  ui_crosshair_state__isAiming = false

  let hero = get_controlled_hero()

  var isInVehicle = false
  var human : HumanActor const? = null
  query(hero) <| $ [es] (isInVehicle aka hero_isInVehicle : bool = false;
                         human_net_phys : HumanActor const?)
    isInVehicle = hero_isInVehicle
    human = human_net_phys

  assume phys = human.phys

  if isInVehicle && (human == null || !phys.appliedCT |> is_control_bit_set(HumanPhysControlType.HCT_AIM))
    return

  ui_crosshair_state__isAiming = (human != null && phys.currentState.isAiming)

