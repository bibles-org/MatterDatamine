import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { saveJson, loadJson, read_text_directly_from_fs_file } = require("%sqstd/json.nut")
let { requestProfileServer } = require("%sqGlob/profile_server.nut")
let console = require("console")
let { eventbus_send, eventbus_subscribe } = require("eventbus")
let { hero_clean_all_equipment_and_gun_slots, generate_loadout_by_seed } = require("das.equipment")
let { playerProfileOpenedNodes,
      playerProfileCreditsCount,
      playerProfileMonolithTokensCount,
      playerProfileChronotracesCount,
      playerBaseState,
      playerProfileLoadout,
      playerStats,
      playerProfileUnlocksData,
      alterMints } = require("%ui/profile/profileState.nut")
let { get_setting_by_blk_path } = require("settings")
let { updateProfileBlocks,
      updateProfileBlocksFullLoad } = require("%ui/profile/profile_server_handlers.nut")
let { deep_clone } = require("%sqstd/underscore.nut")
let { matchingQueuesMap } = require("%ui/matchingQueues.nut")
let { getNeededZoneRequirements } = require("%ui/state/queueState.nut")
let { stashItems } = require("%ui/hud/state/inventory_items_es.nut")
let decode_jwt = require("jwt").decode
let { profilePublicKey } = require("%ui/profile/profile_pubkey.nut")
let { EventOnboardingPhaseResult, EventUnlockAppear, CmdForceLoadProfile,
      EventGameTrigger } = require("dasevents")
let { selectedRaid } = require("%ui/gameModeState.nut")
let { isOnboarding } = require("%ui/hud/state/onboarding_state.nut")
let { isOnPlayerBase } = require("%ui/hud/state/gametype_state.nut")
let { currentPrimaryContractIds } = require("%ui/mainMenu/raid_preparation_window_state.nut")

let rand = require("%sqstd/rand.nut")()

function unlocksDiff(old) {
  return playerStats.get().unlocks
    .filter(@(v) !old.contains(v) && (playerProfileUnlocksData.get()?[v]?.isJournalVisible ?? false))
}

function researchNodesDiff(oldNodes) {
  let newNodes = playerProfileOpenedNodes.get()

  let diff = newNodes.map(function(v, k) {
    let wasOpened = oldNodes?[k] != null
    if (wasOpened) {
      let researchPointsDiff = v.currentResearchPoints - oldNodes[k].currentResearchPoints
      if (researchPointsDiff > 0) {
        return {
          researchPointsDiff
          prototypeId = v.prototypeId
        }
      }
      else
        throw null
    }
    else {
      return {
        prototypeId = v.prototypeId
        researchPointsDiff = 0
        newResearch = true
      }
    }
  })

  return diff
}

function currencyDiff(old_currency, current_currency) {
  let diff = current_currency - old_currency
  return diff != 0 ? diff : null
}

function playerBaseStateDiff(oldPlayerBaseState) {
  let openedAMCleaningDevicesDiff = ((playerBaseState.get()?.openedAMCleaningDevices ?? 0)
                                     - (oldPlayerBaseState?.openedAMCleaningDevices ?? 0))
  let openedReplicatorDevicesDiff = ((playerBaseState.get()?.openedReplicatorDevices ?? 0)
                                     - (oldPlayerBaseState?.openedReplicatorDevices ?? 0))
  let openedAlterContainersDiff = ((playerBaseState.get()?.openedAlterContainers ?? 0)
                                     - (oldPlayerBaseState?.openedAlterContainers ?? 0))
  let stashVolumeUpgradesDiff = ((playerBaseState.get()?.stashAdditionalVolume ?? 0)
                                     - (oldPlayerBaseState?.stashAdditionalVolume ?? 0))

  local diff = []
  if (openedReplicatorDevicesDiff != 0) {
    diff.append({
      name = "ReplicatorDevice"
      count = openedReplicatorDevicesDiff
    })
  }

  if (openedAMCleaningDevicesDiff != 0) {
    diff.append({
      name = "AMCleaningDevice"
      count = openedAMCleaningDevicesDiff
    })
  }

  if (openedAlterContainersDiff != 0) {
    diff.append({
      name = "AlterContainer"
      count = openedAlterContainersDiff
    })
  }

  if (stashVolumeUpgradesDiff != 0) {
    diff.append({
      name = "StashVolume"
      count = stashVolumeUpgradesDiff
    })
  }

  return diff
}

function itemsDiff(oldItems, updatedItems) {
  return updatedItems.map(function(item) {
    let oldItem = oldItems.findvalue(@(i) i.uniqueId == item.itemId)
    if (oldItem != null)
      return item.__merge({countAdded = item.charges - oldItem.ammoCount})
    else
      throw null
  })
}

let profile_loaded_query = ecs.SqQuery("profile_loaded_query", { comps_rw=[["player_profile__isLoaded", ecs.TYPE_BOOL]] })

let reset_profile_loaded = function() {
  local querySuccessful = false
  profile_loaded_query.perform(function(_eid, comp) {
    comp["player_profile__isLoaded"] = false
    querySuccessful = true
  })
  return querySuccessful
}

function loadFullProfile(request_name = "load_profile") {
  if (reset_profile_loaded()) {
    hero_clean_all_equipment_and_gun_slots()
    requestProfileServer(request_name, null, {}, updateProfileBlocksFullLoad)
  }
}

eventbus_subscribe("profile.load", @(...) loadFullProfile())

console.register_command(@() loadFullProfile(),
  "profile.load")

console.register_command(@() loadFullProfile("reset_profile"),
  "profile.reset")

console.register_command(@(item_id) requestProfileServer("destroy_item", {items=[item_id]}, {}, updateProfileBlocks),
  "profile.destroy_item")

console.register_command(@() requestProfileServer("force_update_daily_contracts", null, {}, updateProfileBlocks),
  "profile.force_update_daily_contracts")

console.register_command(@() requestProfileServer("force_complete_contracts", null, {}, updateProfileBlocks),
  "profile.force_complete_contracts")

console.register_command(@() requestProfileServer("force_uncomplete_contracts", null, {}, updateProfileBlocks),
  "profile.force_uncomplete_contracts")

console.register_command(@() requestProfileServer("force_reset_contracts", null, {}, updateProfileBlocks),
  "profile.force_reset_contracts")

console.register_command(@() requestProfileServer("clear_all_research_nodes", {}, {}, updateProfileBlocks),
  "profile.clear_all_research_nodes")

console.register_command(@() requestProfileServer("clear_all_recipes", {}, {}, updateProfileBlocks),
  "profile.clear_all_recipes")

console.register_command(@(count) requestProfileServer("force_set_credits_count", {count}, {}, updateProfileBlocks),
  "profile.force_set_credits_count")

console.register_command(@(count) requestProfileServer("force_set_monolith_credits_count", {count}, {}, updateProfileBlocks),
  "profile.force_set_monolith_credits_count")

console.register_command(@(count) requestProfileServer("force_set_chronotraces_count", {count}, {}, updateProfileBlocks),
  "profile.force_set_chronotraces_count")

console.register_command(@(node_id, points_count)
  requestProfileServer("add_research_points_to_node", {node_id, points_count}, {}, updateProfileBlocks),
  "profile.add_research_points_to_node")

console.register_command(@(node_id)
  requestProfileServer("claim_craft_recipe", {node_id}, {}, updateProfileBlocks),
  "profile.claim_craft_recipe")

console.register_command(@(craft_recipe_id, replicatorSlotIdx)
  eventbus_send("profile_server.add_craft_task", {craft_recipe_id, replicatorSlotIdx}), "profile.add_craft_task")

console.register_command(@() requestProfileServer("force_complete_all_crafts", {}, {}, updateProfileBlocks),
  "profile.force_complete_all_crafts", "Completes all active replicator crafts")

console.register_command(@() requestProfileServer("force_complete_all_refines", {}, {}, updateProfileBlocks),
  "profile.force_complete_all_refines")

console.register_command(@(craft_recipe_id) requestProfileServer("force_break_recipe", {craft_recipe_id}, {}, updateProfileBlocks),
  "profile.force_break_recipe")

console.register_command(@(craft_recipe_id) eventbus_send("profile_server.repair_craft_recipe", craft_recipe_id),
  "profile.repair_craft_recipe")

console.register_command(@(mode, stat_name, diff_value = 1) requestProfileServer("modify_player_stat", {mode, stat_name, diff_value}, {}, updateProfileBlocks),
  "profile.modify_player_stat")

console.register_command(@(path_id) requestProfileServer("player_select_monolith_path", {path_id}, {}, updateProfileBlocks),
  "profile.test_select_monolith_path")

function unlockAllRequirements (requirements) {
  if (requirements == null)
    return
  let neededRequirements = getNeededZoneRequirements(requirements, playerStats.get())
  foreach(neededStat in neededRequirements[0]) {
    let mode = neededStat[0]
    let stat_name = neededStat[1]
    let diff_value = neededStat[2]
    console_print($"Stat setted {mode}.{stat_name}={diff_value}")
    requestProfileServer("modify_player_stat", {mode, stat_name, diff_value}, {}, updateProfileBlocks)
  }
  foreach(neededUnlock in neededRequirements[1]) {
    console_print($"Added unlock {neededUnlock}")
    requestProfileServer("add_player_unlock", {unlock_name = neededUnlock}, {}, updateProfileBlocks)
  }
  foreach(notNeededUnlock in neededRequirements[2]) {
    console_print($"Removed unlock {notNeededUnlock}")
    requestProfileServer("remove_player_unlock", {unlock_name = notNeededUnlock}, {}, updateProfileBlocks)
  }
}

console.register_command(function(){
  let allRaids = [
    "am_dalniy_shegolskoe",
    "am_dalniy_factory",
    "am_dalniy_ozernoe",
    "am_dalniy_scrapyard",
    "am_dalniy_dogorsk",
    "am_dalniy_cargoport",
    "am_dalniy_epicenter",
    "am_dalniy_euclid",
    "am_dalniy_park",
    "am_dalniy_dam",
    "am_dalniy_military_base",
    "am_africa_headquarters",
  ]
  foreach (raid in allRaids) {
    unlockAllRequirements(matchingQueuesMap.get()[raid]?.extraParams?.requiresToShow)
    unlockAllRequirements(matchingQueuesMap.get()[raid]?.extraParams?.requiresToSelect)
    unlockAllRequirements(matchingQueuesMap.get()[raid]?.extraParams?.requiresToSelectMC)
  }
}, "profile.unlock_all_raids_full")

console.register_command(function(name = ""){
  requestProfileServer("create_mint_from_current_loadout", {name}, {}, updateProfileBlocks)
}, "profile.create_mint_from_current_loadout")

eventbus_subscribe("profile_server.create_mint_from_current_loadout",
  @(name)
    requestProfileServer("create_mint_from_current_loadout", { name }, {}, function(response) {
      let oldMints = deep_clone(alterMints.get())
      updateProfileBlocks(response)

      let mintDiff = alterMints.get().filter(@(newMint) oldMints.findindex(@(v) v.id == newMint.id) == null)
      eventbus_send($"profile_server.create_mint_from_current_loadout.result", { id = mintDiff[0].id })
    })
  )

eventbus_subscribe("profile_server.create_mint",
  function(itemsAndName) {
    log("create_mint request\n", itemsAndName)
    requestProfileServer("create_mint", itemsAndName, {}, updateProfileBlocks)
  }
)

eventbus_subscribe("profile_server.delete_mint",
  @(id)
    requestProfileServer("delete_mint", { mint_id = id }, {}, updateProfileBlocks)
  )

eventbus_subscribe("profile_server.rename_mint",
  @(idAndName)
    requestProfileServer("rename_mint", idAndName, {}, updateProfileBlocks)
  )

eventbus_subscribe("profile_server.change_mint",
  function(idAndItems) {
    log("change_mint request\n", idAndItems)
    requestProfileServer("change_mint", idAndItems, {}, updateProfileBlocks)
  }
)

console.register_command(function(id){
  requestProfileServer("delete_mint", {id}, {}, updateProfileBlocks)
}, "profile.delete_mint")

console.register_command(function(id, name = ""){
  requestProfileServer("rename_mint", {id, name}, {}, updateProfileBlocks)
}, "profile.rename_mint")

console.register_command(@() requestProfileServer("get_loadouts_agency", null, {}, updateProfileBlocks),
  "profile.get_loadouts_agency")

console.register_command(@() requestProfileServer("force_update_loadouts_agency", null, {}, updateProfileBlocks),
  "profile.force_update_loadouts_agency")

console.register_command(function(){
  let newbyRaids = [
    "am_dalniy_shegolskoe_newby",
    "am_dalniy_factory_newby",
    "am_dalniy_ozernoe_newby",
  ]
  foreach (raid in newbyRaids) {
    unlockAllRequirements(matchingQueuesMap.get()[raid]?.extraParams?.requiresToShow)
    unlockAllRequirements(matchingQueuesMap.get()[raid]?.extraParams?.requiresToSelect)
    unlockAllRequirements(matchingQueuesMap.get()[raid]?.extraParams?.requiresToSelectMC)
  }
}, "profile.unlock_newby_raids_full")

console.register_command(function(){
  let advancedRaids = [
    "am_dalniy_shegolskoe",
    "am_dalniy_factory",
    "am_dalniy_ozernoe",
  ]
  foreach (raid in advancedRaids) {
    unlockAllRequirements(matchingQueuesMap.get()[raid]?.extraParams?.requiresToShow)
    unlockAllRequirements(matchingQueuesMap.get()[raid]?.extraParams?.requiresToSelect)
    unlockAllRequirements(matchingQueuesMap.get()[raid]?.extraParams?.requiresToSelectMC)
  }
}, "profile.unlock_advanced_raids_full")

console.register_command(function(raidName){
  unlockAllRequirements(matchingQueuesMap.get()[raidName]?.extraParams?.requiresToShow)
  unlockAllRequirements(matchingQueuesMap.get()[raidName]?.extraParams?.requiresToSelect)
  unlockAllRequirements(matchingQueuesMap.get()[raidName]?.extraParams?.requiresToSelectMC)
}, "profile.unlock_raid_full")

console.register_command(function(raidName){
  unlockAllRequirements(matchingQueuesMap.get()[raidName]?.extraParams?.requiresToShow)
  unlockAllRequirements(matchingQueuesMap.get()[raidName]?.extraParams?.requiresToSelectMC)
}, "profile.unlock_raid_mc")

console.register_command(function(raidName){
  unlockAllRequirements(matchingQueuesMap.get()[raidName]?.extraParams?.requiresToShow)
  unlockAllRequirements(matchingQueuesMap.get()[raidName]?.extraParams?.requiresToSelect)
}, "profile.unlock_raid_operative")

console.register_command(function(raidName){
  unlockAllRequirements(matchingQueuesMap.get()[raidName]?.extraParams?.requiresToShow)
}, "profile.unlock_raid_show")

console.register_command(@(unlock_name) requestProfileServer("add_player_unlock", {unlock_name}, {}, updateProfileBlocks),
  "profile.add_player_unlock")

console.register_command(@() requestProfileServer("add_player_unlock", {unlock_name="__ADMIN__"}, {}, updateProfileBlocks),
  "profile.unlock_all_shop")

console.register_command(@(unlock_name) requestProfileServer("remove_player_unlock", {unlock_name}, {}, updateProfileBlocks),
  "profile.remove_player_unlock")

console.register_command(@() requestProfileServer("lock_equipment_cheat", {}, {}, null),
  "profile.lock_equipment_cheat")

console.register_command(@() requestProfileServer("unlock_equipment_cheat", {}, {}, null),
  "profile.unlock_equipment_cheat")

console.register_command(@() requestProfileServer("force_set_refiners_count", {count = 1}, {}, updateProfileBlocks),
  "profile.force_open_refiner")

console.register_command(@(count) requestProfileServer("force_set_alter_containers_count", {count}, {}, updateProfileBlocks),
  "profile.force_set_alter_containers_count")

console.register_command(@(level) requestProfileServer("force_set_monolith_access_level", {level}, {}, updateProfileBlocks),
  "profile.force_set_monolith_access_level")

console.register_command(@(count) requestProfileServer("force_set_stash_upgrades", {count}, {}, updateProfileBlocks),
  "profile.force_set_stash_upgrades")

console.register_command(@(level) requestProfileServer("give_monolith_full_access_level", {level}, {}, updateProfileBlocks),
  "profile.give_monolith_full_access_level")

console.register_command(@(count) requestProfileServer("force_set_replicators_count", {count}, {}, updateProfileBlocks),
  "profile.force_set_replicators_count")

console.register_command(@(is_enrich) requestProfileServer("force_change_pouch_enrichment", {is_enrich}, {}, updateProfileBlocks),
  "profile.force_change_pouch_enrichment")

console.register_command(@(is_replica) requestProfileServer("force_change_pouch_replica", {is_replica}, {}, updateProfileBlocks),
  "profile.force_change_pouch_replica")

console.register_command(@(offer_id) requestProfileServer("add_purchased_unique_offer", {offer_id}, {}, updateProfileBlocks),
  "profile.add_purchased_unique_offer")

console.register_command(@(offer_id) requestProfileServer("remove_purchased_unique_offer", {offer_id}, {}, updateProfileBlocks),
  "profile.remove_purchased_unique_offer")

console.register_command(@() requestProfileServer("debug_inventory", {}, {}, updateProfileBlocks),
  "profile.debug_inventory")

console.register_command(@() requestProfileServer("debug_loadout", {}, {}, updateProfileBlocks),
  "profile.debug_loadout")

console.register_command(@() requestProfileServer("reset_rent_equipment_timer", {}, {}, updateProfileBlocks),
  "profile.reset_rent_equipment_timer")

console.register_command(@() requestProfileServer("force_damage_armor_plates", {}, {}, updateProfileBlocks),
  "profile.force_damage_armor_plates")

console.register_command(@(count) requestProfileServer("force_add_experience", {count}, {}, updateProfileBlocks),
  "profile.force_add_experience")

console.register_command(function(session_id, zone_name, is_rented_equipment) {
  requestProfileServer("get_battle_loadout", {
      session_id,
      raid_name = zone_name,
      is_rented_equipment,
      primary_contract_ids = currentPrimaryContractIds.get()}, {}, function(response) {

    updateProfileBlocks(response)
    let filename = get_setting_by_blk_path("debug/AMJsonPath") ?? "active_matter.profile2.json"
    let jwtDecoded = decode_jwt(playerProfileLoadout.get(), profilePublicKey)
    saveJson(filename, jwtDecoded.payload)
    console_print($"Raid profile saved to {filename}")
  })
}, "profile.save_raid_profile_ext")

console.register_command(function(is_rented_equipment = false) {
  let queue = selectedRaid.get()
  let raidName = queue?.extraParams.raidName ?? "sector_unknown+zone_unknown"
  let primary_contract_ids = currentPrimaryContractIds.get()
  console_print($"Save raid profile for raidName <{raidName}> is_rented_equipment <{is_rented_equipment}> primary_contract_ids <{primary_contract_ids}>")
  requestProfileServer("get_battle_loadout", {
      session_id=$"{rand.rint(1, 10000000)}",
      raid_name = raidName,
      is_rented_equipment,
      primary_contract_ids}, {}, function(response) {

    updateProfileBlocks(response)
    let filename = get_setting_by_blk_path("debug/AMJsonPath") ?? "active_matter.profile2.json"
    let jwtDecoded = decode_jwt(playerProfileLoadout.get(), profilePublicKey)
    saveJson(filename, jwtDecoded.payload)
    console_print($"Raid profile saved to {filename}")
  })
}, "profile.save_raid_profile")

console.register_command(function() {
  let queue = selectedRaid.get()
  let raidName = queue?.extraParams.raidName ?? "sector_unknown+zone_unknown"
  let primary_contract_ids = currentPrimaryContractIds.get()
  console_print($"Save nexus profile")
  requestProfileServer("get_nexus_loadout", {
      session_id=$"{rand.rint(1, 10000000)}",
      raid_name = raidName,
      selected_mints=alterMints.get().map(@(v) v.id),
      primary_contract_ids}, {}, function(response) {

    updateProfileBlocks(response)
    let filename = get_setting_by_blk_path("debug/AMJsonPath") ?? "active_matter.profile2.json"
    let jwtDecoded = decode_jwt(playerProfileLoadout.get(), profilePublicKey)
    saveJson(filename, jwtDecoded.payload)
    console_print($"Nexus profile saved to {filename}")
  })
}, "profile.save_nexus_profile")

console.register_command(function(session_id, raid_name, is_rented_equipment) {
  requestProfileServer("get_battle_loadout", {
      session_id,
      raid_name,
      is_rented_equipment,
      primary_contract_ids = currentPrimaryContractIds.get()}, {}, function(response) {

    updateProfileBlocks(response)
    let filename = get_setting_by_blk_path("debug/AMJsonPath") ?? "active_matter.profile2.json"
    saveJson(filename, {
      jwtToken = playerProfileLoadout.get()
    })
    console_print($"Raid profile saved to {filename}")
  })
}, "profile.save_raid_profile_ext_jwt")

console.register_command(function() {
  let profileFilename = get_setting_by_blk_path("debug/AMResultJsonPath") ?? "battle_result.json"
  local loadedProfile = loadJson(profileFilename, {load_text_file = read_text_directly_from_fs_file})
  requestProfileServer("apply_cheat_battle_result", loadedProfile, {}, updateProfileBlocks)
}, "profile.apply_cheat_battle_result")

console.register_command(function() {
  let profileFilename = get_setting_by_blk_path("debug/AMResultJsonPath") ?? "nexus_result.json"
  local loadedProfile = loadJson(profileFilename, {load_text_file = read_text_directly_from_fs_file})
  requestProfileServer("apply_cheat_nexus_result", loadedProfile, {}, updateProfileBlocks)
}, "profile.apply_cheat_nexus_result")

console.register_command(function(){
  if ((playerBaseState.get()?.openedReplicatorDevices ?? 0) == 0)
    requestProfileServer("force_set_replicators_count", {count = 1}, {}, updateProfileBlocks)
  if ((playerBaseState.get()?.openedAMCleaningDevices ?? 0) == 0)
    requestProfileServer("force_set_refiners_count", {count = 1}, {}, updateProfileBlocks)
  if ((playerBaseState.get()?.openedAlterContainers ?? 0) < 2)
    requestProfileServer("force_set_alter_containers_count", {count = 2}, {}, updateProfileBlocks)
}, "ui.unlock_all_consoles")

eventbus_subscribe("profile.add_research_points_to_node",
  function(nodeInfo) {
    requestProfileServer("add_research_points_to_node", nodeInfo, {}, updateProfileBlocks)
  }
)

eventbus_subscribe("profile.add_chronotraces_to_research_node",
  function(nodeInfo) {
    requestProfileServer("add_chronotraces_to_research_node", nodeInfo, {}, updateProfileBlocks)
  }
)

eventbus_subscribe("profile_server.claim_craft_recipe",
  @(node_data)
    requestProfileServer("claim_craft_recipe", node_data, {}, updateProfileBlocks)
  )

eventbus_subscribe("profile_server.buyLots",
  function(lots) {
    log("buy_lots request\n", lots)
    requestProfileServer("buy_lots", {lots}, {}, function(response) {
      updateProfileBlocks(response)
      eventbus_send($"profile_server.buyLots.result", response?.result)
    })
  }
)

eventbus_subscribe("profile_server.buyLotInSlot",
  function(lot) {
    log("buy_lot_in_slot request\n", lot)
    requestProfileServer("buy_lot_in_slot", lot, {}, function(response) {
      updateProfileBlocks(response)
      eventbus_send($"profile_server.buyLots.result", response?.result)
    })
  }
)

eventbus_subscribe("profile_server.destroyItems",
  @(items) requestProfileServer("destroy_items", {items}, {}, updateProfileBlocks))

eventbus_subscribe("profile_server.completeContracts",
  @(contractIds) requestProfileServer("complete_contracts", {contractIds}, {}, function(response) {
      let oldOpenedNodes = deep_clone(playerProfileOpenedNodes.get())
      let oldCurrency = clone playerProfileCreditsCount.get()
      let oldMonolithTokens = clone playerProfileMonolithTokensCount.get()
      let oldChronotraces = clone playerProfileChronotracesCount.get()
      let oldPlayerBaseState = deep_clone(playerBaseState.get())
      let oldItems = clone(stashItems.get())
      let oldUnlocks = clone playerStats.get().unlocks


      updateProfileBlocks(response)

      let researches = researchNodesDiff(oldOpenedNodes)
      let currency = currencyDiff(oldCurrency, playerProfileCreditsCount.get())
      let monolithTokens = currencyDiff(oldMonolithTokens, playerProfileMonolithTokensCount.get())
      let chronotraces = currencyDiff(oldChronotraces, playerProfileChronotracesCount.get())
      let baseUpdates = playerBaseStateDiff(oldPlayerBaseState)
      let unlocks = unlocksDiff(oldUnlocks)

      if (response?.result?.need_more_stash_space) {
        eventbus_send($"profile_server.completeContracts.result#{contractIds[0]}", response?.result?.need_more_stash_space)
      }
      else if (response?.result) {
        eventbus_send($"profile_server.completeContracts.result#{contractIds[0]}", {
          itemsAdd = response.result?.inventory_diff?.add
          itemsUpdate = itemsDiff(oldItems, response.result?.inventory_diff?.update ?? [])
          researches
          currency
          monolithTokens
          chronotraces
          baseUpdates
          unlocks
        })
      }
  }))

eventbus_subscribe("profile_server.update_daily_contracts",
  @(_) requestProfileServer("update_daily_contracts", {}, {}, updateProfileBlocks))

eventbus_subscribe("profile_server.add_craft_task", function(data) {
  requestProfileServer("add_craft_task", data, {}, function(response) {
    updateProfileBlocks(response)

    eventbus_send($"profile_server.add_craft_task.result#{data.replicatorSlotIdx}")
  })
})

eventbus_subscribe("profile_server.repair_item", function(data) {
  requestProfileServer("repair_item", data, {}, function(response) {
    updateProfileBlocks(response)

    eventbus_send($"profile_server.repair_item.result")
  })
})

eventbus_subscribe("profile_server.complete_craft_tasks",
  function(task_ids) {
    requestProfileServer("complete_craft_tasks", {task_ids}, {}, function(response) {
      let oldItems = clone(stashItems.get())
      updateProfileBlocks(response)
      let itemsAdd = response?.result?.inventory_diff?.add
      let itemsUpdate = response?.result?.inventory_diff?.update
      let idsString = ",".join(task_ids)
      if (response?.result?.need_more_stash_space)
        eventbus_send($"profile_server.complete_craft_tasks.result#{idsString}", response?.result?.need_more_stash_space)
      if (itemsAdd || itemsUpdate)
        eventbus_send($"profile_server.complete_craft_tasks.result#{idsString}", {
          itemsAdd
          itemsUpdate = itemsDiff(oldItems, itemsUpdate ?? [])
        })
    })
  })

eventbus_subscribe("profile_server.repair_craft_recipe",
  @(craft_recipe_id) requestProfileServer("repair_craft_recipe", {craft_recipe_id}, {}, function(response) {
    updateProfileBlocks(response)
    eventbus_send("profile_server.repair_craft_recipe.result", {})
  }))

eventbus_subscribe("profile_server.requestUnlockBattleReserve",
  @(_) requestProfileServer("unlock_equipment", {}, {}, updateProfileBlocks))

eventbus_subscribe("profile_server.add_refine_task", @(data)
  requestProfileServer("add_refine_task", data, {}, function(response){
    updateProfileBlocks(response)

    eventbus_send($"profile_server.add_refine_task.result")
  }))

eventbus_subscribe("profile_server.complete_refine_task",
  @(taskId) requestProfileServer("complete_refine_task", {taskId}, {}, function(response) {
      let oldCurrency = clone playerProfileCreditsCount.get()
      let oldOpenedNodes = deep_clone(playerProfileOpenedNodes.get())
      let oldChronotraces = clone playerProfileChronotracesCount.get()

      updateProfileBlocks(response)
      let currency = currencyDiff(oldCurrency, playerProfileCreditsCount.get())
      let researches = researchNodesDiff(oldOpenedNodes)
      let chronotraces = currencyDiff(oldChronotraces, playerProfileChronotracesCount.get())

      eventbus_send($"profile_server.complete_refine_task.result#{taskId}", {
        itemsAdd = response?.result.inventory_diff?.add
        currency
        researches
        chronotraces
      })
    }))

eventbus_subscribe("profile_server.get_battle_loadout",
  @(data) requestProfileServer("get_battle_loadout", data, {}, function(response){
    updateProfileBlocks(response)
    eventbus_send("profile_server.get_battle_loadout.recieved")
  }))

eventbus_subscribe("profile_server.get_nexus_loadout",
  @(data) requestProfileServer("get_nexus_loadout", data, {}, updateProfileBlocks))

ecs.register_es("load_state_from_profile_es", {
  onInit = @(_eid, comp) !comp.player_profile__isLoaded ? loadFullProfile() : null
  },
  { comps_ro=[["player_profile__isLoaded", ecs.TYPE_BOOL]] },
  { tags="gameClient" }
)

let transactions_in_progress_query = ecs.SqQuery("transactions_in_progress_query", { comps_rw=[["player_profile__applyTransactionsInProgress", ecs.TYPE_BOOL]] })

eventbus_subscribe("profile_server.make_alter_from_chronogenes",
  @(genes) requestProfileServer("make_alter_from_chronogenes",
    {
      container_id_int64=genes?.container_id_int64 ?? 0,
      primary_chronogenes=genes.mainGenes,
      secondary_chronogenes=genes.secondaryGenes
      alter_name=genes.alterName
    }, {}, function(response) {
      updateProfileBlocks(response)
      eventbus_send("profile_server.make_alter_from_chronogenes.result", {})
    }))

eventbus_subscribe("profile_server.remove_alter_from_container",
  @(container_id_int64) requestProfileServer("remove_alter_from_container",
    container_id_int64, {}, function(response) {
      updateProfileBlocks(response)
      eventbus_send("profile_server.remove_alter_from_container.result", {})
    }))

eventbus_subscribe("profile_server.possess_alter",
  function (container_id_int64) {
    requestProfileServer("possess_alter", container_id_int64, {}, updateProfileBlocks)
  }
)

ecs.register_es("inventory_profile_send_transactions_es",
  {
    [["onInit", "onChange"]] = function (_evt, _eid, comp) {
      if (comp.player_profile__applyTransactionsInProgress)
        return

      local arr = comp.player_profile__queuedTransactions.getAll()
      if (arr.len() <= 0)
        return

      log("apply_transactions request\n", arr)
      comp.player_profile__applyTransactionsInProgress = true
      requestProfileServer("apply_transactions", { transactions=arr }, {}, function(response) {
        updateProfileBlocks(response)
        transactions_in_progress_query.perform(function(_response_eid, response_comp) { response_comp.player_profile__applyTransactionsInProgress = false })
      })
      arr.clear()
      comp.player_profile__queuedTransactions = arr
    }
  },
  {
    comps_rw = [
      ["player_profile__queuedTransactions", ecs.TYPE_ARRAY],
      ["player_profile__applyTransactionsInProgress", ecs.TYPE_BOOL]
    ],
    comps_track = [
      ["player_profile__queuedTransactions", ecs.TYPE_ARRAY],
      ["player_profile__applyTransactionsInProgress", ecs.TYPE_BOOL]
    ]
  },
  { tags="gameClient" }
)


ecs.register_es("profile_finish_onboarding_phase",
{
  [EventOnboardingPhaseResult] = function(evt, _eid, _comp) {
    requestProfileServer("onboarding_battle_result", {
      unlocks=evt.data.unlocks.getAll(),
      loadout=evt.data.items.getAll(),
      am_count=evt.amCount
    }, {}, function(response) {
      updateProfileBlocks(response)
      eventbus_send("profile_server.profile_finish_onboarding_phase.result", response)
    })
  }
},
{
  comps_rq = ["player"]
})


let clearPlayerUnlocksQuery = ecs.SqQuery("clear_player_unlocks_Query", {
  comps_rw=[
    ["player__newUnlocks", ecs.TYPE_STRING_LIST],
    ["player__unlocks", ecs.TYPE_STRING_LIST],
    ["active_matter_player__unlockedNotes", ecs.TYPE_STRING_LIST]
  ],
  comps_ro = [["is_local", ecs.TYPE_BOOL]],
})

ecs.register_es("profile_monolith_path_selection",
{
  [EventGameTrigger] = function(evt, _eid, comp) {
    if (evt.triggerHash != comp.game_trigger_processor__onTriggerHash)
      return
    if (comp.onboarding_monolith_path_selection__pathId == 0) {
      clearPlayerUnlocksQuery.perform(function(_, compQ) {
        if (!compQ?.is_local)
          return
        compQ.player__newUnlocks = []
        compQ.player__unlocks = ["onboarding_base_first_time"]
        compQ.active_matter_player__unlockedNotes = []
        playerStats.mutate(@(v) v.unlocks <- [])
      })
    }
    requestProfileServer("player_select_monolith_path", {
      path_id = comp.onboarding_monolith_path_selection__pathId
    }, {}, updateProfileBlocks)
  }
},
{
  comps_ro=[
    ["game_trigger_processor__onTriggerHash", ecs.TYPE_INT],
    ["onboarding_monolith_path_selection__pathId", ecs.TYPE_INT]
  ]
  comps_no = ["game_trigger_processor_disabled"]
})





ecs.register_es("profile_open_unlock_on_base",
{
  [EventUnlockAppear] = function(evt, _eid, _comp) {
    if (!isOnPlayerBase.get() || isOnboarding.get())
      return

    requestProfileServer("player_base_open_unlock", { unlock=evt.unlockName }, {}, updateProfileBlocks)
  }
},
{
  comps_rq = ["player"]
}, { tags="gameClient" })


ecs.register_es("profile_force_load",
{
  [CmdForceLoadProfile] = function(_evt, _eid, _comp) {
    loadFullProfile()
  }
},
{
  comps_rq = ["player"]
})


return {
  loadFullProfile
  generate_loadout_by_seed
}
