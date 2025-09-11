enum WeaponSlots {
  EWS_PRIMARY = 0
  EWS_SECONDARY = 1
  EWS_TERTIARY = 2
  EWS_MELEE = 3
  EWS_GRENADE = 4
  EWS_SPECIAL = 5
  EWS_UNARMED = 6
  EWS_NUM = 7
}

let weaponSlotsKeys = static {
  [WeaponSlots.EWS_PRIMARY] = "primary",
  [WeaponSlots.EWS_SECONDARY] = "secondary",
  [WeaponSlots.EWS_TERTIARY] = "tertiary",
  [WeaponSlots.EWS_MELEE] = "melee",
  [WeaponSlots.EWS_GRENADE] = "grenade",
  [WeaponSlots.EWS_SPECIAL] = "special",
  [WeaponSlots.EWS_UNARMED] = "unarmed",
}

return freeze({
  EWS_PRIMARY = WeaponSlots.EWS_PRIMARY
  EWS_SECONDARY = WeaponSlots.EWS_SECONDARY
  EWS_TERTIARY = WeaponSlots.EWS_TERTIARY
  EWS_MELEE = WeaponSlots.EWS_MELEE
  EWS_GRENADE = WeaponSlots.EWS_GRENADE
  EWS_UNARMED = WeaponSlots.EWS_UNARMED
  EWS_NUM = WeaponSlots.EWS_NUM
  weaponSlotsKeys
})