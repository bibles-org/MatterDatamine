from "%ui/hud/state/equipment.nut" import isModForEquipmentSlot


function isAmmoForWeapon(ammo, weapon){
  if (ammo?.boxTemplate != null && ammo.boxTemplate == weapon?.gunBoxedAmmoTemplate)
    return true
  return weapon?.ammoHolders.indexof(ammo?.ammoId ?? 0) != null
}

function isItemForSlot(item, slot, equipment) {
  return (item?.validWeaponSlots.indexof(slot ?? "") != null ||
          item?.equipmentSlots.indexof(slot ?? "") != null ||
          (item?.eid != null && equipment != null && isModForEquipmentSlot(item?.eid, equipment, slot)))
}

function isItemForWeaponMod(item, modSlotItems, modSlotAmmo) {
  return (modSlotItems?.indexof(item?.itemTemplate ?? "") != null ||
          modSlotAmmo?.indexof(item.id) != null)
}

function isItemForHolder(boxed_item, holder){
  return holder?.boxedItemTemplate == boxed_item?.boxTemplate && boxed_item?.boxTemplate != null
}

return {
  isAmmoForWeapon,
  isItemForSlot,
  isItemForWeaponMod,
  isItemForHolder
}
