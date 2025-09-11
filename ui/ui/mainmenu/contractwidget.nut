from "%sqGlob/dasenums.nut" import ContractType
import "%ui/components/tooltipBox.nut" as tooltipBox
from "%ui/state/matchingUtils.nut" import get_matching_utc_time
from "%ui/state/queueState.nut" import isZoneUnlocked
from "%ui/hud/objectives/objective_components.nut" import getContractProgressionText
from "%ui/fonts_style.nut" import sub_txt, tiny_txt, body_txt, fontawesome
from "%ui/components/button.nut" import textButtonSmall, button
from "%ui/components/itemIconComponent.nut" import itemIconNoBorder
from "%ui/components/commonComponents.nut" import mkText, mkTooltiped, mkTimeComp, mkDescTextarea, BD_LEFT,
  getTextColorForSelectedPanelText, mkSelectPanelItem, mkTextArea
from "eventbus" import eventbus_subscribe_onehit, eventbus_send
from "%ui/components/scrollbar.nut" import makeVertScrollExt, overlappedStyle
from "%ui/mainMenu/craftIcons.nut" import getCraftResultItems, mkCraftResultsItems
from "%ui/mainMenu/currencyIcons.nut" import monolithTokensColor, monolithTokensTextIcon, creditsColor,
  creditsTextIcon, premiumColor, premiumCreditsTextIcon, chronotracesColor, chronotraceTextIcon
from "%ui/components/profileAnswerMsgBox.nut" import showMsgBoxResult
from "%ui/components/msgbox.nut" import showMessageWithContent, showMsgbox
from "%ui/helpers/timers.nut" import mkCountdownTimerPerSec
from "%ui/hud/menus/components/fakeItem.nut" import mkFakeItem, mkFakeAttachments
from "%ui/hud/menus/components/inventoryItemTooltip.nut" import buildInventoryItemTooltip
from "%ui/hud/menus/components/inventoryItemRarity.nut" import mkRarityIconByTemplateName
from "%ui/hud/menus/components/inventoryItem.nut" import inventoryItem
from "%ui/components/accentButton.style.nut" import accentButtonStyle, successButtonStyle, stopButtonStyle
import "%ui/components/faComp.nut" as faComp
import "%ui/components/colorize.nut" as colorize
from "%ui/hud/hud_menus_state.nut" import openMenu
from "%ui/components/cursors.nut" import setTooltip
from "%ui/options/mkOnlineSaveData.nut" import mkOnlineSaveData
from "%ui/faction_presentation.nut" import mkFactionIcon
from "%ui/popup/player_event_log.nut" import addPlayerLog, mkPlayerLog
from "%ui/hud/menus/components/inventoryItemImages.nut" import inventoryItemImage
from "%ui/hud/menus/components/inventoryStyle.nut" import itemHeight
from "%ui/mainMenu/clonesMenu/clonesMenuCommon.nut" import mkAlterIconParams
from "%ui/components/colors.nut" import BtnBgHover, BtnBgNormal, SelBgNormal, BtnBdSelected, BtnBgDisabled,
  BtnBgSelected, InfoTextDescColor, InfoTextValueColor, BtnTextNormal, RarityUncommon, RarityRare, RarityCommon,
  ItemBgColor, RedWarningColor, SelBdNormal, SelBdSelected, RarityEpic, BtnBdHover, BtnBdNormal, TextNormal,
  BtnBdDisabled
from "%ui/helpers/parseSceneBlk.nut" import get_raid_description
import "%ui/components/fontawesome.map.nut" as fa
from "math" import ceil
from "dagor.debug" import logerr
from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { playerProfileCurrentContracts, currentContractsUpdateTimeleft, playerStats, allCraftRecipes, marketItems, completedStoryContracts } = require("%ui/profile/profileState.nut")
let { selectedRaid, selectedNexusNode, selectedPlayerGameModeOption, GameMode } = require("%ui/gameModeState.nut")
let { isOnboarding, playerProfileOnboardingContracts } = require("%ui/hud/state/onboarding_state.nut")
let { LOOTBOX_SHOW_RESULT } = require("%ui/hud/menus/components/inventoryItemTypes.nut")
let { currentPrimaryContractIds, Missions_id } = require("%ui/mainMenu/raid_preparation_window_state.nut")
let { MonolithMenuId, monolithSelectedLevel, monolithSectionToReturn } = require("%ui/mainMenu/monolith/monolith_common.nut")
let { squadLeaderState, isInSquad, isSquadLeader } = require("%ui/squad/squadState.nut")

const PRIMARY_CONTRACT_ALARM = "primary_contract_alarm"

let primaryContractAlramShowSetting = mkOnlineSaveData(PRIMARY_CONTRACT_ALARM, @() true)
let primaryContractAlramWatch = primaryContractAlramShowSetting.watch
let primaryContractAlramSet = primaryContractAlramShowSetting.setValue

let difficultyStatus = Watched({})

let scrollHandler = ScrollHandler()
let suitIconParams = {
  width = hdpxi(70)
  height = hdpxi(70) / 2 * 3
  transform = {}
  animations = []
  slotSize = [hdpxi(76), hdpxi(76)]
}

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
let contractToFocus = Watched(-1)
let contractReportIsInProgress = Watched(false)

let contractBtnHeight = 26 

function showMsgBoxCraftResult(result, name = null) {
  let contractName = name ? $"{loc($"contract/{name}")}\n" : ""
  let header = $"{contractName}{loc("craft/resultReceived")}"
  showMsgBoxResult(header, result, contractName, @() contractReportIsInProgress.set(false))
}

let mkCounter = @(text) {
  rendObj = ROBJ_BOX
  borderRadius = static [0, 0, hdpx(5), 0]
  fillColor = Color(67, 67, 67)
  vplace = ALIGN_TOP
  hplace = ALIGN_LEFT
  padding = hdpx(3)
  children = mkText(text, static { fontSize = hdpx(17) })
}

function mkContractMark(contract, isPremium){
  let fontSize = hdpx(16)
  let tooltips = []
  let children = []
  let baseIconColor = isPremium ? premiumColor
    : contract.isReported ? InfoTextDescColor
    : Color(255, 255, 255)

  if (contract?.contractType == ContractType.PRIMARY) {
    children.append(faComp("star", { fontSize color = baseIconColor, margin = [hdpx(2), 0, 0, 0] }))
    tooltips.append(static ["star", loc("contracts/primaryContractTooltip")])
  }
  else if (contract?.contractType == ContractType.SECONDARY) {
    children.append(faComp("star-half-empty", { fontSize color = baseIconColor }))
    tooltips.append(static ["star-half-empty", loc("contracts/secondaryContractTooltip")])
  }
  else if (contract?.contractType == ContractType.MONSTER) {
    children.append(faComp("star-half-empty", {fontSize color = baseIconColor }))
    tooltips.append(static ["star-half-empty", loc("contracts/primaryContractTooltip")])
  }
  else if (contract?.contractType == ContractType.STORY || contract?.contractType == ContractType.ITEM) {
    children.append(faComp("book", {fontSize color = baseIconColor }))
    tooltips.append(static ["book", loc("contracts/storyContractTooltip", "Storyline")])
  }
  if (contract?.blockExtractionWhenIncomplete && !contract.isReported) {
    children.insert(1, static faComp("extraction_point.svg", { fontSize color = RedWarningColor, margin = [hdpx(2), 0, 0, 0]}))
    tooltips.insert(1, static ["extraction_point.svg", loc("contract/required"), RedWarningColor])
  }
  return mkTooltiped({
    flow = FLOW_HORIZONTAL
    gap = static hdpx(2)
    children
  }, tooltipBox({
    padding = hdpx(2) flow = FLOW_VERTICAL gap = hdpx(1)
    children = tooltips.map(@(v) {
      flow = FLOW_HORIZONTAL
      valign = ALIGN_CENTER
      gap = static hdpx(2)
      children = [
        faComp(v[0], {fontSize = sub_txt.fontSize, color = v?[2] ?? Color(255,255,255), margin = [hdpx(2), 0, 0, 0]})
        {
          rendObj = ROBJ_TEXTAREA
          behavior = Behaviors.TextArea
          valign = ALIGN_CENTER
          text = " - {0}".subst(v[1])
        }.__update(sub_txt)
      ]
    })
  }))
}

function reportContract(ids, protect_watch, name){
  eventbus_subscribe_onehit($"profile_server.completeContracts.result", function(diff) {
    showMsgBoxCraftResult(diff, name)

  })
  protect_watch.set(true)

  
  const profileAnswerBlockerResetTime = 3.0
  gui_scene.resetTimeout(profileAnswerBlockerResetTime, @() protect_watch.set(false), "completeContractsReset")

  eventbus_send("profile_server.completeContracts", ids)
}

let mkCheckIcon = @(btnHeight) faComp("check", {
  size = [SIZE_TO_CONTENT, btnHeight]
  fontSize = btnHeight
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  color = InfoTextDescColor
})

let mkContractName = function(contract, isReported, selected, isHover) {
  let namePrefix = contract?.namePrefix != null ? loc(contract?.namePrefix) : null
  let name = loc($"contract/{contract.name}")
  return {
    text = !namePrefix ? name : $"{namePrefix}: {name}"
    rendObj = ROBJ_TEXT
    behavior = Behaviors.Marquee
    scrollOnHover = true
    color = isReported ? InfoTextDescColor : getTextColorForSelectedPanelText(selected, isHover)
    size = FLEX_H
  }

}

let btnBack = static {size = flex() rendObj = ROBJ_SOLID margin = hdpx(1) color = Color(0,0,0,100)}
let iconBtnStyle = static { size = hdpxi(25) font = fontawesome.font fontSize = hdpxi(18) halign = ALIGN_CENTER valign = ALIGN_CENTER}

let getContractRaidArr = memoize(@(name) name.split("+"))
function isRightRaidNameArr(raid_name_arr, contract_raid_name_arr) {
  if (raid_name_arr.len() < contract_raid_name_arr.len())
    return false
  foreach (i, v in contract_raid_name_arr) {
    if (raid_name_arr[i] != v) {
      return false
    }
  }
  return true
}
let isRightRaidNameStr = memoize(@(raid_name, contract_raid_name) raid_name!="" && isRightRaidNameArr(getContractRaidArr(raid_name), getContractRaidArr(contract_raid_name)))
let isRightRaidName = function(name1, name2){
  if (name1==null || name2==null)
    return false
  if (type(name1) != "string" || type(name2) != "string"){
    log("raid_name:", name1, "contract_raid_name:", name2)
    logerr("Incorrect raid names")
    return false
  }
  return isRightRaidNameStr(name1, name2)
}

function getContracts(zone, contracts=null, mItems = {}) {
  contracts = contracts ?? (isOnboarding.get() ? playerProfileOnboardingContracts.get() : playerProfileCurrentContracts.get())
  return (contracts)
    .filter(function(v){
      let sameRaidName = isRightRaidName(zone?.extraParams.raidName, v?.raidName)
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

function getNexusContracts(contracts, mItems, nexusNode) {
  contracts = contracts ?? (isOnboarding.get() ? playerProfileOnboardingContracts.get() : playerProfileCurrentContracts.get())
  return (contracts)
    .filter(function(v) {
      let isMonsterType = v.contractType == ContractType.MONSTER
      let shouldBeReported = v.currentValue >= v.requireValue && !v.isReported
      let sameNexusNode = v?.params.nodeId[0] != null && v?.params.nodeId[0] == nexusNode
      return sameNexusNode && (!isMonsterType || shouldBeReported)
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


function anyCurrentRaidContractAlreadyAccepted() {
  let currentRaidContracts = getContracts(selectedRaid.get(), null, marketItems.get())
    .filter(@(contract) contract[1].contractType == ContractType.PRIMARY && contract[1].currentValue < contract[1].requireValue)
  local primaryContractsCounter = 0
  foreach (contract in currentRaidContracts)
    if (contract[0] in currentPrimaryContractIds.get() && primaryContractsCounter < 2)
      primaryContractsCounter++
  return primaryContractsCounter > 1
}


function mkGetPrimaryContractBtn(contract, currentPrimaries) {
  if (contract.id not in currentPrimaries) {
    return {
      children = [
        btnBack
        textButtonSmall(loc("contracts/take"), function(){
          if (primaryContractAlramWatch.get() && (contract?.blockExtractionWhenIncomplete ?? false))
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
    return textButtonSmall(loc("contracts/declineMonolith"), function() {
      if (!anyCurrentRaidContractAlreadyAccepted()) {
        showMsgbox({
          text = loc("contracts/cantDeclineLastContract")
        })
        return
      }
      currentPrimaryContractIds.mutate(@(v) v.$rawdelete(contract.id))
    }, {
      isEnabled = !contractReportIsInProgress.get()
      stopHover = true
      onHover = @(on) setTooltip(on ? loc("contracts/declineMonolith") : null)
      key = $"{contract}_decline"
    }.__update(stopButtonStyle))
  }
}

let disabledStyle = { style = { BtnBgNormal = BtnBgDisabled } }
function mkGetContractBtn(contract, isReported, currentValue, requireValue, btnHeight, multyRewardIdx = 0) {
  if (isReported)
    return mkCheckIcon(btnHeight)
  else if (currentValue >= requireValue)
    return {
      children = [
        btnBack
        textButtonSmall(loc("contracts/report"), function() {
            if ((contract?.rewards?? []).len() > 1 && multyRewardIdx < 0) {
              showMsgbox({ text = loc("contracts/rewards/multyRewardsNoSelection") })
              return
            }
            else if (contract?.onReport != null) {
              contract.onReport()
              return
            }
            reportContract({ [contract.id] = multyRewardIdx }, contractReportIsInProgress, contract.name)
          }, {
            isEnabled = !contractReportIsInProgress.get()
            maxHeight = iconBtnStyle?.size[1]
          }.__update(multyRewardIdx < 0 ? disabledStyle : successButtonStyle))
    ]
  }
  return { size = [pw(20), btnHeight] }
}

function mkChooseRewardBtn(isReported, currentValue, requireValue, btnHeight, idx) {
  if (isReported)
    return mkCheckIcon(btnHeight)
  else if (currentValue >= requireValue)
    return {
      children = [
        btnBack
        textButtonSmall(loc("contract/selectReward"),
          function() {
            selectedContract.set(idx)
            showMsgbox({ text = loc("contracts/rewards/chooseReward")})
          },
          {
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

  let unlocksNeeded = recs.filter(@(v) levelToFocus?.offerName != v )

  if (levelToFocus.len() <= 0 && unlocksNeeded.len() < 0)
    return { watch = marketItems }
  let { requirements = null, offerName = null } = levelToFocus
  return {
    watch = marketItems
    children = textButtonSmall(fa["lock"],
      function() {
        if (levelToFocus.len() > 0) {
          monolithSelectedLevel.set((requirements?.monolithAccessLevel ?? 0) + 1)
          monolithSectionToReturn.set(Missions_id)
          openMenu(MonolithMenuId)
        }
        else {
          showMsgbox({
            text = "\n".join(unlocksNeeded.map(@(v) loc($"requirement/{v}")))
          })
        }
      }, {
        stopHover = true
        style = static {TextNormal  = mul_color(BtnTextNormal, 0.5) }
        onHover = function(on) {
          if (on) {
            if (levelToFocus.len() > 0) {
              setTooltip(loc("monolith/canBeUnlockedOnLevel", { level = colorize(InfoTextValueColor, loc(offerName)) }))
            }
            else {
              setTooltip("\n".join(unlocksNeeded.map(@(v) loc($"requirement/{v}"))))
            }
          }
          else {
            setTooltip(null)
          }
        }
      }.__update(iconBtnStyle)
    )
  }
}

let premiumBg = @() {
  rendObj = ROBJ_SOLID
  size = flex()
  transform = {}
  opacity = 0.2
  color = premiumColor
  animations = [{prop = AnimProp.color, from = 0x00000000, to = premiumColor, duration = 3,
    play = true, loop = true, easing = CosineFull }]
}

function mkContractHeader(contract, idx, isRaidAvailable, manyContractsPossible){
  let { isReported, currentValue, requireValue, requireParams = {},
    rewards = [], contractType = null, premium = false } = contract
  let canReport = currentValue >= requireValue
  let isPremium = premium && contractType != ContractType.STORY
  let btnHeight = hdpx(contractBtnHeight)
  let isSelected = Computed(@() selectedContract.get() == idx)
  let contractRequirements = Computed(function() {
    let contractRecs = requireParams?.completeUnlocksRequire ?? []
    let playerUnlocks = playerStats.get()?.unlocks ?? []
    let neededRecs = contractRecs.filter(@(v) !playerUnlocks.contains(v))
    return neededRecs
  })
  let hasMultiRewards = rewards.len() > 1
  let stateFlags = Watched(0)
  return function() {
    let sf = stateFlags.get()
    let selected = isSelected.get()
    let isHover = sf & S_HOVER
    let needRecs = contractRequirements.get().len() > 0
    return {
      watch = [stateFlags, isSelected, contractRequirements, isRaidAvailable]
      size = FLEX_H
      children = [
        {
          size = FLEX_H
          rendObj = ROBJ_BOX
          fillColor = sf & S_HOVER ? BtnBgHover
            : selected ? BtnBgSelected
            : (needRecs || !isRaidAvailable.get()) ? BtnBgDisabled
            : SelBgNormal
          onElemState = @(s) stateFlags.set(s)
          borderColor = isPremium ? premiumColor
            : selected ? SelBdSelected
            : SelBdNormal
          borderWidth = selected ? static [hdpx(2), 0,0,0] : static [0,0,0, hdpx(2)]
          behavior = Behaviors.Button
          onClick = @() selectedContract.modify(@(v) v!=idx ? idx : null)
          xmbNode = XmbNode()
          flow = FLOW_HORIZONTAL
          padding = static [hdpx(5), hdpx(5), hdpx(5), hdpx(10)]
          gap = hdpx(10)
          valign = ALIGN_CENTER
          sound = static {
            hover = "ui_sounds/button_highlight"
            click  = "ui_sounds/button_click"
          }
          children = [
            mkContractMark(contract, isPremium)
            mkContractName(contract, isReported, selected, isHover)
            !canReport
              ? { size = [SIZE_TO_CONTENT, btnHeight] }
              : @() {
                  watch = contractReportIsInProgress
                  children = hasMultiRewards
                    ? mkChooseRewardBtn(isReported, currentValue, requireValue, btnHeight, idx)
                    : mkGetContractBtn(contract, isReported, currentValue, requireValue, btnHeight)
                }
            contract.contractType == ContractType.PRIMARY && !canReport
              ? needRecs
                ? mkMonolithBtn(contractRequirements.get())
                : isRaidAvailable.get() && manyContractsPossible ? @() {
                    watch = [contractReportIsInProgress, currentPrimaryContractIds]
                    children = mkGetPrimaryContractBtn(contract, currentPrimaryContractIds.get())
                  } : null
              : null
          ]
        }
        isPremium && !isReported && !selected ? premiumBg : null
      ]
    }
  }
}


function mkItemIcon(templateName, size, attachments = null) {
  attachments = attachments ?? []
  return itemIconNoBorder(templateName,
    { width=size?[0] ?? size, height=size?[1] ?? size, shading = "full" }, mkFakeAttachments(attachments) )
}
function mkItemChildren(templateName, itemIconSize, attachments=null){
  return [mkItemIcon(templateName, itemIconSize, attachments), mkRarityIconByTemplateName(templateName)]
}

function mkRewardBlock(contract, num_in_row) {
  let { isReported, currentValue, requireValue, contractType = null, premium = false } = contract
  let isPremium = premium && contractType != ContractType.STORY
  let iconSize = hdpx(76)
  let itemIconSize = iconSize
  let rewardIdx = Watched(-1)
  let titleText = isPremium ? loc("contracts/rewards/premiumRewardsTitle") : loc("contracts/rewards/rewardsTitle")
  let rewardsTitle = mkTooltiped(mkText(titleText, {
    color = isPremium ? premiumColor : TextNormal
  }), isPremium ? loc("contracts/rewards/premiumRewardsDesc") : null)

  let multyRewardsClaim = static {
    size = FLEX_H
    halign = ALIGN_LEFT
    children = mkTextArea(loc("contracts/rewards/multyRewardsClaim"))
  }

  let multyRewardsHeader = static {
    size = FLEX_H
    halign = ALIGN_LEFT
    children = mkTextArea(loc("contracts/rewards/multyRewardsHeader"))
  }

  let hasMultiRewards = contract.rewards.len() > 1
  let res = []
  foreach (reward in contract.rewards) {
    let rewards = []
    if ((reward?.premiumCurrency.y ?? 0) > 0) {
      rewards.append(
        mkTooltiped({
          rendObj = ROBJ_BOX
          size = iconSize
          fillColor = RarityEpic
          halign = ALIGN_CENTER
          valign = ALIGN_BOTTOM
          children = mkItemChildren("premium_credit_coins_pile", itemIconSize)
            .append(mkCounter($"{loc("ui/multiply")}{reward?.premiumCurrency.x}"))
        }, "{0} {1}\n\n{2}".subst(colorize(premiumColor, premiumCreditsTextIcon), loc("premiumCredits"), loc("premiumCredits/desc"))))
    }

    if ((reward?.monolithTokens.y ?? 0) > 0) {
      rewards.append(
        mkTooltiped({
          rendObj = ROBJ_BOX
          size = iconSize
          fillColor = RarityRare
          halign = ALIGN_CENTER
          valign = ALIGN_BOTTOM
          children = mkItemChildren("monolith_credit_coins_pile", itemIconSize)
            .append(mkCounter($"{loc("ui/multiply")}{reward?.monolithTokens.x}"))
        }, "{0} {1}\n\n{2}".subst(colorize(monolithTokensColor, monolithTokensTextIcon), loc("monolithTokens"), loc("monolithTokens/desc"))))
    }

    if ((reward?.currency.y ?? 0) > 0) {
      rewards.append(
        mkTooltiped({
          rendObj = ROBJ_BOX
          size = iconSize
          fillColor = RarityUncommon
          halign = ALIGN_CENTER
          valign = ALIGN_BOTTOM
          children = mkItemChildren("credit_coins_pile", itemIconSize)
            .append(mkCounter($"{loc("ui/multiply")}{reward?.currency.x}"))
        }, "{0} {1}\n\n{2}".subst(colorize(creditsColor, creditsTextIcon), loc("credits"), loc("currency/desc"))))
    }

    if ((reward?.chronotraces.y ?? 0) > 0) {
      rewards.append(
        mkTooltiped({
          rendObj = ROBJ_BOX
          size = iconSize
          fillColor = RarityCommon
          halign = ALIGN_CENTER
          valign = ALIGN_BOTTOM
          children = mkItemChildren("chronotrace_coins_pile", itemIconSize)
            .append(mkCounter($"{loc("ui/multiply")}{reward?.chronotraces.y}"))
        }, "{0} {1}\n\n{2}".subst(colorize(chronotracesColor, chronotraceTextIcon), loc("chronotraces"), loc("chronotraces/desc"))))
    }

    foreach(item in reward?.items ?? []) {
      let templateName = item.itemPrototypeName
      local attachmentsToUse = []
      local suitOverrideData = {}
      let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(templateName)
      let isAlter = template?.getCompValNullable("item__filterType") == "alters"
      if (isAlter) {
        let { attachments, alterIconParams } = mkAlterIconParams(templateName, template)
        attachmentsToUse = attachments
        suitOverrideData = alterIconParams.__merge({ iconScale = (alterIconParams?.iconScale ?? 1) * 0.7 })
      }
      let fakeItem = mkFakeItem(templateName, suitOverrideData, attachmentsToUse)
      let itemTooltip = buildInventoryItemTooltip(fakeItem)

      let tooltipedIcon = mkTooltiped({
        rendObj = ROBJ_BOX
        fillColor = Color(30, 30, 30, 20)
        children = isAlter
          ? inventoryItemImage(fakeItem, suitIconParams, { clipChildren = true })
          : mkItemChildren(templateName, itemIconSize)
      }, itemTooltip)

      let itemCount = item.count > 1 ? mkCounter($"{loc("ui/multiply")}{item.count}") : null

      rewards.append({
        rendObj = ROBJ_SOLID
        size = iconSize
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
    foreach(marketOffer in reward?.marketOffers ?? []) {
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
        size = iconSize
        color = ItemBgColor
        valign = ALIGN_CENTER
        children = [
          marketOffer.tooltipedIcon
          marketOffer.count > 1 ? mkCounter($"{loc("ui/multiply")}{marketOffer.count}") : null
        ]
      })
    }

    foreach(recipeId in reward?.craftRecipes ?? []) {
      let recipe = allCraftRecipes.get()?[recipeId]
      let recipeName = recipe?.name ?? ""
      let templateName = $"fuse_result_{recipeName}"
      let faked = mkFakeItem(templateName)
      let tooltip = buildInventoryItemTooltip(faked)
      let tooltipedIcon = mkTooltiped({
        rendObj = ROBJ_BOX
        fillColor = Color(30, 30, 30, 20)
        children = mkItemChildren(templateName, itemIconSize)
      }, tooltip)

      rewards.append({
        rendObj = ROBJ_SOLID
        size = iconSize
        color = ItemBgColor
        valign = ALIGN_BOTTOM
        halign = ALIGN_CENTER
        children = tooltipedIcon
      })
    }

    let lootboxes = reward?.lootboxes ?? []
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

    foreach(playerBaseUpgrade in reward?.playerBaseUpgrades ?? []) {
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
    foreach(unlock in reward?.unlocks ?? []) {
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
    if (reward?.nexusFactionPoint != null && reward?.nexusFactionPoint != "") {
      let faction = reward.nexusFactionPoint
      rewards.insert(0, {
        flow = FLOW_HORIZONTAL
        children = [
          {
            behavior = Behaviors.Button
            onHover = @(on) setTooltip(on ? loc("faction/rewardDesc",
              { faction = colorize(InfoTextValueColor, loc(faction)) }) : null)
            children = [
              mkFactionIcon(faction, [itemHeight, itemHeight])
              mkCounter($"{loc("ui/multiply")}1")
            ]
          }
          {
            rendObj = ROBJ_SOLID
            size = [hdpx(1), itemHeight]
            margin = [0, hdpx(20)]
            opacity = 0.3
          }
        ]
      })
    }
    let linesCount = ceil(rewards.len() / num_in_row) + 1
    let lines = []
    for (local i = 0; i < linesCount; i++){
      lines.append({
        flow = FLOW_HORIZONTAL
        gap = hdpx(3)
        valign = ALIGN_CENTER
        halign = ALIGN_LEFT
        size = FLEX_H
        children = rewards.slice(i * num_in_row, (i + 1) * num_in_row)
      })
    }
    if (hasMultiRewards) {
      res.append(mkSelectPanelItem({
        idx = res.len()
        state = rewardIdx
        border_align = BD_LEFT
        visual_params = {
          size = FLEX_H
          padding = [0,0,0, hdpx(4)]
        }
        children = {
          flow = FLOW_VERTICAL
          children = lines
        }
      }))
    }
    else
      res.extend(lines)
  }

  return {
    size = FLEX_H
    flow = FLOW_VERTICAL
    valign = ALIGN_CENTER
    gap = hdpx(10)
    children = [!hasMultiRewards
                  ? rewardsTitle
                  : currentValue >= requireValue
                    ? multyRewardsClaim
                    : multyRewardsHeader]
      .extend(res)
      .append(!hasMultiRewards ? null : @() {
        watch = rewardIdx
        hplace = ALIGN_RIGHT
        children = mkGetContractBtn(contract, isReported, currentValue, requireValue, contractBtnHeight, rewardIdx.get())
      })
  }
}
let monolithContractText = {contract_monolith_danger = loc("contract_monolith_danger")}

let mkContractBlock = @(idx, contract, isRaidAvailable, manyContractsPossible) function() {
  let selectedReward = Watched(0)
  let buttons = []
  if (contract.rewards.len() > 1) {
    for (local i = 0; i < contract.rewards.len(); i++) {
      let num = i 
      buttons.append(button({
          size = [ hdpx(30), hdpx(30) ]
          halign = ALIGN_CENTER
          valign = ALIGN_CENTER
          children = mkText(i+1)
        },
        function() {
          selectedReward.set(num)
        },
        {}
      ))
    }
  }
  return {
    size = FLEX_H
    flow = FLOW_VERTICAL
    key = contract.id
    children = [
      mkContractHeader(contract, idx, isRaidAvailable, manyContractsPossible)
      @() {
        watch = selectedContract
        rendObj = ROBJ_SOLID
        color = BtnBgNormal
        size = FLEX_H
        flow = FLOW_VERTICAL
        padding = hdpx(10)
        gap = hdpx(5)
        eventPassThrough = true
        children = selectedContract.get() == idx ? [
          mkRewardBlock(contract, sw(100) / sh(100) >= 1.7 ? 5 : 4)
          static {size = static [flex(), 1], rendObj = ROBJ_SOLID, opacity = 0.3}
          mkDescTextarea(getContractProgressionText(contract), static { color = InfoTextValueColor })
          static {size = static [flex(), 1], rendObj = ROBJ_SOLID, opacity = 0.3}
          mkDescTextarea(loc($"contract/{contract.name}/desc", monolithContractText))
        ] : null
      }
    ]
  }
}


function isContractAvailable(contract) {
  let recs = contract?[1].requireParams
  if (!recs?.len())
    return true

  let unlocksRequire = recs?.completeUnlocksRequire
  if (unlocksRequire) {
    let playerUnlocks = playerStats.get()?.unlocks ?? []

    foreach (req in unlocksRequire) {
      let idx = playerUnlocks.findindex(@(v) v == req)

      if (idx == null)
        return false
    }
  }
  let storyRequire = recs?.completeStoryContractsRequire
  if (storyRequire) {
    foreach (reqId in storyRequire) {
      let idx = (completedStoryContracts.get() ?? []).findindex(@(completed) completed.k == reqId)
      if (idx == null)
        return false
    }
  }

  return true
}

let questionSign = faComp("question-circle", { fontSize = hdpxi(20) })

let matchingUTCTime = Watched(0)
let updateTime = @() matchingUTCTime.set(get_matching_utc_time())
let mkContractsBlock = function() {
  updateTime()
  let isRaidAvailable = Computed(@() isZoneUnlocked(selectedRaid.get(), playerStats.get(), matchingUTCTime,
    isInSquad.get(), isSquadLeader.get(), squadLeaderState.get()?.leaderRaid.raidData))

  return function () {
    local contractsList = null

    if (selectedPlayerGameModeOption.get() == GameMode.Nexus) {
      contractsList = getNexusContracts(playerProfileCurrentContracts.get(), marketItems.get(), selectedNexusNode.get())
      let res = {}
      res[selectedNexusNode.get()] <- true
      currentPrimaryContractIds.set(res)
      
    } else {
      contractsList = getContracts(selectedRaid.get(), isOnboarding.get()
        ? playerProfileOnboardingContracts.get() : playerProfileCurrentContracts.get(), marketItems.get())
    }

    let manyContractsPossible = contractsList.map(@(v) v[1]).filter(@(v) v.contractType==0).len()>1

    let firstPossibleIdx = contractsList.findindex(@(v) isContractAvailable(v))
    if (firstPossibleIdx != null && isRaidAvailable.get() && !anyCurrentRaidContractAlreadyAccepted()) {
      currentPrimaryContractIds.mutate(@(v) v[contractsList[firstPossibleIdx][0]] <- true)
    }
    if (contractToFocus.get() < 0)
      selectedContract.set(firstPossibleIdx)
    else
      selectedContract.set(contractToFocus.get())

    let primaryContracts = []
    let secondaryContracts = []

    contractsList.each(function(data) {
      let cType = data?[1].contractType
      if (cType == ContractType.PRIMARY)
        primaryContracts.append(data)
      else
        secondaryContracts.append(data)
    })

    return {
      watch = [isOnboarding, isRaidAvailable, playerProfileCurrentContracts, selectedRaid, marketItems,
        contractToFocus, selectedNexusNode, selectedPlayerGameModeOption]
      size = FLEX_H
      gap = static hdpx(2)
      flow = FLOW_VERTICAL
      onAttach = function() {
        if (selectedContract.get() < 0 && contractsList.len() == 1)
          selectedContract.set(0)
        gui_scene.clearTimer(updateTime)
        gui_scene.setInterval(1, updateTime)
        if (contractToFocus.get() < 0)
          return
        scrollHandler.scrollToChildren(@(child) child?.key == contractsList?[contractToFocus.get()].id, 2, false, true)
      }
      onDetach = function() {
        gui_scene.clearTimer(updateTime)
        contractToFocus.set(-1)
      }
      children = [
        {
          size = FLEX_H
          flow = FLOW_VERTICAL
          gap = hdpx(2)
          children = [
            mkTooltiped({
              size = FLEX_H
              flow = FLOW_HORIZONTAL
              gap = hdpx(4)
              padding = static [0, hdpx(4), 0,0]
              margin = static [0, 0, hdpx(8), 0]
              children = [
                mkTextArea(loc("contracts/primaryList"), body_txt)
                questionSign
              ]
            }, selectedPlayerGameModeOption.get() == GameMode.Nexus ? loc("contracts/nexusPrimaryListDesc") : loc("contracts/primaryListDesc"),
              { size = FLEX_H })
          ].extend(primaryContracts.map(@(v, i) mkContractBlock(i, v[1].__merge({id=v[0],
              premium = v[1].rewards.reduce(@(res, val) res || (val?.premiumCurrency.x ?? 0) > 0, false)
            }), isRaidAvailable, manyContractsPossible)))
        }
        secondaryContracts.len() <= 0 ? null : {
          rendObj = ROBJ_SOLID
          size = static [flex(), hdpx(1)]
          opacity = 0.3
          margin = static [hdpx(8), 0, hdpx(4), 0]
        }
        secondaryContracts.len() <= 0 ? null : {
          size = FLEX_H
          flow = FLOW_VERTICAL
          gap = hdpx(2)
          children = [
            mkTooltiped({
              size = FLEX_H
              flow = FLOW_HORIZONTAL
              gap = hdpx(4)
              padding = static [0, hdpx(4), 0,0]
              margin = static [hdpx(4), 0, hdpx(8), 0]
              children = [
                mkTextArea(loc("contracts/secondaryList"), body_txt)
                questionSign
              ]
            }, selectedPlayerGameModeOption.get() == GameMode.Nexus ? loc("contracts/nexusSecondaryListDesc") : loc("contracts/secondaryListDesc"),
              { size = FLEX_H })
          ].extend(secondaryContracts.map(@(v, i) mkContractBlock(i, v[1].__merge({id=v[0],
              premium = v[1].rewards.reduce(@(res, val) res || (val?.premiumCurrency.x ?? 0) > 0, false)
            }), isRaidAvailable, manyContractsPossible)))
        }
      ]
    }
  }
}

let mkRaidInfoIcon = @(icon_name, icon_size, icon_color) mkTooltiped({
  rendObj = ROBJ_IMAGE
  size = icon_size
  color = icon_color
  image = Picture("!ui/skin#raid_info/{0}.svg:{1}:{1}:K".subst(icon_name, icon_size))
}, loc($"missionInfo/{icon_name}"))

let difficultyColors = static {
  dif_easy = Color(60, 200, 100, 160)
  dif_norm = Color(200, 200, 60, 160)
  dif_hard = Color(200, 60, 60, 160)
}

let skullIcon = {
  rendObj = ROBJ_IMAGE
  size = [hdpxi(20), hdpxi(20)]
  transform = {}
  animations = [
    { prop = AnimProp.translate, from = [sw(40), 0], to = [0, 0], duration = 0.4, play = true, easing = OutCubic }
    {
      prop = AnimProp.opacity, from = 1, to = 0.5, duration = 2, delay = 0.4, play = true, easing = CosineFull
    }
  ]
  color = difficultyColors.dif_hard
  image = Picture($"ui/skin#skull.svg:{hdpxi(20)}:{hdpxi(20)}:P")
}

let contractsTitle = freeze({
  vplace = ALIGN_CENTER
  rendObj = ROBJ_TEXT
  size = FLEX_H
  text = loc("contracts/title")
  fontFx = FFT_GLOW
  fontFxColor = Color(0, 0, 0, 255)
}.__update(body_txt))

function mkContractTimer() {
  let contractTimerUpdateTime = mkCountdownTimerPerSec(currentContractsUpdateTimeleft, "contractsTimer")
  return function() {
    if (contractTimerUpdateTime.get() <= 0)
      eventbus_send("profile_server.update_daily_contracts")
    return {
      watch = contractTimerUpdateTime
      children = mkTimeComp(contractTimerUpdateTime.get())
    }
  }
}

function mkDailyContractUpdate() {
  let hasContracts = Computed(@() playerProfileCurrentContracts.get().findvalue(@(v) v.dailyRestoring))
  return @() {
    watch = [hasContracts, currentContractsUpdateTimeleft]  
    size = FLEX_H
    flow = FLOW_HORIZONTAL
    behavior = Behaviors.Button
    skipDirPadNav = true
    onHover = @(on) setTooltip(on ? loc("contracts/dailyContractTimer") : null)
    children = !hasContracts.get() ? null : [
      mkText(loc("contracts/dailyContractUpdate"))
      mkContractTimer()
    ]
  }
}

function mkDifficultyBlock() {
  let primaryContractsCount = Computed(@() getContracts(selectedRaid.get(), playerProfileCurrentContracts.get(), marketItems.get())
    .reduce(function(res, data) {
      let contractId = data[0]
      if (contractId in currentPrimaryContractIds.get())
        res++
      return res
    }, 0))

  return function() {
    if (selectedPlayerGameModeOption.get() == GameMode.Nexus || isOnboarding.get())
      return { watch = [selectedPlayerGameModeOption, primaryContractsCount, isOnboarding] }
    let scene = selectedRaid.get()?.scenes[0].fileName
    let raid_description = get_raid_description(scene)
    let difficulty = raid_description?.difficulty ?? "unknown"
    let difData = [
      mkText(loc("contracts/difficulty"), body_txt)
      mkRaidInfoIcon(difficulty, hdpx(20), difficultyColors?[difficulty] ?? TextNormal)
    ]
    if (primaryContractsCount.get() > 0) {
      difData.append(mkText("+", body_txt))
      for (local i = 0; i < primaryContractsCount.get(); i++)
        difData.append(skullIcon)
    }

    return {
      watch = [difficultyStatus, selectedRaid, isOnboarding, primaryContractsCount, selectedPlayerGameModeOption]
      size = FLEX_H
      flow = FLOW_HORIZONTAL
      gap = hdpx(4)
      margin = static [hdpx(4), 0]
      valign = ALIGN_CENTER
      children = difData
    }
  }
}

let contractsPanel = @() {
  size = flex()
  flow = FLOW_VERTICAL
  gap = hdpx(4)
  xmbNode = XmbContainer({
    canFocus = false
    wrap = false
    scrollSpeed = 5.0
  })
  children = [
    @() {
      watch = selectedRaid
      size = FLEX_H
      flow = FLOW_VERTICAL
      children = [
        contractsTitle
        mkDailyContractUpdate()
        mkDifficultyBlock()
      ]
    }
    makeVertScrollExt(mkContractsBlock(), static {
      styling = overlappedStyle
      scrollHandler
    })
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
  getContracts
  isRightRaidName
  contractToFocus
  mkDifficultyBlock
}
