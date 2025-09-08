require ecs
require DagorRandom
require game.events.inventory_events


[es(tag=server)]
def refill_magazines_on_unloading(evt : EventOnWeaponModUnequipped; refill_magazines__refillVolumeRng : float2)
  query(evt.weaponModEid) <| $ [es] (item_holder__maxItemCount : int; var item__currentBoxedItemCount : int&)
    let fillAmount = rnd_float(refill_magazines__refillVolumeRng.x, refill_magazines__refillVolumeRng.y)
    item__currentBoxedItemCount = int(float(item_holder__maxItemCount) * fillAmount)
