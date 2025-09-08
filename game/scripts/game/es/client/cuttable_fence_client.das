require app
require ecs
require math.base
require game.events.events_active_matter
require DagorSystem
require fx
require game.utils.hero
require game.utils.net_utils
require player
require HumanPhys
require DngHuman


def update_cuttable_fences_usage(usage_available : bool)
  query() <| $ [es(REQUIRE=cuttableFence)] (var item__useActionAvailable : bool&;
                                            var item__setCustomUsePrompt : das_string&;
                                            cuttable_fence__isValid : bool)
    if cuttable_fence__isValid
      item__useActionAvailable = usage_available
      item__setCustomUsePrompt := usage_available ? "hint/cut_the_fence" : "hint/select_melee_to_cut_the_fence"
    else
      item__useActionAvailable = false
      item__setCustomUsePrompt := "hint/cannot_cut_the_fence"


[es(tag=input, REQUIRE=hero, REQUIRE_NOT=deadEntity,
  after=hero_human_use_object,
  before=hero_human_final_use_object_sync)]
def cuttable_fences_use_check_available(act : UpdateStageInfoAct;
                                        var human_use_object__canUseSelected : bool&;
                                        human_use_object__selectedObject : EntityId)
  query(human_use_object__selectedObject) <| $ [es(REQUIRE=cuttableFence)] (item__useActionAvailable : bool)
    human_use_object__canUseSelected = item__useActionAvailable


[es(tag=gameClient, REQUIRE=hero, track=human_weap__currentGunSlot, on_appear)]
def update_cuttable_fences_by_hero_weap(evt : Event;
                                        human_weap__currentGunSlot : int)
  let isMelee = (human_weap__currentGunSlot == int(HUWeaponSlots.EWS_MELEE))
  update_cuttable_fences_usage(isMelee)


[es(tag=gameClient, REQUIRE=cuttableFence, on_appear)]
def set_cuttable_fences_usage(evt : Event;
                              var item__useActionAvailable : bool&;
                              var item__setCustomUsePrompt : das_string&)
  query() <| $ [es(REQUIRE=hero)] (human_weap__currentGunSlot : int)
    let isMelee = (human_weap__currentGunSlot == int(HUWeaponSlots.EWS_MELEE))
    item__useActionAvailable = isMelee
    item__setCustomUsePrompt := isMelee ? "hint/cut_the_fence" : "hint/select_melee_to_cut_the_fence"
