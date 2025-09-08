require ecs
require ecs.safe
require math.base
require game.es.inventory_checks_common


def process_player_base_upgrades(upgrades_count : int;
                                 player_base_upgrades__upgradeTemplateNames : Object;
                                 player_base_upgrades__upgradePlaces : TMatrixList;
                                 transform : float3x4;
                                 var player_base_upgrades__currentUpgradesCount : int&;
                                 var player_base_upgrades__upgradesEids : EidList)
  if upgrades_count < player_base_upgrades__currentUpgradesCount
    for upgradeEid in player_base_upgrades__upgradesEids
      destroyEntity(upgradeEid)
    player_base_upgrades__upgradesEids |> clear()
    player_base_upgrades__currentUpgradesCount = 0
  if player_base_upgrades__currentUpgradesCount < upgrades_count
    var needUpgrades = upgrades_count - player_base_upgrades__currentUpgradesCount
    needUpgrades = min(length(player_base_upgrades__upgradePlaces) - player_base_upgrades__currentUpgradesCount, needUpgrades)
    for i in range(needUpgrades)
      let upgradeOffset = player_base_upgrades__upgradePlaces[player_base_upgrades__currentUpgradesCount + i]
      for obj in player_base_upgrades__upgradeTemplateNames
        let localOffset = obj.value ?? IDENT_TM
        let upgradeEid = createEntity(obj.key) <| $(var init)
          init |> set("transform", transform * upgradeOffset * localOffset)
        player_base_upgrades__upgradesEids |> push(upgradeEid)
    player_base_upgrades__currentUpgradesCount += needUpgrades


[es(tag=gameClient, on_appear, track=player_profile__replicatorDevicesCount)]
def player_base_upgrades_replicators_update(evt : Event; player_profile__replicatorDevicesCount : int)
  query() <| $ [es(REQUIRE=player_base_device__replicator)] (player_base_upgrades__upgradeTemplateNames : Object;
                                                             player_base_upgrades__upgradePlaces : TMatrixList;
                                                             transform : float3x4;
                                                             var player_base_upgrades__currentUpgradesCount : int&;
                                                             var player_base_upgrades__upgradesEids : EidList)
    process_player_base_upgrades(
      player_profile__replicatorDevicesCount,
      player_base_upgrades__upgradeTemplateNames,
      player_base_upgrades__upgradePlaces,
      transform,
      player_base_upgrades__currentUpgradesCount,
      player_base_upgrades__upgradesEids
    )

[es(tag=gameClient, on_appear, track=player_profile__amCleaningDevicesCount)]
def player_base_upgrades_cleaners_update(evt : Event; player_profile__amCleaningDevicesCount : int)
  query() <| $ [es(REQUIRE=player_base_device__recycler)] (player_base_upgrades__upgradeTemplateNames : Object;
                                                           player_base_upgrades__upgradePlaces : TMatrixList;
                                                           transform : float3x4;
                                                           var player_base_upgrades__currentUpgradesCount : int&;
                                                           var player_base_upgrades__upgradesEids : EidList)
    process_player_base_upgrades(
      player_profile__amCleaningDevicesCount,
      player_base_upgrades__upgradeTemplateNames,
      player_base_upgrades__upgradePlaces,
      transform,
      player_base_upgrades__currentUpgradesCount,
      player_base_upgrades__upgradesEids
    )


[es(tag=gameClient, on_appear)]
def player_base_upgrades_appear(evt : Event;
                                player_base_upgrades__upgradeTemplateNames : Object;
                                player_base_upgrades__upgradePlaces : TMatrixList;
                                transform : float3x4;
                                player_base_upgrades__upgradeName : string;
                                var player_base_upgrades__currentUpgradesCount : int&;
                                var player_base_upgrades__upgradesEids : EidList)
  query() <| $ [es] (player_profile__replicatorDevicesCount, player_profile__amCleaningDevicesCount : int)
    if player_base_upgrades__upgradeName == "replicator_device"
      process_player_base_upgrades(
        player_profile__replicatorDevicesCount,
        player_base_upgrades__upgradeTemplateNames,
        player_base_upgrades__upgradePlaces,
        transform,
        player_base_upgrades__currentUpgradesCount,
        player_base_upgrades__upgradesEids
      )
    elif player_base_upgrades__upgradeName == "recycler_device"
      process_player_base_upgrades(
        player_profile__amCleaningDevicesCount,
        player_base_upgrades__upgradeTemplateNames,
        player_base_upgrades__upgradePlaces,
        transform,
        player_base_upgrades__currentUpgradesCount,
        player_base_upgrades__upgradesEids
      )


[es(tag=gameClient, on_appear, track=player_profile__stashMaxVolume)]
def player_base_stash_on_cap_change(evt : Event; player_profile__stashMaxVolume : float)
  query() <| $ [es] (inventory__name : string;
                     var human_inventory__maxVolume : float&;
                     var human_inventory__maxVolumeInt : int&)
    if inventory__name == "stash"
      human_inventory__maxVolume = player_profile__stashMaxVolume
      human_inventory__maxVolumeInt = convert_volume_to_int(human_inventory__maxVolume)


[es(tag=gameClient, on_appear)]
def player_base_stash_cap_update(evt : Event; inventory__name : string;
                                 var human_inventory__maxVolume : float&;
                                 var human_inventory__maxVolumeInt : int&)
  if inventory__name == "stash"
    query() <| $ [es] (player_profile__stashMaxVolume : float)
      human_inventory__maxVolume = player_profile__stashMaxVolume
      human_inventory__maxVolumeInt = convert_volume_to_int(human_inventory__maxVolume)
