from "%ui/ui_library.nut" import *
from "%ui/devInfo.nut" import addTabToDevInfo
from "%dngscripts/globalState.nut" import nestWatched

let playerProfileLoadout = nestWatched("playerProfileLoadout", null)
let playerProfileLoadoutUpdate = @(v) playerProfileLoadout.set(v)
let playerProfileCurrentContracts = nestWatched("playerProfileCurrentContracts", {})
let playerProfileCurrentContractsUpdate = @(v) playerProfileCurrentContracts.set(v)
let playerProfileCreditsCount = nestWatched("playerProfileCreditsCount", 0.0)
let playerProfileCreditsCountUpdate = @(v) playerProfileCreditsCount.set(v)
let playerProfileChronotracesCount = nestWatched("playerProfileChronotracesCount", 0)
let playerProfileMonolithTokensCount = nestWatched("playerProfileMonolithTokensCount", 0.0)
let playerProfileMonolithTokensCountUpdate = @(v) playerProfileMonolithTokensCount.set(v)
let playerProfileExperience = nestWatched("playerProfileExperience", 0)
let playerReserveEndAt = nestWatched("playerReserveEndAt", 0)
let playerReserveEndAtUpdate = @(v) playerReserveEndAt.set(v)
let playerProfileAMConvertionRate = nestWatched("playerProfileAMConvertionRate", 100)
let playerProfileAMConvertionRateUpdate = @(v) playerProfileAMConvertionRate.set(v)
let marketPriceSellMultiplier = nestWatched("marketPriceSellMultiplier", 1.0)
let marketPriceSellMultiplierUpdate = @(v) marketPriceSellMultiplier.set(v)
let currentContractsUpdateTimeleft = nestWatched("currentContractsUpdateTimeleft", 0)
let currentContractsUpdateTimeleftUpdate = @(v) currentContractsUpdateTimeleft.set(v)
let marketItems = nestWatched("marketItems", {})
let marketItemsUpdate = @(v) marketItems.set(v)
let allRecipes = nestWatched("allRecipes", {})
let allCraftRecipes = Computed(@() allRecipes.get().filter(@(v) !v?.components.len()))
let refinerFusingRecipes = Computed(@() allRecipes.get().filter(@(v) v?.components.len()))
let playerProfileOpenedNodes = nestWatched("playerProfileOpenedNodes", [])
let playerProfileOpenedNodesUpdate = @(v) playerProfileOpenedNodes.set(v)
let playerProfileAllResearchNodes = nestWatched("playerProfileAllResearchNodes", [])
let playerProfileAllResearchNodesUpdate = @(v) playerProfileAllResearchNodes.set(v)
let amProcessingTask = nestWatched("amProcessingTask", null)
let craftTasks = nestWatched("craftTasks", {})
let craftTasksUpdate = @(v) craftTasks.set(v)
let cleanableItems = nestWatched("cleanableItems", {})
let cleanableItemsUpdate = @(v) cleanableItems.set(v)
let teamColorIdxs = nestWatched("teamColorIdxs", {primary=-1, secondary=-1})
let teamColorIdxsUpdate = @(v) teamColorIdxs.set(v)
let playerStats = nestWatched("playerStats", {})
let playerStatsUpdate = @(v) playerStats.set(v)
let nextMindtransferTimeleft = nestWatched("nextMindtransferTimeleft", 0.0)
let nextMindtransferTimeleftUpdate = @(v) nextMindtransferTimeleft.set(v)
let mindtransferSeed = nestWatched("mindtransferSeed", "0")
let mindtransferSeedUpdate = @(v) mindtransferSeed.set(v)
let playerBaseState = nestWatched("playerBaseState", {})
let playerBaseStateUpdate = @(v) playerBaseState.set(v)
let currentAlter = nestWatched("currentAlter", null)
let alterContainers = nestWatched("alterContainers", [])
let lastBattleResult = nestWatched("lastBattleResult", {})
let lastNexusResult = nestWatched("lastNexusResult", {})
let repairRelativePrice = nestWatched("repairRelativePrice", 0.0)
let playerProfileUnlocksData = nestWatched("playerProfileUnlocksData", {})
let playerProfileUnlocksDataUpdate = @(v) playerProfileUnlocksData.set(v)
let refinedItemsList = nestWatched("refinedItemsList", []) 
let alterMints = nestWatched("alterMints", [])
let loadoutsAgency = nestWatched("loadoutsAgency", {})
let playerProfileNexusLoadoutStorageCount = nestWatched("playerProfileNexusLoadoutStorageCount", 10)
let playerExperienceToLevel = nestWatched("playerExperienceToLevel", {})
let allPassiveChronogenes = nestWatched("allPassiveChronogenes", {})
let completedStoryContracts = nestWatched("completedStoryContracts", {})
let completedStoryContractsUpdate = @(v) completedStoryContracts.set(v)
let playerProfilePremiumCredits = nestWatched("playerProfilePremiumCredits", 0)
let nextOfflineSessionId = nestWatched("nextOfflineSessionId", -1)
let numOfflineRaidsAvailable = nestWatched("numOfflineRaidsAvailable", 0)
let offlineFreeTicketAt = nestWatched("offlineFreeTicketAt", -1)
let nexusNodesState = nestWatched("nexusNodesState", {})
let freeTicketsPerDay = nestWatched("freeTicketsPerDay", 0)
let freeTicketsLimit = nestWatched("freeTicketsLimit", 0)
let nexusNodesStateUpdate = @(v) nexusNodesState.set(v)
let alwaysIsolatedQueues = nestWatched("alwaysIsolatedQueues", {})
let neverIsolatedQueues = nestWatched("neverIsolatedQueues", {})
let trialData = nestWatched("trialData", null)


addTabToDevInfo("Console commands", "", @"
    profile.unlock_all_shop -- unlock all items in shop until first 'profile.load'
    profile.force_set_credits_count <count> -- set credits to shopping
    profile.force_set_monolith_credits_count <count> -- set monolith credits to shopping

    profile.force_change_pouch_enrichment <is_enrich> -- make items in IIFS Load Vest enriched (UI reload required after)
    profile.force_change_stash_enrichment <is_enrich> -- make items in STASH enriched  (UI reload required after)

    profile.modify_player_stat <'mode'> <'stat_name'> <diff_value> -- add/remove value from selected stat

    profile.force_open_refiner -- add refiner to base
    profile.force_set_replicators_count <count> -- set replicators count on base
")


addTabToDevInfo("allCraftRecipes", allCraftRecipes)
addTabToDevInfo("alterContainers", alterContainers)
addTabToDevInfo("amProcessingTask", amProcessingTask)
addTabToDevInfo("cleanableItems", cleanableItems)
addTabToDevInfo("completedStoryContracts", completedStoryContracts)
addTabToDevInfo("craftTasks", craftTasks)
addTabToDevInfo("currentAlter", currentAlter)
addTabToDevInfo("currentContractsUpdateTimeleft", currentContractsUpdateTimeleft)
addTabToDevInfo("marketItems", marketItems)
addTabToDevInfo("nextMindtransferTimeleft", nextMindtransferTimeleft)
addTabToDevInfo("playerBaseState", playerBaseState)
addTabToDevInfo("playerProfileAllResearchNodes", playerProfileAllResearchNodes)
addTabToDevInfo("playerProfileCurrentContracts", playerProfileCurrentContracts)
addTabToDevInfo("playerProfileOpenedNodes", playerProfileOpenedNodes)
addTabToDevInfo("playerProfileUnlocks" ,playerProfileUnlocksData)
addTabToDevInfo("playerStats", playerStats)
addTabToDevInfo("refinerFusingRecipes", refinerFusingRecipes)
addTabToDevInfo("nexusNodesState", nexusNodesState)

return {
  playerProfileLoadout, playerProfileLoadoutUpdate,
  playerProfileCreditsCount, playerProfileCreditsCountUpdate,
  playerProfileChronotracesCount,
  playerProfileMonolithTokensCount, playerProfileMonolithTokensCountUpdate, playerProfileExperience,
  playerExperienceToLevel, allPassiveChronogenes,
  playerReserveEndAt, playerReserveEndAtUpdate,
  playerProfileAMConvertionRate, playerProfileAMConvertionRateUpdate,
  marketPriceSellMultiplier, marketPriceSellMultiplierUpdate,
  playerProfileCurrentContracts, playerProfileCurrentContractsUpdate,
  currentContractsUpdateTimeleft, currentContractsUpdateTimeleftUpdate,
  marketItems, marketItemsUpdate,
  allRecipes,
  allCraftRecipes,
  playerProfileOpenedNodes, playerProfileOpenedNodesUpdate,
  playerProfileAllResearchNodes, playerProfileAllResearchNodesUpdate,
  amProcessingTask
  craftTasks, craftTasksUpdate,
  cleanableItems, cleanableItemsUpdate,
  playerStats, playerStatsUpdate,
  nextMindtransferTimeleft, nextMindtransferTimeleftUpdate,
  mindtransferSeed, mindtransferSeedUpdate,
  playerBaseState, playerBaseStateUpdate,
  currentAlter,
  alterContainers,
  repairRelativePrice,
  playerProfileUnlocksData, playerProfileUnlocksDataUpdate,
  refinerFusingRecipes, refinedItemsList
  alterMints,
  loadoutsAgency,
  playerProfileNexusLoadoutStorageCount,
  teamColorIdxs, teamColorIdxsUpdate
  lastBattleResult,
  lastNexusResult,
  completedStoryContracts, completedStoryContractsUpdate,
  playerProfilePremiumCredits
  nextOfflineSessionId, numOfflineRaidsAvailable,
  offlineFreeTicketAt,
  freeTicketsPerDay,
  freeTicketsLimit,
  nexusNodesState, nexusNodesStateUpdate,
  alwaysIsolatedQueues, neverIsolatedQueues,
  trialData
}
