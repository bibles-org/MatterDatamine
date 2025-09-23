from "%sqstd/json.nut" import parse_json
from "%sqGlob/profile_server.nut" import requestProfileServer
from "%sqGlob/dasenums.nut" import ContractType

from "%ui/profile/profileState.nut" import playerProfileLoadoutUpdate, playerProfileCreditsCountUpdate, playerProfileMonolithTokensCountUpdate, playerProfileAMConvertionRateUpdate,
  playerReserveEndAtUpdate, marketPriceSellMultiplierUpdate, playerProfileCurrentContractsUpdate, currentContractsUpdateTimeleftUpdate,
  marketItemsUpdate, playerProfileOpenedNodesUpdate, allRecipes, nextOfflineSessionId, numOfflineRaidsAvailable, offlineFreeTicketAt,
  freeTicketsPerDay, freeTicketsLimit,
  playerProfileAllResearchNodesUpdate, craftTasksUpdate, cleanableItemsUpdate, playerStatsUpdate,
  nextMindtransferTimeleftUpdate, mindtransferSeedUpdate, playerBaseStateUpdate, playerProfileUnlocksDataUpdate, completedStoryContractsUpdate,
  nexusNodesStateUpdate, alwaysIsolatedQueues, neverIsolatedQueues, trialData

from "net" import get_sync_time
from "eventbus" import eventbus_send
from "dasevents" import CmdUpdateActiveBuildings, CmdUpdateBasePower, EventProfileLoaded, EventEquipAlter, sendNetEvent
from "%ui/profile/profile_functions.nut" import parseBaseBuildings, parseBasePower
from "math" import FLT_MAX
from "dagor.debug" import logerr
from "jwt" import decode as decode_jwt

from "base64" import decodeString
from "%ui/mainMenu/debriefing/debriefing_quests_state.nut" import updateDebriefingContractsData
from "das.equipment" import hero_clean_all_equipment_and_gun_slots
from "dagor.random" import rnd_int
import "%dngscripts/ecs.nut" as ecs
import "%ui/components/msgbox.nut" as msgbox
from "%ui/ui_library.nut" import *
from "math" import min, max

let { playerProfileChronotracesCount, playerProfileNexusLoadoutStorageCount, playerStats, currentAlter, alterContainers, lastBattleResult,
      lastNexusResult, repairRelativePrice, refinedItemsList, alterMints, loadoutsAgency,
      amProcessingTask, playerProfileExperience, playerExperienceToLevel, allPassiveChronogenes,
      playerProfilePremiumCredits } = require("%ui/profile/profileState.nut")

let { profilePublicKey } = require("%ui/profile/profile_pubkey.nut")
let { localPlayerEid } = require("%ui/hud/state/local_player.nut")
let { isOnPlayerBase } = require("%ui/hud/state/gametype_state.nut")

local battle_reserve_update_timer = null
let randomTimeGap = rnd_int(0, 300)

function unpackResponse(answer, error_header) {
  let err = answer?.error
  let res = answer?.result
  if (err != null || res == null) {
    let errMessage = (type(err) == "string") ? $"[curl] {err}" : $"[profile server] {err?.message ?? "Unspecified error"}"
    logerr($"{error_header}: {errMessage}")
    eventbus_send("profile.load")

    return null
  }
  return res
}

let loadStateComps = {
  comps_rw = [
    ["player_profile__allBuilds", ecs.TYPE_ARRAY],
    ["player_profile__isLoaded", ecs.TYPE_BOOL],
    ["player_profile__allItems", ecs.TYPE_ARRAY],
    ["player_profile__playerNexusPresets", ecs.TYPE_OBJECT],
    ["player_profile__stashMaxVolume", ecs.TYPE_INT],
    ["player_profile__loadout", ecs.TYPE_ARRAY],
    ["player_profile__currentContracts", ecs.TYPE_ARRAY],
    ["player_profile__creditsCount", ecs.TYPE_INT],
    ["player_profile__monolithTokensCount", ecs.TYPE_INT],
    ["player_profile__unlocks", ecs.TYPE_STRING_LIST],
    ["player_profile__reserveEndAt", ecs.TYPE_UINT64],
    ["player_profile__amResource", ecs.TYPE_INT],
    ["player_profile__am2CreditsConversionRate", ecs.TYPE_FLOAT],
    ["player_profile__activeBuildingsPositions", ecs.TYPE_IPOINT2_LIST],
    ["player_profile__activeBuildingsRotations", ecs.TYPE_INT_LIST],
    ["player_profile__activeBuildingsGridIds", ecs.TYPE_INT_LIST],
    ["player_profile__activeBuildingsIds", ecs.TYPE_STRING_LIST],
    ["player_profile__basePower", ecs.TYPE_OBJECT],
    ["player_profile__itemAdditionQueue", ecs.TYPE_ARRAY],
    ["player_profile__itemDeletionQueue", ecs.TYPE_ARRAY],
    ["player_profile__itemUpdateQueue", ecs.TYPE_ARRAY],
    ["player_profile__replicatorDevicesCount", ecs.TYPE_INT],
    ["player_profile__amCleaningDevicesCount", ecs.TYPE_INT],
    ["player_profile__alterIds", ecs.TYPE_STRING_LIST]
  ]
}

let load_state_from_profile_query = ecs.SqQuery("load_state_from_profile_query", loadStateComps)

let marketHandler = function(market_block, comp) {
  
  comp.player_profile__allBuilds = (market_block?.items ?? []).map(@(v) v.v.__merge({id = v.k})).filter(@(v) (v?.itemType ?? "") == "builds")
  
  marketItemsUpdate((market_block?.offers ?? []).map(@(v) [v.k.tostring(), v.v]).totable())
  marketPriceSellMultiplierUpdate(market_block?.marketSellDiscount ?? 1)
  repairRelativePrice.set(market_block?.repairRelativePrice ?? 1.0)
  cleanableItemsUpdate(market_block?.cleanable_items ?? [])
}

let craftRecipesHandler = function(craft_recipes, _comp) {
  
  let tableRecipes = (craft_recipes ?? []).map(@(v) [v.k, v.v]).totable()
  allRecipes.set(tableRecipes)
}

let openedNodesHandler = function(opened_nodes, _comp) {
  playerProfileOpenedNodesUpdate(opened_nodes)
}

let allResearchNodesHandler = function(all_research_nodes, _comp) {
  playerProfileAllResearchNodesUpdate(all_research_nodes
    .reduce(function(prevval, curval){
      prevval[curval.k] <- curval.v
      return prevval
    }, {})
  )
}

let debugDiffItems = function(old_items, new_items, prefix) {
  let addedItems = new_items.filter(@(new_v) old_items.findvalue(@(old_v) new_v?.itemId == old_v?.itemId) == null)
  let deletedItems = old_items.filter(@(old_v) new_items.findvalue(@(new_v) new_v?.itemId == old_v?.itemId) == null)
  local modifiedItems = []
  foreach (v in new_items) {
    let old_v = old_items.findvalue(@(old_v) v?.itemId == old_v?.itemId)
    if (old_v == null) {
      continue
    }

    local modifiedArguments = {itemId=v?.itemId ?? "Missing"}
    local isModified = false

    if (v?.templateName != old_v?.templateName) {
      modifiedArguments.__update({templateName=$"{old_v?.templateName ?? "Missing"} => {v?.templateName ?? "Missing"}"})
      isModified = true
    }
    else {
      modifiedArguments.__update({templateName=v?.templateName ?? "Missing"})
    }
    if (v?.parentItemId != old_v?.parentItemId) {
      modifiedArguments.__update({parentItemId=$"{old_v?.parentItemId ?? "Missing"} => {v?.parentItemId ?? "Missing"}"})
      isModified = true
    }
    if (v?.slotName != old_v?.slotName) {
      modifiedArguments.__update({slotName=$"{old_v?.slotName ?? "Missing"} => {v?.slotName ?? "Missing"}"})
      isModified = true
    }
    if (v?.charges != null && v?.charges != old_v?.charges) {
      modifiedArguments.__update({charges=$"{old_v?.charges ?? "Missing"} => {v?.charges ?? "Missing"}"})
      isModified = true
    }

    if (isModified) {
      modifiedItems.append(modifiedArguments)
    }
  }

  log($"{prefix} added\n", addedItems)
  log($"{prefix} mopdified (values will be presented as `param = old => new`)\n", modifiedItems)
  log($"{prefix} deleted\n", deletedItems)
  log($"{prefix} old\n", old_items)
  log($"{prefix} new\n", new_items)
}

let debugInventoryHandler = function(debug_inventory_block, comp) {
  log("debug_inventory_block (old = client inventory | new = profile server inventory)")
  debugDiffItems(comp.player_profile__allItems.getAll(), debug_inventory_block, "debug_inventory_block")
}

let debugLoadoutHandler = function(debug_loadout_block, comp) {
  log("debug_loadout_block (old = client loadout | new = profile server loadout)")
  debugDiffItems(comp.player_profile__loadout.getAll(), debug_loadout_block, "debug_loadout_block")
}

let allItemsHandler = function(all_items, comp) {
  log("all_items (old = client loadout | new = profile server loadout)", all_items)
  debugDiffItems(comp.player_profile__allItems.getAll(), all_items, "all_items")
  comp.player_profile__allItems = all_items
}

let contractsHandler = function(contracts_block, _comp) {
  
  let newAllContracts = (contracts_block?.currentContracts ?? [])
    .map(@(v) [v.k, v.v]).totable()
    .map(@(contract) contract.__merge({
      params = contract.params.reduce(function(res, param) {
        if (param.name in res)
          res[param.name].append(param.value)
        else
          res[param.name] <- [param.value]
        return res
      }, {}),
      contractType =
        contract.uniqueContract ? ContractType.STORY :
        contract.dailyRestoring ? ContractType.SECONDARY :
        contract.params.findindex(@(v) v.name == "monsterTag") != null ? ContractType.MONSTER :
        ContractType.PRIMARY
    }))
  playerProfileCurrentContractsUpdate(newAllContracts)
  currentContractsUpdateTimeleftUpdate(get_sync_time() + (contracts_block?.currentContractsUpdateTimeleft ?? 60) + randomTimeGap)
}

let battleReserveHandler = function(battle_reserve_block, comp) {
  log("battle_reserve_block update", battle_reserve_block)
  
  local nextReserveUpdate = FLT_MAX
  let itemReserveBySessionId = battle_reserve_block?.itemReserveBySessionId
  if(itemReserveBySessionId) {
    foreach(_, sessionReserve in battle_reserve_block.itemReserveBySessionId){
      nextReserveUpdate = min(nextReserveUpdate, sessionReserve.reserveEndAt)
    }
  }
  ecs.clear_callback_timer(battle_reserve_update_timer)
  if (nextReserveUpdate != FLT_MAX){
    comp.player_profile__reserveEndAt = get_sync_time() + nextReserveUpdate
    battle_reserve_update_timer = ecs.set_callback_timer(
      @() eventbus_send("profile_server.requestUnlockBattleReserve", null),
      nextReserveUpdate,
      false
    )
  }
  else
    comp.player_profile__reserveEndAt = 0
  
  playerReserveEndAtUpdate(comp.player_profile__reserveEndAt)
}

let currencyHandler = function(currency, comp) {
  
  comp.player_profile__creditsCount = currency.creditsCount
  comp.player_profile__monolithTokensCount = currency.monolithTokensCount
  
  playerProfileCreditsCountUpdate(currency.creditsCount)
  playerProfileMonolithTokensCountUpdate(currency.monolithTokensCount)
  playerProfileChronotracesCount.set(currency.chronotracesCount)
  playerProfileExperience.set(currency.experienceCount)
  playerProfilePremiumCredits.set(currency.premiumCreditsCount)
}

let mindtransferInfoHandler = function(mindtransfer_info, _comp) {
  
  nextMindtransferTimeleftUpdate(max(0.0, get_sync_time() + mindtransfer_info.timeleft))
  mindtransferSeedUpdate(mindtransfer_info.seed)
}

let battleLoadoutHandler = function(signed_battle_loadout, _comp) {
  let res = decode_jwt(signed_battle_loadout, profilePublicKey)
  if ("error" in res) {
    let resError = res["error"]
    logerr($"Could not decode signed battle loadout jwt: {resError}. JWT: {signed_battle_loadout}")
    eventbus_send("battle_loadout_sign_failed")
    return
  }
  log($"For session: {res?.payload?.sessionId} new Jwt Token: {signed_battle_loadout}\n",
      "battle_loadout\n", res?.payload?.loadoutItems)
  playerProfileLoadoutUpdate(signed_battle_loadout)

  eventbus_send("battle_loadout_sign_success")
}

let nexusLoadoutHandler = function(signed_nexus_loadout, _comp) {
  let res = decode_jwt(signed_nexus_loadout, profilePublicKey)
  if ("error" in res) {
    let resError = res["error"]
    logerr($"Could not decode signed nexus loadout jwt: {resError}. JWT: {signed_nexus_loadout}")
    eventbus_send("battle_loadout_sign_failed")
    return
  }
  log($"For session: {res?.payload?.sessionId} new Jwt Token: {signed_nexus_loadout}\n")
  playerProfileLoadoutUpdate(signed_nexus_loadout)
  eventbus_send("battle_loadout_sign_success")
}

let amToCreditsHandler = function(am_to_credits_conversion_rate, comp) {
  
  comp.player_profile__am2CreditsConversionRate = am_to_credits_conversion_rate
  
  playerProfileAMConvertionRateUpdate(am_to_credits_conversion_rate)
}

let nexusLoadoutSettingsHandler = function(nexus_loadout_settings, _comp) {
  
  playerProfileNexusLoadoutStorageCount.set(nexus_loadout_settings.storage_count)
}

let basePowerHandler = function(basePower, comp) {
  
  comp.player_profile__basePower = parseBasePower(basePower)
  ecs.g_entity_mgr.broadcastEvent(CmdUpdateBasePower())
}

let deployedConstructionsHandler = function(deployedConstructions, comp) {
  
  let {positions, rotations, ids_int64, gridIds} = parseBaseBuildings(deployedConstructions)
  comp.player_profile__activeBuildingsPositions = positions
  comp.player_profile__activeBuildingsRotations = rotations
  comp.player_profile__activeBuildingsIds = ids_int64
  comp.player_profile__activeBuildingsGridIds = gridIds
  ecs.g_entity_mgr.broadcastEvent(CmdUpdateActiveBuildings())
}

let refineTasksHandler = function(refineTasks, _comp) {
  log("refineTasks update", refineTasks)
  if (refineTasks?.taskId == null) {
    amProcessingTask.set(null)
    return
  }

  
  let curTime = get_sync_time()
  refineTasks.endTimeAt = refineTasks.endTimeAt.tointeger() + curTime
  amProcessingTask.set(refineTasks)
}

let craftTasksHandler = function(craftTasks, _comp) {
  log("craftTasks update", craftTasks)
  
  let curTime = get_sync_time()
  craftTasks.each(@(i) i.craftCompleteAt += curTime)
  craftTasksUpdate(craftTasks)
}

let purchasedUniqueMarketOffersHandler = function(uniqueOffers, _comp) {
  playerStats.mutate(@(stats) stats.purchasedUniqueMarketOffers = uniqueOffers )
}

let completedStoryContractsHandler = function(completed_story_contracts, _comp) {
  completedStoryContractsUpdate(completed_story_contracts)
}

let requestFreeOfflineRaidTicketsFromProfile = @() eventbus_send("profile_server.requestFreeOfflineTickets", null)

let offlineRaidDataHandler = function(offline_raid_data, _comp) {
  nextOfflineSessionId.set(offline_raid_data?.nextSessionId ?? "0")
  numOfflineRaidsAvailable.set(offline_raid_data?.numRaidsAvailable ?? 0)
  if (offline_raid_data?.freeTicketIn != null) {
    offlineFreeTicketAt.set(offline_raid_data.freeTicketIn + get_sync_time())
    gui_scene.resetTimeout(offline_raid_data.freeTicketIn, requestFreeOfflineRaidTicketsFromProfile, "request_free_tickets_on_timer_expired")
  }
  freeTicketsPerDay.set(offline_raid_data?.freeTicketsPerDay ?? 0)
  freeTicketsLimit.set(offline_raid_data?.freeTicketsLimit ?? 0)
}

let nexusStateHandler = function(nexus_state, _comp) {
  nexusNodesStateUpdate(nexus_state)
}

let playerStatsHandler = function(player_stats, comp) {
  
  playerStatsUpdate(player_stats)
  comp.player_profile__unlocks = player_stats?.unlocks ?? []
}

let modify_stat = function(stats_table, mode, stat_name, stat_diff) {
  let oldVal = stats_table?[mode]?[stat_name] ?? 0.0
  if (stats_table?[mode] == null)
    stats_table[mode] <- {}
  stats_table[mode][stat_name] <- oldVal + stat_diff
}

let statsDiffHandler = function(stats_diff, _comp) {
  
  playerStats.mutate(function(stats){
    if (!("statsCurrentSeason" in stats) || !("stats" in stats))
      return
    let statsSeason = stats.statsCurrentSeason
    let statsAll = stats.stats
    foreach (mode, modeStats in stats_diff) {
      foreach (statName, statDiff in modeStats) {
        modify_stat(statsSeason, mode, statName, statDiff)
        modify_stat(statsAll, mode, statName, statDiff)
      }
    }
  })
}

let unlocksDiffHandler = function(unlocks_diff, comp) {
  
  playerStats.mutate(function(stats){
    if (!("unlocks" in stats))
      return
    foreach (unlockName, isAdded in unlocks_diff) {
      if (isAdded) {
        stats.unlocks.append(unlockName)
      }
      else {
        let idx = stats.unlocks.indexof(unlockName)
        if (idx != null) {
          stats.unlocks.remove(idx)
        }
      }
    }
  })
  comp.player_profile__unlocks = playerStats.get().unlocks
}

let playerBaseStateHandler = function(playerBaseState, comp) {
  
  comp.player_profile__amCleaningDevicesCount = playerBaseState?.openedAMCleaningDevices ?? 0
  comp.player_profile__replicatorDevicesCount = playerBaseState?.openedReplicatorDevices ?? 0
  let additionalBaseStashesCount = playerBaseState.stashesCount.x * playerBaseState.stashVolumeUpgrade.x
  let additionalPrestigeStashesCount = playerBaseState.stashesCount.y * playerBaseState.stashVolumeUpgrade.y
  comp.player_profile__stashMaxVolume = playerBaseState.stashVolumeSize + additionalBaseStashesCount + additionalPrestigeStashesCount
  
  playerBaseStateUpdate(playerBaseState)
}

let experienceToLevelRateHandler = function (experience_to_level_rate, _comp) {
  playerExperienceToLevel.set(experience_to_level_rate)
}

let allPassiveChronogenesHandler = function (all_passive_chronogenes, _comp) {
  allPassiveChronogenes.set(all_passive_chronogenes)
}

let alterHandler = function(alterContainerBlock, _comp) {
  let newCurrentAlter = alterContainerBlock?.currentAlter
  currentAlter.set(newCurrentAlter)
  alterContainers.set(alterContainerBlock?.currentContainers ?? [])
  let alterToEquip = alterContainers.get().findvalue(@(i) i.containerId == newCurrentAlter)
  if (alterToEquip != null) {
    let chronogenesList = ecs.CompObject()
    chronogenesList["primaryChronogenes"] <- alterToEquip?.primaryChronogenes ?? []
    chronogenesList["secondaryChronogenes"] <- alterToEquip?.secondaryChronogenes ?? []
    chronogenesList["stubMeleeChronogenes"] <- alterToEquip?.stubMeleeChronogenes ?? []
    chronogenesList["dogtagChronogenes"] <- alterToEquip?.dogtagChronogenes ?? []
    sendNetEvent(localPlayerEid.get(), EventEquipAlter({ chronogenesList }))
  }
}

let mintsHandler = function(mints, comp) {
  log("mints update", mints)

  let obj = {}
  foreach (idx, v in mints) {
    obj[idx.tostring()] <- v
  }

  comp.player_profile__playerNexusPresets = obj
  alterMints.set(mints)
}

let loadoutsAgencyHandler = function(loadouts_agency, _comp) {
  log("loadouts_agency update", loadouts_agency)

  loadoutsAgency.set({
    updateTimeAt = get_sync_time() + loadouts_agency.updateTimeLeft.tofloat()
    seed = loadouts_agency.seed
    count = loadouts_agency.count
  })
}

let inventoryDiffHandler = function(inventory_diff, comp) {
  log("inventory_diff_block update", inventory_diff)
  let additions = inventory_diff?.add ?? []
  let deletions = inventory_diff?.remove ?? []
  let updates = inventory_diff?.update ?? []
  if (additions.len() > 0){
    local existingQueue = comp.player_profile__itemAdditionQueue.getAll()
    foreach (a in additions){
      existingQueue.append(a)
    }
    comp.player_profile__itemAdditionQueue = existingQueue
  }
  if (deletions.len() > 0){
    local existingQueue = comp.player_profile__itemDeletionQueue.getAll()
    foreach (a in deletions){
      existingQueue.append(a)
    }
    comp.player_profile__itemDeletionQueue = existingQueue
  }
  if (updates.len() > 0){
    local existingQueue = comp.player_profile__itemUpdateQueue.getAll()
    foreach (a in updates){
      existingQueue.append(a)
    }
    comp.player_profile__itemUpdateQueue = existingQueue
  }
}

let lastBattleResultHandler = function(last_battle_result, _comp) {
  log("Last battle result handler called")
  if ((last_battle_result?.dateTime ?? 0) == 0){
    lastBattleResult.set(null)
    return
  }

  let scene = last_battle_result?.battleAreaInfo?.scene
  if (scene == null || scene == "")
    return
  log($"Scene = {scene} time = {last_battle_result?.dateTime} id = {last_battle_result?.id}")
  let encodedTrackPoints = last_battle_result?.trackPointsV2 ?? ""
  let trackPoints = encodedTrackPoints.len() > 0 ? parse_json(decodeString(encodedTrackPoints)) : []
  last_battle_result.trackPoints <- trackPoints
  if (encodedTrackPoints.len() > 0) {
    last_battle_result.$rawdelete("trackPointsV2")
  }

  let encodedTeamInfo = last_battle_result?.teamInfo ?? ""
  last_battle_result.teamInfo = encodedTeamInfo.len() > 0 ? parse_json(decodeString(last_battle_result.teamInfo)) : {}

  lastBattleResult.set(last_battle_result)
  updateDebriefingContractsData(isOnPlayerBase.get(), lastBattleResult.get())
}

let lastNexusResultHandler = function(last_nexus_result, _comp) {
  log($"lastNexusResultHandler called, dateTime = {last_nexus_result?.dateTime}")
  if ((last_nexus_result?.dateTime ?? 0) == 0){
    lastNexusResult.set(null)
    return
  }

  let encodedModeData = last_nexus_result?.modeSpecificData ?? ""
  let encodedPlayers = last_nexus_result?.players ?? ""
  let encodedMvps = last_nexus_result?.mvps ?? ""

  let modeData = encodedModeData.len() > 0 ? parse_json(decodeString(encodedModeData)) : []
  let players = encodedPlayers.len() > 0 ? parse_json(decodeString(encodedPlayers)) : []
  let mvps = encodedMvps.len() > 0 ? parse_json(decodeString(encodedMvps)) : []

  last_nexus_result.modeSpecificData <- modeData
  last_nexus_result.players <- players
  last_nexus_result.mvps <- mvps

  lastNexusResult.set(last_nexus_result)
}

let refinedItemsListHandler = function(refined_items, _comp) {
  refinedItemsList.set(refined_items)
}

let unlocksDataHandler = function(unlocks_data, _comp) {
  playerProfileUnlocksDataUpdate(unlocks_data)
}

let neverIsolatedQueuesHandler = function(data, _comp) {
  neverIsolatedQueues.set(data)
}

let alwaysIsolatedQueuesHandler = function(data, _comp) {
  alwaysIsolatedQueues.set(data)
}

let trialDataHandler = function(data, _comp) {
  trialData.set(data)
}

let profileBlocksHandlerTable = {
  market_block = marketHandler
  craft_recipes = craftRecipesHandler
  all_research_nodes = allResearchNodesHandler
  neverIsolatedQueues = neverIsolatedQueuesHandler
  alwaysIsolatedQueues = alwaysIsolatedQueuesHandler
  opened_nodes = openedNodesHandler
  all_items = allItemsHandler
  inventory_diff = inventoryDiffHandler
  contracts_block = contractsHandler
  battle_reserve_block = battleReserveHandler
  currency = currencyHandler
  am_to_credits_conversion_rate = amToCreditsHandler
  nexus_loadout_settings = nexusLoadoutSettingsHandler
  basePower = basePowerHandler
  deployedConstructions = deployedConstructionsHandler
  refineTask = refineTasksHandler
  craftTasks = craftTasksHandler
  player_stats = playerStatsHandler
  stats_diff = statsDiffHandler
  unlocks_diff = unlocksDiffHandler
  player_base_state = playerBaseStateHandler
  experience_to_level_rate = experienceToLevelRateHandler
  all_passive_chronogenes = allPassiveChronogenesHandler
  alter_containers_block = alterHandler
  mindtransfer_info = mindtransferInfoHandler
  signed_battle_loadout = battleLoadoutHandler
  signed_nexus_loadout = nexusLoadoutHandler
  last_battle_result = lastBattleResultHandler
  last_nexus_result = lastNexusResultHandler
  unlocks_data = unlocksDataHandler
  debug_inventory_block = debugInventoryHandler
  debug_loadout_block = debugLoadoutHandler
  mints = mintsHandler
  loadouts_agency = loadoutsAgencyHandler
  refined_items = refinedItemsListHandler
  purchased_unique_market_offers = purchasedUniqueMarketOffersHandler
  completed_story_contracts = completedStoryContractsHandler
  offline_raid_data = offlineRaidDataHandler
  nexus_state = nexusStateHandler
  trial_data = trialDataHandler
}

let updateProfileBlocks = function(response) {
  load_state_from_profile_query.perform(function(_eid, comp) {
    unpackResponse(response, "Fail update profile blocks")
      ?.each(@(block, block_key) profileBlocksHandlerTable?[block_key]?(block, comp))
  })
}


local isLoading = false

function updateProfileBlocksFullLoad(response) {
  load_state_from_profile_query.perform(function(_eid, comp) {
    let unpackedResult = unpackResponse(response, "Fail update profile blocks")
    if (unpackedResult != null) {
      
      isLoading = false

      hero_clean_all_equipment_and_gun_slots()
      unpackedResult.each(@(block, block_key) profileBlocksHandlerTable?[block_key]?(block, comp))
      comp.player_profile__isLoaded = true
      ecs.g_entity_mgr.broadcastEvent(EventProfileLoaded())
    }
    else { 
      isLoading = false
      eventbus_send("profile.load")
      logerr($"Trying to restore profile data")
      
      
      
      
      
      
      
      
    }
  })
}

let profile_loaded_query = ecs.SqQuery("profile_loaded_query", { comps_rw=[["player_profile__isLoaded", ecs.TYPE_BOOL]] })

function loadFullProfile(request_name = "load_profile") {
  profile_loaded_query.perform(function(_eid, comp) {
    comp.player_profile__isLoaded = false
    if (!isLoading) {
      isLoading = true
      requestProfileServer(request_name, null, {}, updateProfileBlocksFullLoad)
    }
  })
}

return {
  unpackResponse
  updateProfileBlocks
  updateProfileBlocksFullLoad
  loadFullProfile
}
