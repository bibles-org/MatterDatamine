require ecs
require ecs.safe
require DagorRandom
require DagorSystem
require game.es.inventory_weapon_mod_common


[es(tag=server,   on_appear)]
def create_initial_weapon_mods(evt : Event;
                               eid : EntityId;
                               @shared_comp gun_mods__slots : Object;
                               initial_weapon_mods__list : Object)
  for modItem in initial_weapon_mods__list
    if !(gun_mods__slots |> has(modItem.key))
      logerr("[Initial Weapon Mods] Weapon <{eid}> ({getEntityTemplateName(eid)}) has not slot <{modItem.key}>")
      return
    let modItemTemplate = (modItem.value as Object)?.templateName ?? ""
    if empty(modItemTemplate)
      logerr("[Initial Weapon Mods] Weapon <{eid}> ({getEntityTemplateName(eid)}) has not correct templateName in weapon mod list")
      return

    let modItemAmmo = (modItem.value as Object)?.ammoRange ?? int2(0)
    var maxModItemAmmo = 0
    let modTemplate = getTemplateByName(modItemTemplate)
    if modTemplate != null
      maxModItemAmmo = getTemplateComponent(*modTemplate, "item_holder__maxItemCount") ?? 0
    // convert -1 to max ammo
    let generatedModItemAmmo = rnd_int(
      modItemAmmo.x < 0 ? maxModItemAmmo : modItemAmmo.x,
      modItemAmmo.y < 0 ? maxModItemAmmo : modItemAmmo.y)

    create_mod_in_weapon(modItemTemplate, modItem.key, eid, INVALID_ENTITY_ID) <| $(var init)
      init |> set("item__currentBoxedItemCount", generatedModItemAmmo)
