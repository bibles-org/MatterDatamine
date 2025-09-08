let { nestWatched } = require("%dngscripts/globalState.nut")

let playerProfileLoadout = nestWatched("playerProfileLoadout", [])
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
let allCraftRecipes = nestWatched("allCraftRecipes", [])
let allCraftRecipesUpdate = @(v) allCraftRecipes.set(v)
let playerProfileOpenedNodes = nestWatched("playerProfileOpenedNodes", [])
let playerProfileOpenedNodesUpdate = @(v) playerProfileOpenedNodes.set(v)
let playerProfileOpenedRecipes = nestWatched("playerProfileOpenedRecipes", [])
let playerProfileOpenedRecipesUpdate = @(v) playerProfileOpenedRecipes.set(v)
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
let refinerFusingRecipes = nestWatched("refinerFusingRecipes", [])
let refinedItemsList = nestWatched("refinedItemsList", []) 
let alterMints = nestWatched("alterMints", [])
let loadoutsAgency = nestWatched("loadoutsAgency", {})
let playerProfileNexusLoadoutStorageCount = nestWatched("playerProfileNexusLoadoutStorageCount", 10)
let playerExperienceToLevel = nestWatched("playerExperienceToLevel", {})
let allPassiveChronogenes = nestWatched("allPassiveChronogenes", {})

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
  allCraftRecipes, allCraftRecipesUpdate,
  playerProfileOpenedNodes, playerProfileOpenedNodesUpdate,
  playerProfileOpenedRecipes, playerProfileOpenedRecipesUpdate,
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
  lastNexusResult
}

