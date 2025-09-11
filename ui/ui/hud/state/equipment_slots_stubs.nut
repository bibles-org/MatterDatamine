from "%ui/ui_library.nut" import *

let humanEquipmentSlots = freeze({
  helmet = {
    defaultIcon = "skin#helmet_slot_icon.svg"
    slotTooltip = "slots/helmet"
    iconImageColor = Color(101, 101, 101, 51)
  }
  flashlight = {
    defaultIcon = "skin#flashlight_slot_icon.svg"
    slotTooltip = "slots/flashlight"
    iconImageColor = Color(101, 101, 101, 51)
  }
  signal_grenade = {
    defaultIcon = "skin#airdrop_icon.svg"
    slotTooltip = "slots/signalGrenade"
    slotKeyBindTip = "Human.UseSignalGrenade"
    iconImageColor = Color(101, 101, 101, 51)
  }
  pouch = {
    defaultIcon = "skin#pouches_slot_icon.svg"
    slotTooltip = "slots/pouch"
    iconImageColor = Color(101, 101, 101, 51)
  }
  backpack = {
    defaultIcon = "skin#backpack_slot_icon.svg"
    slotTooltip = "slots/backpack"
    iconImageColor = Color(101, 101, 101, 51)
  }
  safepack = {
    defaultIcon = "skin#safebox.svg"
    slotTooltip = "slots/safepack"
    iconImageColor = Color(101, 101, 101, 51)
  }
  chronogene_primary_1 = {
    defaultIcon = "skin#helmet_slot_icon.svg"
    slotTooltip = "slots/alter"
    iconImageColor = Color(101, 101, 101, 51)
  }
  chronogene_secondary = {
    defaultIcon = "skin#chronogene.svg"
    slotTooltip = "slots/chronogene"
    iconImageColor = Color(101, 101, 101, 51)
  }
  cortical_vault = {
    defaultIcon = "skin#chronogene.svg"
    slotTooltip = "Cortical vault slot"
    iconImageColor = Color(101, 101, 101, 51)
  }
  refiner_key_item = {
    defaultIcon = "skin#key_item_slot.svg"
    slotTooltip = "refiner/keyItem"
    iconImageColor = Color(101, 101, 101, 51)
  }
  refiner_fuse_result = {
    defaultIcon = "skin#refiner_lootbox_slot.svg"
    slotTooltip = "refiner/fuseResult"
    iconImageColor = Color(101, 101, 101, 51)
  }
})

return freeze({
  humanEquipmentSlots
})
