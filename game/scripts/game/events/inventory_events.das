module inventory_events shared
require ecs

// Commands that initiate server actions

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdItemPickup
  item : EntityId

// Item

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdDropItemFromInventory
  itemEid : EntityId

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdMoveItemFromGroundToInventory
  itemEid : EntityId
  toInventoryEid : EntityId

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdMoveItemFromInventoryToInventory
  itemEid : EntityId
  toInventoryEid : EntityId

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdSplitItemToInventory
  itemEid : EntityId
  toInventoryEid : EntityId
  count : int

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdSplitItemToGround
  itemEid : EntityId
  count : int

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct NotifyItemHolderLoadingStart
  processEid : EntityId // Server-only (non replicating) entity
  wishToLoad : bool
  holderEid : EntityId
  inventoryEid : EntityId
  boxedId : string


[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct NotifyItemHolderLoadingEnd
  processEid : EntityId // Server-only (non replicating) entity
  wishToLoad : bool
  holderEid : EntityId
  inventoryEid : EntityId
  boxedId : string
  count : int

// Equipment

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdMoveEquipmentToInventory
  slotName : string
  toInventoryEid : EntityId

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdEquipEquipmentFromInventory
  itemEid : EntityId
  fromInventoryEid : EntityId
  slotName : string

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdEquipEquipmentFromGround
  itemEid : EntityId
  slotName : string


// Equipment Mod

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdSplitItemToEquipmentModSlot
  itemEid : EntityId
  equipmentEid : EntityId
  fromInventoryEid : EntityId
  slotName : string

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdEquipEquipmentModFromInventory
  itemEid : EntityId
  equipmentEid : EntityId
  fromInventoryEid : EntityId
  slotName : string

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdMoveEquipmentModToInventory
  equipmentEid : EntityId
  slotName : string
  toInventoryEid : EntityId


// Weapon

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdMoveWeaponToInventory
  slotId : int
  toInventoryEid : EntityId

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdEquipWeaponFromInventory
  itemEid : EntityId
  fromInventoryEid : EntityId
  slotId : int

// Weapon Mod

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdEquipWeaponModFromInventory
  itemEid : EntityId
  weaponEid : EntityId
  fromInventoryEid : EntityId
  slotName : string

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdMoveWeaponModToInventory
  slotId : int
  slotName : string
  toInventoryEid : EntityId

[event(unicast)]
struct CmdAbortMoveWeaponMods
  weaponEid : EntityId

[event(unicast)]
struct CmdWeaponModEquipStarted
  weaponEid : EntityId
  weaponModEid : EntityId
  slotName : string

// Events on something happens with inventory

// Item

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventOnItemPickup
  itemEid : EntityId
  toInventoryEid : EntityId

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventOnItemDrop
  itemEid : EntityId
  fromInventoryEid : EntityId

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventOnItemMovedBetweenInventory
  itemEid : EntityId
  oldInventoryEid : EntityId
  newInventoryEid : EntityId

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventOnMovingBetweenInventories
  actorEid : EntityId
  oldInventoryEid : EntityId
  newInventoryEid : EntityId

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventOnDropItem
  actorEid : EntityId
  oldInventoryEid : EntityId
  newInventoryEid : EntityId
  transform : float3x4

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventOnDropItemPhys
  actorEid : EntityId
  transform : float3x4

// Common

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventOnStartDelayedModMove
  modParentEid : EntityId
  inventoryEid : EntityId

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventOnEndDelayedModMove {}

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventOnUnequipingToInventory
  newInventoryEid : EntityId
  lastOwnerEid : EntityId

// Equipment

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventOnEquipmentUnequipped
  equipmentEid : EntityId
  toInventoryEid : EntityId
  slotName : string

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventOnEquipmentEquipped
  equipmentEid : EntityId
  slotName : string

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventOnEquipmentChanged
  oldEquipmentEid : EntityId
  newEquipmentEid : EntityId
  slotName : string

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventOnEquipingAsEquipment
  heroEid : EntityId
  fromInventoryEid : EntityId

[event(unicast)]
struct EquipmentApplyEffects
  actorEid : EntityId

[event(unicast)]
struct EquipmentRevertEffects
  actorEid : EntityId

// Equipment Mod

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventOnEquipmentModEquippedToEquipment
  equipmentModEid : EntityId
  equipmentEid : EntityId
  slotName : string

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventOnEquipmentModUnequippedFromEquipment
  equipmentModEid : EntityId
  equipmentEid : EntityId
  toInventoryEid : EntityId
  slotName : string

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventOnEquipmentModEquippedToHero
  equipmentModEid : EntityId
  equipmentEid : EntityId

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventOnEquipmentModUnequippedFromHero
  equipmentModEid : EntityId

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventOnEquipmentModChanged
  oldEquipmentModEid : EntityId
  newEquipmentModEid : EntityId
  equipmentEid : EntityId
  slotName : string

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventOnEquipmentModSwap
  firstSlotName : string
  secondSlotName : string
  firstEquipmentModEid : EntityId
  secondEquipmentModEid : EntityId
  firstEquipmentEid : EntityId
  secondEquipmentEid : EntityId

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventOnEquipingAsEquipmentMod
  actorEid : EntityId
  equipmentEid : EntityId
  fromInventoryEid : EntityId
  slotName : string

// Weapon

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventOnWeaponEquipped
  weaponEid : EntityId
  slotId : int

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventOnWeaponUnequipped
  weaponEid : EntityId
  toInventoryEid : EntityId
  slotId : int

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventOnWeaponChanged
  oldWeaponEid : EntityId
  newWeaponEid : EntityId
  slotId : int

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventOnWeaponSwap
  firstSlotId : int
  secondSlotId : int
  firstWeaponEid : EntityId
  secondWeaponEid : EntityId

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventOnEquipingAsWeapon
  heroEid : EntityId
  slotId : int
  fromInventoryEid : EntityId

// Weapon Mod

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventOnWeaponModEquipped
  weaponModEid : EntityId
  weaponEid : EntityId
  slotName : string

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventOnWeaponModUnequipped
  weaponModEid : EntityId
  weaponEid : EntityId
  toInventoryEid : EntityId

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventOnWeaponModChanged
  oldWeaponModEid : EntityId
  newWeaponModEid : EntityId
  weaponEid : EntityId
  slotName : string

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventOnEquipingAsWeaponMod
  actorEid : EntityId
  weaponEid : EntityId
  fromInventoryEid : EntityId
  isStartDelayedEquip : bool

// Boxed Ammo

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdUnloadAmmoFromGunToInventory
  slotId : int
  toInventoryEid : EntityId

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdLoadAmmoFromInventoryToGun
  ammoEid : EntityId
  gunEid : EntityId

[event(unicast)]
struct NotifyGunBoxedAmmoLoadingEnd
  gunEid : EntityId
  boxedId : string
  count : int

[event(unicast)]
struct NotifyGunBoxedAmmoUnoadingEnd
  gunEid : EntityId
  inventoryEid : EntityId
  count : int

[event(unicast)]
struct CmdHeroGunWithBoxedAmmoReloadStarted
  gunEid : EntityId


[event(unicast)]
struct CmdInterruptReloadGunWithBoxedAmmo
  humanEid : EntityId
  immediately : bool


[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdDropAllItemsFromInventory
  fromInventoryEid : EntityId
  toInventoryEid : EntityId