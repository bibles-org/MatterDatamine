from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs
from "%ui/components/colors.nut" import BtnBgHover, BtnBgNormal, SelBgNormal, BtnBdSelected, BtnBgDisabled, BtnBgSelected, InfoTextDescColor, InfoTextValueColor, BtnTextNormal,
  RarityUncommon, RarityRare, RarityCommon, ItemBgColor, RedWarningColor, SelBdNormal, SelBdSelected
import "%ui/components/fontawesome.map.nut" as fa
from "math" import ceil

let tooltipBox = require("%ui/components/tooltipBox.nut")
let { get_matching_utc_time } = require("%ui/state/matchingUtils.nut")
let { isZoneUnlocked } = require("%ui/state/queueState.nut")
let { playerProfileCurrentContracts, currentContractsUpdateTimeleft, playerStats, allCraftRecipes,
  nextMindtransferTimeleft, marketItems } = require("%ui/profile/profileState.nut")
let { selectedRaid } = require("%ui/gameModeState.nut")
let { getContractProgressionText } = require("%ui/hud/objectives/objective_components.nut")
let { sub_txt, tiny_txt, body_txt, fontawesome } = require("%ui/fonts_style.nut")
let { addTabToDevInfo } = require("%ui/devInfo.nut")
let { textButtonSmall } = require("%ui/components/button.nut")
let { itemIconNoBorder } = require("%ui/components/itemIconComponent.nut")
let { mkText, mkTooltiped, mkMonospaceTimeComp, mkDescTextarea, getTextColorForSelectedPanelText } = require("%ui/components/commonComponents.nut")
let { eventbus_subscribe_onehit, eventbus_send } = require("eventbus")
let { makeVertScrollExt, overlappedStyle } = require("%ui/components/scrollbar.nut")
let { getCraftResultItems, mkCraftResultsItems } = require("craftIcons.nut")
let { showMsgBoxResult } = require("%ui/components/profileAnswerMsgBox.nut")
let { showMessageWithContent, showMsgbox } = require("%ui/components/msgbox.nut")
let { mkCountdownTimerPerSec } = require("%ui/helpers/timers.nut")
let { ContractType } = require("%sqGlob/dasenums.nut")
let { isOnboarding, playerProfileOnboardingContracts } = require("%ui/hud/state/onboarding_state.nut")
let { mkFakeItem, mkFakeAttachments } = require("%ui/hud/menus/components/fakeItem.nut")
let { buildInventoryItemTooltip } = require("%ui/hud/menus/components/inventoryItemTooltip.nut")
let { mkRarityIconByTemplateName } = require("%ui/hud/menus/components/inventoryItemRarity.nut")
let { inventoryItem } = require("%ui/hud/menus/components/inventoryItem.nut")
let { LOOTBOX_SHOW_RESULT } = require("%ui/hud/menus/components/inventoryItemTypes.nut")
let { currentPrimaryContractIds, Raid_id } = require("%ui/mainMenu/raid_preparation_window_state.nut")
let { MonolithMenuId, monolithSelectedLevel, monolithSectionToReturn } = require("%ui/mainMenu/monolith/monolith_common.nut")
let { accentButtonStyle, successButtonStyle, stopButtonStyle } = require("%ui/components/accentButton.style.nut")
let faComp = require("%ui/components/faComp.nut")
let colorize = require("%ui/components/colorize.nut")
let { openMenu } = require("%ui/hud/hud_menus_state.nut")
let { setTooltip } = require("%ui/components/cursors.nut")
let { mkOnlineSaveData } = require("%ui/options/mkOnlineSaveData.nut")
let { addPlayerLog, mkPlayerLog } = require("%ui/popup/player_event_log.nut")

addTabToDevInfo("playerProfileCurrentContracts", playerProfileCurrentContracts)
addTabToDevInfo("currentContractsUpdateTimeleft", currentContractsUpdateTimeleft)
addTabToDevInfo("[STATS] playerStats", playerStats, "console commands: \n    profile.modify_player_stat <\"mode\"> <\"stat_name\"> <diff_value>")
addTabToDevInfo("[STATS] nextMindtransferTimeleft", nextMindtransferTimeleft)

const PRIMARY_CONTRACT_ALARM = "primary_contract_alarm"

let primaryContractAlramShowSetting = mkOnlineSaveData(PRIMARY_CONTRACT_ALARM, @() true)
let primaryContractAlramWatch = primaryContractAlramShowSetting.watch
let primaryContractAlramSet = primaryContractAlramShowSetting.setValue

let mkPrimaryContractMsgbox = @() showMsgbox({
  text = loc("contracts/primaryAlertContactHeader")
  buttons = [
    {
      text = loc("Ok")
      isCurrent = true
    },
    {
      text = loc("contract/acceptAndDontShow")
      action = @() primaryContractAlramSet(false)
      isCurrent = true
    },
  ]
})


let selectedContract = Watched(-1)
let contractReportIsInProgress = Watched(false)

let contractBtnHeight = 26 

function showMsgBoxCraftResult(result, name = null) {
  let contractName = name ? $"{loc($"contract/{name}")}\n" : ""
  let header = $"{contractName}{loc("craft/resultReceived")}"
  showMsgBoxResult(header, result, contractName, @() contractReportIsInProgress.set(false))
}

let mkCounter = @(text) {
  rendObj = ROBJ_BOX
  borderRadius = const [0, 0, hdpx(5), 0]
  fillColor = Color(67, 67, 67)
  vplace = ALIGN_TOP
  hplace = ALIGN_LEFT
  padding = hdpx(3)
  children = mkText(text, const { fontSize = hdpx(17) })
}

function mkContractMark(contract){
  let fontSize = hdpx(16)
  let tooltips = []
  let children = []
  if (contract?.contractType == ContractType.PRIMARY) {
    children.append(faComp("star", { fontSize color = contract.isReported ? InfoTextDescColor : Color(255, 255, 255) }))
    tooltips.append(const ["star", loc("contracts/primaryContractTooltip")])
  }
  else if (contract?.contractType == ContractType.SECONDARY) {
    children.append(faComp("star-half-empty", { fontSize = hdpx(14) color = contract.isReported ? InfoTextDescColor : Color(255, 255, 255) }))
    tooltips.append(const ["star-half-empty", loc("contracts/secondaryContractTooltip")])
  }
  else if (contract?.contractType == ContractType.MONSTER) {
    children.append(faComp("star-half-empty", {fontSize = hdpx(14)color = contract.isReported ? InfoTextDescColor : Color(255, 255, 255) }))
    tooltips.append(const ["star-half-empty", loc("contracts/primaryContractTooltip")])
  }
  else if (contract?.contractType == ContractType.STORY || contract?.contractType == ContractType.ITEM) {
    children.append(faComp("book", {fontSize color = contract.isReported ? InfoTextDescColor : Color(255, 255, 255)}))
    tooltips.append(const ["book", loc("contracts/storyContractTooltip", "Storyline")])
  }
  if (contract?.blockExtractionWhenIncomplete && !contract.isReported) {
    children.insert(1, const faComp("warning", { fontSize color = RedWarningColor}))
    tooltips.insert(1, const ["warning", loc("contract/required"), RedWarningColor])
  }
  return mkTooltiped({
    children
    flow = FLOW_HORIZONTAL
    gap = hdpx(2)
  }, tooltipBox({
    padding = hdpx(2) flow = FLOW_VERTICAL gap = hdpx(1)
    children = tooltips.map(@(v) {
      maxWidth = hdpx(400) rendObj = ROBJ_TEXTAREA behavior = Behaviors.TextArea
      tagsTable = {fa = {font=fontawesome.font, color = v?[2] ?? Color(255,255,255), fontSize = tiny_txt.fontSize}}
      text = " - ".concat("".concat("<fa>", fa[v[0]], "</fa>"), v[1])
    }.__update(sub_txt))
  }))
}

function reportContract(ids, protect_watch, name){
  eventbus_subscribe_onehit($"profile_server.completeContracts.result#{ids[0]}", function(diff) {
    showMsgBoxCraftResult(diff, name)
  })
  protect_watch.set(true)
  eventbus_send("profile_server.completeContracts", ids)
}

let mkCheckIcon = @(btnHeight) faComp("check", {
  size = const [SIZE_TO_CONTENT, btnHeight]
  fontSize = btnHeight
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  color = InfoTextDescColor
})

let mkContractName = @(contract, isReported, selected, isHover) {
  text = loc($"contract/{contract.name}")
  rendObj = ROBJ_TEXT
  behavior = Behaviors.Marquee
  scrollOnHover = true
  color = isReported ? InfoTextDescColor : getTextColorForSelectedPanelText(selected, isHover)
  size = const [flex(), SIZE_TO_CONTENT]
}

let btnBack = const {size = flex() rendObj = ROBJ_SOLID margin = hdpx(1) color = Color(0,0,0,100)}
let iconBtnStyle = const { size = hdpxi(25) font = fontawesome.font fontSize = hdpxi(18) halign = ALIGN_CENTER valign = ALIGN_CENTER}

function mkGetPrimaryContractBtn(contract, currentPrimaries) {
  if (contract.id not in currentPrimaries) {
    return {
      children = [
        btnBack
        textButtonSmall(loc("contracts/take"), function(){
          if (primaryContractAlramWatch.get())
            mkPrimaryContractMsgbox()
          let { weaponType = null } = contract?.params
          if (weaponType != null)
            addPlayerLog({
              id = $"{contract}_{contract.id}"
              idToIgnore = $"{contract}_{contract.id}"
              content = mkPlayerLog({
                titleText = loc("re_attention")
                titleFaIcon = "exclamation-circle"
                bodyText = loc("contract/weaponType", { weaponType = loc($"items/types/{weaponType[0]}" )})
              })
            })
          currentPrimaryContractIds.mutate(@(v) v[contract.id] <- true)
        }, {
            isEnabled = !contractReportIsInProgress.get()
            stopHover = true
            maxHeight = iconBtnStyle?.size[1]
            key = $"{contract}_accept"
          }.__update(accentButtonStyle))
      ]
    }
  }
  else {
    return textButtonSmall(fa["close"], function() {
      currentPrimaryContractIds.mutate(@(v) v.$rawdelete(contract.id))
    }, {
      isEnabled = !contractReportIsInProgress.get()
      stopHover = true
      onHover = @(on) setTooltip(!on ? null : loc(loc("contracts/declineMonolith")))
      key = $"{contract}_decline"
    }.__update(stopButtonStyle, iconBtnStyle))
  }
}


function mkGetContractBtn(contract, isReported, currentValue, requireValue, btnHeight) {
  if (isReported)
    return mkCheckIcon(btnHeight)
  else if (currentValue >= requireValue)
    return {
      children = [
        btnBack
        textButtonSmall(loc("contracts/report"), function() {
            if (contract?.onReport != null) {
              contract.onReport()
              return
            }
            reportContract([contract.id], contractReportIsInProgress, contract.name)
          }, {
            isEnabled = !contractReportIsInProgress.get()
            maxHeight = iconBtnStyle?.size[1]
          }.__update(successButtonStyle))
     ]
   }
  return { size = [pw(20), btnHeight] }
}

let mkMonolithBtn = @(recs) function() {
  let levelToFocus = (marketItems.get().findvalue(@(v) (v?.children.unlocks ?? []).contains(recs[0])) ?? [])
    .filter(@(v) v != null)
  if (levelToFocus.len() <= 0 )
    return { watch = marketItems }
  let { requirements, offerName } = levelToFocus
  return {
    watch = marketItems
    children = textButtonSmall(fa["lock"],
    function() {
      monolithSelectedLevel.set(requirements.monolithAccessLevel)
      monolithSectionToReturn.set(Raid_id)
      openMenu(MonolithMenuId)
    }, {
      stopHover = true
      style = const {TextNormal  = mul_color(BtnTextNormal, 0.5) }
      onHover = @(on) setTooltip(!on ? null
        : loc("monolith/canBeUnlockedOnLevel", { level = colorize(InfoTextValueColor, loc(offerName)) }))
    }.__update(iconBtnStyle))
  }
}

function mkContractHeader(contract, idx, isRaidAvailable, manyContractsPossible){
  let { isReported, currentValue, requireValue, requireParams = {} } = contract
  let canReport = currentValue >= requireValue
  let btnHeight = hdpx(contractBtnHeight)
  let isSelected = Computed(@() selectedContract.get() == idx)
  let contractRequirements = Computed(function() {
    let contractRecs = requireParams?.completeUnlocksRequire ?? []
    let playerUnlocks = playerStats.get()?.unlocks ?? []
    let neededRecs = contractRecs.filter(@(v) !playerUnlocks.contains(v))
    return neededRecs
  })

  return watchElemState(function(sf) {
    let selected = isSelected.get()
    let isHover = sf & S_HOVER
    let needRecs = contractRequirements.get().len() > 0
    return {
      watch = [isSelected, contractRequirements, isRaidAvailable]
      rendObj = ROBJ_BOX
      size = const [flex(), SIZE_TO_CONTENT]
      fillColor = sf & S_HOVER ? BtnBgHover
        : isSelected.get() ? BtnBgSelected
        : (needRecs || !isRaidAvailable.get()) ? BtnBgDisabled
        : SelBgNormal
      borderColor = selected ? SelBdSelected : SelBdNormal
      borderWidth = selected ? const [hdpx(2), 0,0,0] : const [0,0,0, hdpx(2)]
      behavior = Behaviors.Button
      onClick = @() selectedContract.modify(@(v) v!=idx ? idx : null)
      flow = FLOW_HORIZONTAL
      padding = const [hdpx(5), hdpx(5), hdpx(5), hdpx(10)]
      gap = hdpx(10)
      valign = ALIGN_CENTER
      sound = const {
        hover = "ui_sounds/button_highlight"
        click  = "ui_sounds/button_click"
      }
      children = [
        mkContractMark(contract)
        mkContractName(contract, isReported, selected, isHover)
        !canReport
          ? { size = [SIZE_TO_CONTENT, btnHeight] }
          : @() {
              watch = contractReportIsInProgress
              children = mkGetContractBtn(contract, isReported, currentValue, requireValue, btnHeight)
            }
        isRaidAvailable.get() && contract.contractType == ContractType.PRIMARY && !canReport
          ? needRecs
            ? mkMonolithBtn(contractRequirements.get())
            : manyContractsPossible ? @() {
                watch = [contractReportIsInProgress, currentPrimaryContractIds]
                children = mkGetPrimaryContractBtn(contract, currentPrimaryContractIds.get())
              } : null
          : null
      ]
    }
  })
}


function mkItemIcon(templateName, size, attachments = null) {
  attachments = attachments ?? []
  return itemIconNoBorder(templateName,
    { width=size[0], height=size[1], shading = "full" }, mkFakeAttachments(attachments) )
}
function mkItemChildren(templateName, itemIconSize, attachments=null){
  return [mkItemIcon(templateName, itemIconSize, attachments), mkRarityIconByTemplateName(templateName)]
}

function mkRewardBlock(contract, num_in_row) {
  let iconSize = hdpx(76)
  let itemIconSize = [ iconSize, iconSize ]

  let rewardsTitle = {
    size = [ flex(), SIZE_TO_CONTENT ]
    halign = ALIGN_LEFT
    children = mkText(loc("contracts/rewards/rewardsTitle"))
  }

  let rewards = []

  if ((contract.rewards?.monolithTokens.y ?? 0) > 0) {
    rewards.append(
      mkTooltiped({
        rendObj = ROBJ_BOX
        size = [ iconSize, iconSize ]
        fillColor = RarityRare
        halign = ALIGN_CENTER
        valign = ALIGN_BOTTOM
        children = mkItemChildren("monolith_credit_coins_pile", itemIconSize)
          .append(mkCounter($"{loc("ui/multiply")}{contract.rewards.monolithTokens.x}"))
      }, "{0}\n\n{1}".subst(loc("monolithTokens"), loc("monolithTokens/desc"))))
  }

  if ((contract.rewards?.currency.y ?? 0) > 0) {
    rewards.append(
      mkTooltiped({
        rendObj = ROBJ_BOX
        size = [ iconSize, iconSize ]
        fillColor = RarityUncommon
        halign = ALIGN_CENTER
        valign = ALIGN_BOTTOM
        children = mkItemChildren("credit_coins_pile", itemIconSize)
          .append(mkCounter($"{loc("ui/multiply")}{contract.rewards.currency.x}"))
      }, "{0}\n\n{1}".subst(loc("credits"), loc("currency/desc"))))
  }

  if ((contract.rewards?.chronotraces.y ?? 0) > 0) {
    rewards.append(
      mkTooltiped({
        rendObj = ROBJ_BOX
        size = [ iconSize, iconSize ]
        fillColor = RarityCommon
        halign = ALIGN_CENTER
        valign = ALIGN_BOTTOM
        children = mkItemChildren("chronotrace_coins_pile", itemIconSize)
          .append(mkCounter($"{loc("ui/multiply")}{contract.rewards.chronotraces.y}"))
      }, "{0}\n\n{1}".subst(loc("chronotraces"), loc("chronotraces/desc"))))
  }

  foreach(item in contract.rewards?.items ?? []) {
    let templateName = item.itemPrototypeName
    let fakeItem = mkFakeItem(templateName)
    let itemTooltip = buildInventoryItemTooltip(fakeItem)

    let tooltipedIcon = mkTooltiped({
      rendObj = ROBJ_BOX
      fillColor = Color(30, 30, 30, 20)
      children = mkItemChildren(templateName, itemIconSize)
    }, itemTooltip)

    let itemCount = item.count > 1 ? mkCounter($"{loc("ui/multiply")}{item.count}") : null

    rewards.append({
      rendObj = ROBJ_SOLID
      size = [ iconSize, iconSize ]
      color = ItemBgColor
      valign = ALIGN_BOTTOM
      halign = ALIGN_CENTER
      children = [
        tooltipedIcon
        itemCount
      ]
    })
  }

  local marketOffers = {}
  foreach(marketOffer in contract.rewards?.marketOffers ?? []) {
    let offer = marketItems.get()?[marketOffer.tostring()]?.children?.items
    let templateName = offer?[0].templateName
    if (templateName == null)
      continue
    if (marketOffer.tostring() in marketOffers) {
      marketOffers[marketOffer.tostring()].count += 1
      continue
    }
    let attachments = offer.slice(1).map(@(v) v.templateName)


    let fakeItem = mkFakeItem(templateName)
    let itemTooltip = buildInventoryItemTooltip(fakeItem)

    let tooltipedIcon = mkTooltiped({
      rendObj = ROBJ_BOX
      fillColor = Color(30, 30, 30, 20)
      children =  mkItemChildren(templateName, itemIconSize, attachments)
    }, itemTooltip)

    marketOffers[marketOffer.tostring()] <- {
      tooltipedIcon
      count = 1
    }
  }
  foreach(marketOffer in marketOffers.values()) {
    rewards.append({
      rendObj = ROBJ_SOLID
      size = [iconSize, iconSize]
      color = ItemBgColor
      valign = ALIGN_CENTER
      children = [
        marketOffer.tooltipedIcon
        marketOffer.count > 1 ? mkCounter($"{loc("ui/multiply")}{marketOffer.count}") : null
      ]
    })
  }

  let lootboxes = contract.rewards?.lootboxes ?? []
  if (lootboxes.len() > 0) {
    rewards.extend(lootboxes.map(function(i){
      let fakeItem = mkFakeItem(allCraftRecipes.get()?[i].name ?? "default_lootbox")

      let resultFake = mkCraftResultsItems(
        getCraftResultItems(allCraftRecipes.get()?[i].results ?? {}),
        6
      )

      let itemToShow = inventoryItem(fakeItem, LOOTBOX_SHOW_RESULT, {
        lmbAction = function(_) {
          showMessageWithContent({
            content = {
              flow = FLOW_VERTICAL
              halign = ALIGN_CENTER
              gap = hdpx(10)
              children = [
                mkText(loc("lootbox/results"), body_txt)
                resultFake
              ]
            }
          })
        }
      })

      return itemToShow
    }))
  }

  foreach(playerBaseUpgrade in contract.rewards?.playerBaseUpgrades ?? []) {
    let name = $"base_upgrade_{playerBaseUpgrade}"
    let fakeItem = mkFakeItem(name)
    let tooltip = buildInventoryItemTooltip(fakeItem)
    let tooltipedIcon = mkTooltiped({
      rendObj = ROBJ_BOX
      fillColor = Color(30, 30, 30, 20)
      children = mkItemChildren($"base_upgrade_{playerBaseUpgrade}", itemIconSize)
    }, tooltip)

    rewards.append({
      rendObj = ROBJ_BOX
      fillColor = Color(20, 50, 50, 100)
      valign = ALIGN_CENTER
      halign = ALIGN_CENTER
      size = iconSize
      children = tooltipedIcon
    })
  }

  let playerUnlocks = playerStats.get()?.unlocks ?? []
  foreach(unlock in contract.rewards?.unlocks ?? []) {
    if (playerUnlocks.contains(unlock))
      continue
    let tooltip = $"{loc($"stats/{unlock}")}\n\n{loc($"stats/{unlock}/desc")}"
    let tooltipedIcon = mkTooltiped({
      rendObj = ROBJ_BOX
      fillColor = Color(100, 100, 20, 20)
      children = mkItemChildren("contract_reward_unlock", itemIconSize)
    }, tooltip)

    rewards.append({
      rendObj = ROBJ_SOLID
      color = ItemBgColor
      valign = ALIGN_CENTER
      size = iconSize
      children = tooltipedIcon
    })
  }

  let rewardsLines = []
  let linesCount = ceil(rewards.len() / num_in_row) + 1
  for (local i = 0; i < linesCount; i++){
    rewardsLines.append({
      flow = FLOW_HORIZONTAL
      gap = hdpx(3)
      valign = ALIGN_CENTER
      halign = ALIGN_LEFT
      size = const [ flex(), SIZE_TO_CONTENT ]
      children = rewards.slice(i * num_in_row, (i + 1) * num_in_row)
    })
  }

  return {
    size = const [ flex(), SIZE_TO_CONTENT ]
    flow = FLOW_VERTICAL
    valign = ALIGN_CENTER
    gap = hdpx(10)
    children = [rewardsTitle]
      .extend(rewardsLines)
  }
}
let monolithContractText = {contract_monolith_danger = loc("contract_monolith_danger")}

let mkContractBlock = @(idx, contract, isRaidAvailable, manyContractsPossible) @() {
  size = const [flex(), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  key = contract.id
  children = [
    mkContractHeader(contract, idx, isRaidAvailable, manyContractsPossible)
    @() {
      rendObj = ROBJ_SOLID
      watch = selectedContract
      color = BtnBgNormal
      size = const [flex(), SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      padding = hdpx(10)
      gap = hdpx(5)
      children = selectedContract.get() == idx ? [
        mkRewardBlock(contract, 4)
        const {size = [flex(), 1], rendObj = ROBJ_SOLID, opacity = 0.3}
        mkDescTextarea(getContractProgressionText(contract), const { color = InfoTextValueColor })
        const {size = [flex(), 1], rendObj = ROBJ_SOLID, opacity = 0.3}
        mkDescTextarea(loc($"contract/{contract.name}/desc", monolithContractText))
      ] : null
    }
  ]
}

function getContracts(zone, contracts=null, mItems = {}) {
  contracts = contracts ?? (isOnboarding.get() ? playerProfileOnboardingContracts.get() : playerProfileCurrentContracts.get())
  return (contracts)
    .filter(function(v){
      let raidName = (zone?.extraParams.raidName ?? "").split("+")
      let isStoryType = v.contractType == ContractType.STORY
      let sameRaidName = isStoryType ? v?.raidName == (raidName?[0] ?? "") : v?.raidName == zone?.extraParams.raidName
      let isMonsterType = v.contractType == ContractType.MONSTER
      let shouldBeReported = v.currentValue >= v.requireValue && !v.isReported
      return sameRaidName && (!isMonsterType || shouldBeReported)
    })
    .topairs()
    .sort(function(a, b) {
      let reqA = a[1]?.requireParams.completeUnlocksRequire[0]
      let reqB = b[1]?.requireParams.completeUnlocksRequire[0]
      let reqLvlA = ((mItems.findvalue(@(v) (v?.children.unlocks ?? []).contains(reqA)) ?? [])?.requirements.monolithAccessLevel ?? -1)
      let reqLvlB = ((mItems.findvalue(@(v) (v?.children.unlocks ?? []).contains(reqB)) ?? [])?.requirements.monolithAccessLevel ?? -1)
      return (a[1].contractType) <=> (b[1].contractType)
        || reqLvlA <=> reqLvlB
        || a[1].difficulty <=> b[1].difficulty
        || a[0] <=> b[0]
    })
}

let mkContractsBlock = function() {
  let matchingUTCTime = Watched(0)
  gui_scene.setInterval(1, @() matchingUTCTime.set(get_matching_utc_time()))
  let isRaidAvailable = Computed(@() isZoneUnlocked(selectedRaid.get(), playerStats.get(), matchingUTCTime))

  return function () {
    let contractsList = getContracts(selectedRaid.get(), isOnboarding.get()
      ? playerProfileOnboardingContracts.get() : playerProfileCurrentContracts.get(), marketItems.get())
    let manyContractsPossible = contractsList.map(@(v) v[1]).filter(@(v) v.contractType==0).len()>1
    return {
      watch = const [isOnboarding, playerProfileCurrentContracts, selectedRaid, marketItems]
      size = const [flex(), SIZE_TO_CONTENT]
      gap = hdpx(2)
      flow = FLOW_VERTICAL
      onAttach = @() selectedContract.set(0)
      children = contractsList
        .map(@(v, i) mkContractBlock(i, v[1].__merge({id=v[0]}), isRaidAvailable, manyContractsPossible))
    }
  }
}

let contractsTitle = freeze({
  vplace = ALIGN_CENTER
  rendObj = ROBJ_TEXT
  size = [ flex() , SIZE_TO_CONTENT ]
  text = loc("contracts/title")
  fontFx = FFT_GLOW
  fontFxColor = Color(0, 0, 0, 255)
}.__update(body_txt))

let dailyContractUpdate = function() {
  let contractTimerUpdateTime = mkCountdownTimerPerSec(currentContractsUpdateTimeleft)
  contractTimerUpdateTime.subscribe(function(v) {
    if (v <= 0)
      eventbus_send("profile_server.update_daily_contracts")
  })
  if (contractTimerUpdateTime.get() <= 0)
    eventbus_send("profile_server.update_daily_contracts")
  return {
    watch = playerProfileCurrentContracts
    flow = FLOW_HORIZONTAL
    size = [ flex(), SIZE_TO_CONTENT ]
    behavior = Behaviors.Button
    skipDirPadNav = true
    onHover = @(on) setTooltip(on ? loc("contracts/dailyContractTimer") : null)
    children = playerProfileCurrentContracts.get().findvalue(function(v){ return !v.isStoryContract}) ? [
      mkText(loc("contracts/dailyContractUpdate"))
      @() {
        watch = contractTimerUpdateTime
        children = mkMonospaceTimeComp(contractTimerUpdateTime.get())
      }
    ] : null
  }
}

let contractsPanel = @() {
  size = flex()
  flow = FLOW_VERTICAL
  gap = hdpx(10)
  children = [
    @() {
      watch = selectedRaid
      size = const [flex(), SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      children = [
        contractsTitle
        dailyContractUpdate
      ]
    }
    makeVertScrollExt(mkContractsBlock(), {styling=overlappedStyle})
  ]
}

return {
  contractsTitle,
  contractsPanel,
  mkContractBlock,
  mkRewardBlock,
  selectedContract
  reportContract
  contractReportIsInProgress
}
