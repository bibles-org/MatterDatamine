import "%dngscripts/ecs.nut" as ecs
import "%ui/components/msgbox.nut" as msgbox
from "%ui/ui_library.nut" import *
from "math" import min, max

let {
  playerProfileLoadoutUpdate,
  playerProfileCreditsCountUpdate,
  playerProfileChronotracesCount,
  playerProfileMonolithTokensCountUpdate,
  playerProfileAMConvertionRateUpdate,
  playerProfileNexusLoadoutStorageCount,
  playerReserveEndAtUpdate,
  marketPriceSellMultiplierUpdate,
  playerProfileCurrentContractsUpdate,
  currentContractsUpdateTimeleftUpdate,
  marketItemsUpdate,
  allCraftRecipesUpdate,
  playerProfileOpenedNodesUpdate,
  playerProfileOpenedRecipesUpdate,
  playerProfileAllResearchNodesUpdate,
  craftTasksUpdate,
  cleanableItemsUpdate,
  playerStatsUpdate,
  nextMindtransferTimeleftUpdate,
  mindtransferSeedUpdate,
  playerBaseStateUpdate,
  currentAlter,
  alterContainers,
  lastBattleResult,
  lastNexusResult,
  repairRelativePrice,
  playerProfileUnlocksData, playerProfileUnlocksDataUpdate,
  refinerFusingRecipes,
  refinedItemsList,
  alterMints,
  loadoutsAgency,
  amProcessingTask,
  playerProfileExperience,
  playerExperienceToLevel,
  allPassiveChronogenes
} = require("%ui/profile/profileState.nut")
let { get_sync_time } = require("net")
let { eventbus_send } = require("eventbus")
let { CmdUpdateActiveBuildings, CmdUpdateBasePower, EventProfileLoaded, EventEquipAlter, sendNetEvent } = require("dasevents")
let { parseBaseBuildings, parseBasePower } = require("%ui/profile/profile_functions.nut")
let {FLT_MAX} = require("math")

let { logerr } = require("dagor.debug")
let decode_jwt = require("jwt").decode
let { profilePublicKey } = require("%ui/profile/profile_pubkey.nut")
let { localPlayerEid } = require("%ui/hud/state/local_player.nut")
let { logOut } = require("%ui/login/login_state.nut")
let { parse_json } = require("%sqstd/json.nut")
let { decodeString } = require("base64")
let { updateDebriefingContractsData } = require("%ui/mainMenu/debriefing/debriefing_quests_state.nut")
let { isOnPlayerBase } = require("%ui/hud/state/gametype_state.nut")
let { addTabToDevInfo } = require("%ui/devInfo.nut")

local battle_reserve_update_timer = null

function unpackResponse(answer, error_header, profileLoadOnError=true) {
  let err = answer?.error
  let res = answer?.result
  if (err != null || res == null) {
    let errMessage = (type(err) == "string") ? $"[curl] {err}" : $"[profile server] {err?.message ?? "Unspecified error"}"
    logerr($"{error_header}: {errMessage}")
    if (profileLoadOnError)
      eventbus_send("profile.load")
    if (err == "Couldn't connect to server"){
      logOut()
      msgbox.showMsgbox({
        text = $"[profile server] {loc("error/CLIENT_ERROR_CONNECTION_CLOSED")}",
        buttons = [{ text = loc("Ok"), isCurrent = true, action = @() null }]
      })
    }

    return null
  }
  return res
}

let loadStateComps = {
  comps_rw = [
    ["player_profile__allBuilds", ecs.TYPE_ARRAY],
    ["player_profile__isLoaded", ecs.TYPE_BOOL],
    ["player_profile__allItems", ecs.TYPE_ARRAY],
    ["player_profile__stashMaxVolume", ecs.TYPE_FLOAT],
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
    ["player_profile__alterIds", ecs.TYPE_STRING_LIST],
    ["player_profile__alterIdsChanged", ecs.TYPE_BOOL]
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

let craftHandler = function(craft_block, _comp) {
  
  allCraftRecipesUpdate((craft_block?.craft_recipes ?? []).map(@(v) [v.k, v.v]).totable())
}

let openedNodesHandler = function(opened_nodes, _comp) {
  playerProfileOpenedNodesUpdate(opened_nodes)
}

let openedCraftRecipesHandler = function(opened_recipes, _comp) {
  playerProfileOpenedRecipesUpdate(opened_recipes)
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

let inventoryHandler = function(inventory_block, comp) {
  log("inventory_block (old = client loadout | new = profile server loadout)", inventory_block)
  debugDiffItems(comp.player_profile__allItems.getAll(), inventory_block, "inventory_block")
  comp.player_profile__allItems = inventory_block.allItems
}

let contractsHandler = function(contracts_block, _comp) {
  
  let newAllContracts = (contracts_block?.currentContracts ?? [])
    .map(@(v) [v.k, v.v]).totable()
    .map(@(contract) contract.__merge({params =
      contract.params.reduce(function(res, param) {
        if (param.name in res)
          res[param.name].append(param.value)
        else
          res[param.name] <- [param.value]
        return res
      }, {})
    }))
  playerProfileCurrentContractsUpdate(newAllContracts)
  currentContractsUpdateTimeleftUpdate(get_sync_time() + (contracts_block?.currentContractsUpdateTimeleft ?? 60))
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
  amProcessingTask(refineTasks)
}

let refinerFusingRecipesHandlers = function(fusingRecipes, _comp) {
  refinerFusingRecipes.set(fusingRecipes)
}

let craftTasksHandler = function(craftTasks, _comp) {
  log("craftTasks update", craftTasks)
  
  let curTime = get_sync_time()
  craftTasks.each(@(i) i.craftCompleteAt += curTime)
  craftTasksUpdate(craftTasks)
}

let playerStatsHandler = function(playerStats, comp) {
  
  playerStatsUpdate(playerStats)
  comp.player_profile__unlocks = playerStats?.unlocks ?? []
}

let playerBaseStateHandler = function(playerBaseState, comp) {
  
  comp.player_profile__amCleaningDevicesCount = playerBaseState?.openedAMCleaningDevices ?? 0
  comp.player_profile__replicatorDevicesCount = playerBaseState?.openedReplicatorDevices ?? 0
  comp.player_profile__stashMaxVolume = (playerBaseState.stashVolumeSize + playerBaseState.stashAdditionalVolume * playerBaseState.stashVolumeUpgrade) / 10.0
  
  playerBaseStateUpdate(playerBaseState)
}

let experienceToLevelRateHandler = function (experience_to_level_rate, _comp) {
  playerExperienceToLevel.set(experience_to_level_rate)
}

let allPassiveChronogenesHandler = function (all_passive_chronogenes, _comp) {
  allPassiveChronogenes.set(all_passive_chronogenes)
}

let alterHandler = function(alterContainerBlock, comp) {
  
  comp.player_profile__alterIds = alterContainerBlock?.currentContainers.map(@(c) c?.primaryChronogenes?[0]) ?? []
  comp.player_profile__alterIdsChanged = true
  
  let newCurrentAlter = alterContainerBlock?.currentAlter
  currentAlter.set(newCurrentAlter)
  alterContainers.set(alterContainerBlock?.currentContainers ?? [])
  let alterToEquip = alterContainers.get().findvalue(@(i) i.containerId == newCurrentAlter)
  if (alterToEquip != null) {
    let chronogenesList = ecs.CompObject()
    chronogenesList["primaryChronogenes"] <- alterToEquip?.primaryChronogenes ?? []
    chronogenesList["secondaryChronogenes"] <- alterToEquip?.secondaryChronogenes ?? []
    sendNetEvent(localPlayerEid.get(), EventEquipAlter({ chronogenesList }))
  }
}

let mintsHandler = function(mints, _comp) {
  log("mints update", mints)
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
  if ((last_battle_result?.dateTime ?? 0) == 0){
    lastBattleResult.set(null)
    return
  }

  let scene = last_battle_result?.battleAreaInfo?.scene
  if (scene == null || scene == "")
    return

  let encodedTrackPoints = last_battle_result?.trackPointsV2 ?? ""
  let trackPoints = encodedTrackPoints.len() > 0 ? parse_json(decodeString(encodedTrackPoints)) : []
  last_battle_result.trackPoints <- trackPoints

  let encodedTeamInfo = last_battle_result?.teamInfo ?? ""
  last_battle_result.teamInfo = encodedTeamInfo.len() > 0 ? parse_json(decodeString(last_battle_result.teamInfo)) : {}

  lastBattleResult.set(last_battle_result)
  updateDebriefingContractsData(isOnPlayerBase.get(), lastBattleResult.get())
}

let lastNexusResultHandler = function(last_nexus_result, _comp) {
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

addTabToDevInfo("[STATS] playerProfileUnlocks" ,playerProfileUnlocksData)
let unlocksDataHandler = function(unlocks_data, _comp) {
  playerProfileUnlocksDataUpdate(unlocks_data)
}


let profileBlocksHandlerTable = {
  market_block = marketHandler
  craft_block = craftHandler
  all_research_nodes = allResearchNodesHandler
  opened_nodes = openedNodesHandler
  inventory_block = inventoryHandler
  inventory_diff = inventoryDiffHandler
  contracts_block = contractsHandler
  battle_reserve_block = battleReserveHandler
  currency = currencyHandler
  am_to_credits_conversion_rate = amToCreditsHandler
  nexus_loadout_settings = nexusLoadoutSettingsHandler
  basePower = basePowerHandler
  deployedConstructions = deployedConstructionsHandler
  refineTask = refineTasksHandler
  refiner_fusing_recipes = refinerFusingRecipesHandlers
  opened_craft_recipes = openedCraftRecipesHandler
  craftTasks = craftTasksHandler
  player_stats = playerStatsHandler
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
}

let updateProfileBlocks = function(response, profileLoadOnError=true) {
  load_state_from_profile_query.perform(function(_eid, comp) {
    unpackResponse(response, "Fail update profile blocks", profileLoadOnError)
      ?.each(@(block, block_key) profileBlocksHandlerTable?[block_key]?(block, comp))
  })
}

function updateProfileBlocksFullLoad(response) {
  updateProfileBlocks(response, false)
  load_state_from_profile_query.perform(function(_eid, comp){
    comp.player_profile__isLoaded = true
    ecs.g_entity_mgr.broadcastEvent(EventProfileLoaded())
  })
}

return {
  unpackResponse
  updateProfileBlocks
  updateProfileBlocksFullLoad
}
