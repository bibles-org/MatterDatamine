from "%ui/fonts_style.nut" import h2_txt, giant_txt, body_txt
from "%ui/quickMatchQueue.nut" import leaveQueue, joinQueue
from "%ui/components/button.nut" import button, textButton, buttonWithGamepadHotkey
from "%ui/components/msgbox.nut" import showMsgbox, showMessageWithContent
from "%ui/components/colors.nut" import BtnBgDisabled, InfoTextValueColor, BtnBgHover
from "%ui/components/commonComponents.nut" import mkText, mkDescTextarea
from "%ui/squad/squadManager.nut" import leaveSquad
from "%ui/gameModeState.nut" import isGroupAvailable
from "%ui/matchingQueues.nut" import isQueueDisabledBySchedule
from "%ui/components/accentButton.style.nut" import accentButtonStyle
from "%ui/state/queueState.nut" import doesZoneFitRequirements
from "%ui/hud/hud_menus_state.nut" import openMenu
from "%ui/hud/state/item_info.nut" import getSlotAvailableMods
from "%ui/mainMenu/raid_preparation_window_state.nut" import closePreparationsScreens
from "dasevents" import CmdRequestOnboardingRaid, CmdHideAllUiMenus, CmdRequestOnboardingReportContract
from "%ui/state/matchingUtils.nut" import get_matching_utc_time
from "%ui/mainMenu/offline_raid_widget.nut" import wantOfflineRaid, isOfflineRaidAvailable
from "%ui/profile/profileState.nut" import playerStats, numOfflineRaidsAvailable, playerProfileCurrentContracts
from "%ui/mainMenu/monolith/monolith_common.nut" import MonolithMenuId
from "%ui/components/profileAnswerMsgBox.nut" import showMsgBoxResult
from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { isInQueue } = require("%ui/quickMatchQueue.nut")
let roomState = require("%ui/state/roomState.nut")
let { showCreateRoom } = require("%ui/mainMenu/customGames/showCreateRoom.nut")
let { isInSquad, isSquadLeader, squadSelfMember, allMembersState, selfUid } = require("%ui/squad/squadState.nut")
let { myExtSquadData } = require("%ui/squad/squadManager.nut")
let { selectedRaid, queueRaid, selectedNexusNode, showNexusFactions, selectedPlayerGameModeOption, GameMode } = require("%ui/gameModeState.nut")
let { matchingQueuesMap } = require("%ui/matchingQueues.nut")
let { joiningQueueName } = require("%ui/state/queueState.nut")
let { loadoutItems, stashVolume, stashMaxVolume } = require("%ui/state/allItems.nut")
let { isOnboarding, onboardingStateMachineCurrentStateEid, onboardingStateMachineBaseFirstTimeStateEid
      playerProfileOnboardingContracts, onboardingContractReported } = require("%ui/hud/state/onboarding_state.nut")
let { weaponsList } = require("%ui/hud/state/hero_weapons.nut")
let { useAgencyPreset } = require("%ui/equipPresets/presetsState.nut")


let skip_descr = {description = {skip=true}}

let defQuickMatchBtnParams = {
  size = static [flex(), hdpx(70)]
  halign = ALIGN_CENTER
  sound = { click = "ui_sounds/button_raid" }
  textParams = { rendObj=ROBJ_TEXT}.__update(h2_txt)
}

let stdQuickMatchBtnParams = {sound = { click = "ui_sounds/button_raid" }}
  .__merge(accentButtonStyle, defQuickMatchBtnParams)
let disabledQuickMatchBtnParams = {}.__merge(defQuickMatchBtnParams, { style = { BtnBgNormal = BtnBgDisabled }, sound = { click = "ui_sounds/button_click_inactive" } })
let quickMatchBtnParams = stdQuickMatchBtnParams.__merge({hotkeys = [ ["^J:Y", skip_descr] ]})
let leaveBtnParams = defQuickMatchBtnParams.__merge({ sound = { click = "ui_sounds/button_leave_queue"} })

function quickMatchFn() {
  if (selectedRaid.get() == null) {
    showMsgbox({ text = loc("zoneNotSelected") })
    return
  }
  if (wantOfflineRaid.get() && !isOfflineRaidAvailable.get()) {
    showMsgbox({ text = loc("queue/offline_raids/noTickets") })
    return
  }
  let q = selectedRaid.get()
  let isDisabled = doesZoneFitRequirements(q?.extraParams.requiresToSelect, playerStats.get())
    && (q?.enabled == null || !q.enabled || isQueueDisabledBySchedule(q, get_matching_utc_time()))
  if (isDisabled) {
    showMsgbox({ text = loc("missions/unavailable") })
    closePreparationsScreens()
    return
  }
  if (roomState.room.get())
    roomState.leaveRoom(@(...) null)

  showCreateRoom.set(false)
  queueRaid.set(selectedRaid.get())

  joinQueue(queueRaid.get())
}

let mkAbortText = @(mainText) @() {
  watch = [matchingQueuesMap, joiningQueueName]
  flow = FLOW_VERTICAL
  valign = ALIGN_CENTER
  halign = ALIGN_CENTER
  children = [
    {
      rendObj = ROBJ_TEXT
      text = mainText
    }.__update(h2_txt)
    joiningQueueName.get() ? {
      rendObj = ROBJ_TEXT
      text = loc(matchingQueuesMap.get()[joiningQueueName.get()].locId)
    } : null
  ]
}

let leaveQuickMatchButton = button(mkAbortText(loc("startButton/leaveQueue")),
  @() leaveQueue(), leaveBtnParams)

let setNotReadyButton = @(additionalFields) button(
  {
    flow = FLOW_VERTICAL
    hplace = ALIGN_CENTER
    halign = ALIGN_CENTER
    children = [
      mkAbortText(loc("startButton/setNotReady"))
      additionalFields
    ]
  },
  function() {
    myExtSquadData.ready.set(false)
    if (isInQueue.get())
      leaveQueue()
  },
  disabledQuickMatchBtnParams
)

function isMagazineInLoadoutWithAmmo(magName) {
  return loadoutItems.get().findindex(@(v) v.templateName == magName && (v?.charges ?? 0) > 0) != null
}

function checkWeaponAmmo(weapon, templateName) {
  let gunMods = weapon?.getCompValNullable("gun_mods__slots").getAll() ?? {}
  let magazineSlotTemplateName = gunMods?.magazine
  if (!magazineSlotTemplateName) {
    let weapons = weaponsList.get()
    let weaponToCheck = weapons.findvalue(@(v) v?.itemTemplate == templateName)
    return (weaponToCheck?.curAmmo ?? 0) > 0
  }

  let magazines = getSlotAvailableMods(magazineSlotTemplateName)
  let hasAmmo = magazines.findindex(@(v) isMagazineInLoadoutWithAmmo(v)) != null
  return hasAmmo
}

let weaponSlots = [ "weapon_0", "weapon_1", "weapon_2" ]

function checkLoadout() {
  let weapWithoutAmmo = []
  local hasWeapon = false
  foreach (item in loadoutItems.get()) {
    let isWeapon = weaponSlots.findvalue(@(v) item?.slotName == v ) != null
    if(!isWeapon)
      continue

    hasWeapon = true
    let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(item.templateName)
    if(!checkWeaponAmmo(template, item.templateName)) {
      let locname = template?.getCompValNullable("item__name") ?? "unknown"
      weapWithoutAmmo.append(locname)
    }
  }
  return { weapWithoutAmmo, hasWeapon }
}

function checkSafepack() {
  if (stashVolume.get() < stashMaxVolume.get())
    return true
  return loadoutItems.get().findvalue(@(item) item?.slotName == "equipment_safepack") == null 
}

let mkCheckEquipmentStateHandler = @(callback) function () {
  let isNexus = selectedRaid.get()?.extraParams.nexus
  if (isNexus){
    callback()
    return
  }
  let { weapWithoutAmmo, hasWeapon } = checkLoadout()

  let noAmmoMsg = {
    flow = FLOW_VERTICAL
    children = [mkText(loc("startButton/warning/noWeaponAmmo"), h2_txt)].extend(weapWithoutAmmo.map(@(v) {
      flow = FLOW_HORIZONTAL
      hplace = ALIGN_CENTER
      gap = hdpx(5)
      children = mkText(loc(v))
    }))
  }
  let noWeaponsMsg = mkText(loc("startButton/warning/noWeapons"), {color = InfoTextValueColor}.__update(h2_txt))
  let warningMsg = mkText(loc("startButton/warning/warningHeader"), giant_txt)
  let proceed = mkText(loc("startButton/warning/areYouSure"), h2_txt)

  let warningContent = {
    flow = FLOW_VERTICAL
    gap = hdpx(20)
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = [
      warningMsg
      hasWeapon ? null : noWeaponsMsg
      weapWithoutAmmo.len() > 0 ? noAmmoMsg : null
      proceed
    ]
  }

  let isOk = ((weapWithoutAmmo.len() == 0) && hasWeapon) || useAgencyPreset.get()

  if (!isOk)
    showMsgbox({
      buttons = [
        { text = loc("Yes"), isCurrent = true, action = function() { callback() } }
        { text = loc("No"), isCancel = true }
      ]
      children = warningContent
    })
  else
    callback()
}

let setCannotTakeSafepackMsg = @() showMsgbox({
  buttons = [
    { text = loc("mainmenu/btnBack"), isCancel = true }
  ]
  children = mkText(loc("startButton/cannotTakeSafepack/msg"), h2_txt)
})

let setCannotTakeSafepackBtn = textButton(loc("startButton/cannotTakeSafepack"),
  setCannotTakeSafepackMsg, disabledQuickMatchBtnParams)

let mkJoinQuickMatchButton = @(additionalFields)
  buttonWithGamepadHotkey({
    flow = FLOW_VERTICAL
    hplace = ALIGN_CENTER
    halign = ALIGN_CENTER
    children = [
      mkText(loc("missionStart"), h2_txt)
      additionalFields
    ]
  },
    mkCheckEquipmentStateHandler(@() quickMatchFn()), quickMatchBtnParams)


let nexusFittingQueues = Computed(function() {
  let raidName = playerProfileCurrentContracts.get().findvalue(
    @(v) selectedNexusNode.get() != null && v?.params.nodeId[0] == selectedNexusNode.get()
  )?.raidName

  if (raidName == null)
    return {}

  let qs = matchingQueuesMap.get().filter(function(q) {
    let isFitting = q?.extraParams.raidName.startswith(raidName)
    let isDisabled = doesZoneFitRequirements(q?.extraParams.requiresToSelect, playerStats.get())
      && (q?.enabled == null || !q.enabled || isQueueDisabledBySchedule(q, get_matching_utc_time()))
    return isFitting && !isDisabled
  })
  return qs
})


function joinNexusFittingQueues() {
  if (!showNexusFactions.get()) {
    quickMatchFn()
    return
  }

  if (nexusFittingQueues.get().len() == 0) {
    showMsgbox({ text = loc("nexus/noNexusFittingQueues") })
    return
  }

  foreach (queue in nexusFittingQueues.get()) {
    joinQueue(queue, { waitingInfoLocId = queue.extraParams.raidName.split("+")[1] })
  }
}


let mkJoinNexusMatchButton = buttonWithGamepadHotkey(mkText(loc("missionStart"), { hplace = ALIGN_CENTER }.__merge(h2_txt)),
  joinNexusFittingQueues, quickMatchBtnParams)

let quickMatchButton = @(additionalFields) @() {
  watch = [isInQueue, loadoutItems, stashVolume, stashMaxVolume]
  size = FLEX_H
  children = isInQueue.get()
              ? leaveQuickMatchButton
              : !checkSafepack()
                ? setCannotTakeSafepackBtn
                : selectedPlayerGameModeOption.get() == GameMode.Nexus
                  ? mkJoinNexusMatchButton
                  : mkJoinQuickMatchButton(additionalFields)
}

let pressWhenReadyBtn = @(additionalFields) buttonWithGamepadHotkey(
  {
    flow = FLOW_VERTICAL
    gap = hdpx(4)
    halign = ALIGN_CENTER
    hplace = ALIGN_CENTER
    children = [
      mkText(loc("startButton/pressWhenReady"), { hplace = ALIGN_CENTER }.__merge(h2_txt))
      additionalFields
    ]
  }
  function() {
    if (isInSquad.get() && !isSquadLeader.get() && wantOfflineRaid.get() && numOfflineRaidsAvailable.get() <= 0) {
      showMsgbox({ text = loc("queue/offline_raids/noTickets") })
      return
    }
    mkCheckEquipmentStateHandler(@() myExtSquadData.ready.set(true))()
  },
  quickMatchBtnParams)

let setNotAllReadyBtn = textButton(loc("startButton/notWholeSquadIsReady"),
  @() null,
  disabledQuickMatchBtnParams)

let setNotPossibleBtn = textButton(loc("startButton/raidIsNotAvailableInSquad"),
  @() showMsgbox(
    { text = loc("squad/leaveSquadQst"),
      buttons = [
        { text = loc("tooltips/disbandSquad"), action = @() leaveSquad() }
        { text = loc("mainmenu/btnBack"), isCancel = true }
      ]
    }),
  disabledQuickMatchBtnParams)

let squadQuickMatchButton = @(additionalFields) function() {
  local myUid = selfUid.get()
  local btn = quickMatchButton(additionalFields)
  if (!checkSafepack())
    btn = setCannotTakeSafepackBtn
  else if (isSquadLeader.get() && !isGroupAvailable())
    btn = setNotPossibleBtn
  else if (isSquadLeader.get() && allMembersState.get().len() > 1
    && !allMembersState.get().reduce(@(acc, v, k) acc && (k != myUid ? (v?.ready ?? false) : true), true)
  )
    btn = setNotAllReadyBtn
  else if (!isSquadLeader.get() && squadSelfMember.get() != null)
    btn = myExtSquadData.ready.get() ? setNotReadyButton(additionalFields) : pressWhenReadyBtn(additionalFields)
  return {
    watch = [isSquadLeader, squadSelfMember, myExtSquadData.ready, allMembersState, loadoutItems, stashVolume, stashMaxVolume]
    size = FLEX_H
    children = btn
  }
}

let startButton = @(additionalFields = null) @() {
  watch = isInSquad
  size = FLEX_H
  children = isInSquad.get() ? squadQuickMatchButton(additionalFields) : quickMatchButton(additionalFields)
}

let consoleRaidAdditionalButton = @(additionalFields = null) function() {
  if (!isInSquad.get() && !isInQueue.get() && checkSafepack())
    return { watch = [isInSquad, isInQueue, loadoutItems, stashVolume, stashMaxVolume] }

  let myUid = selfUid.get()
  local btn = null
  if (!checkSafepack())
    btn = setCannotTakeSafepackBtn
  if (isInQueue.get())
    btn = leaveQuickMatchButton
  if (isSquadLeader.get() && !isGroupAvailable())
    btn = setNotPossibleBtn
  else if (isSquadLeader.get() && allMembersState.get().len() > 1 && !allMembersState.get()
    .reduce(@(acc, v, k) acc && (k != myUid ? (v?.ready ?? false) : true), true)
  )
    btn = setNotAllReadyBtn
  else if (!isSquadLeader.get() && squadSelfMember.get() != null)
    btn = myExtSquadData.ready.get() ? setNotReadyButton(additionalFields) : null
  return {
    watch = [isInQueue, isSquadLeader, allMembersState, selfUid]
    size = FLEX_H
    children = btn
  }
}

let onboardingRaidStartButton = buttonWithGamepadHotkey(mkText(loc("missionStart"), { hplace = ALIGN_CENTER }.__merge(h2_txt)),
  function() {
    ecs.g_entity_mgr.broadcastEvent(CmdRequestOnboardingRaid())
    ecs.g_entity_mgr.broadcastEvent(CmdHideAllUiMenus())
  }, quickMatchBtnParams)

let onboardingFinishButton = buttonWithGamepadHotkey(mkText(loc("contract/report"), { hplace = ALIGN_CENTER }.__merge(h2_txt)),
  function() {
    foreach (_, v in playerProfileOnboardingContracts.get()) {
      if (v?.onReport)
        v.onReport()
      let rewards = (v?.rewards?[0] ?? {}).map(@(rew) rew.x)
      showMsgBoxResult(loc("craft/resultReceived"), rewards)
    }
    ecs.g_entity_mgr.broadcastEvent(CmdRequestOnboardingReportContract())
  }, quickMatchBtnParams)

let onboardingLockedButton = textButton(loc("onboarding/accessDenied"),
  @() showMessageWithContent({
    content = {
      size = static [sw(80), SIZE_TO_CONTENT]
      halign = ALIGN_CENTER
      flow = FLOW_VERTICAL
      gap = static hdpx(20)
      children = [
        mkDescTextarea(loc("onboarding/raidRequiresMonolithLevel"), { halign = ALIGN_CENTER }.__merge(body_txt))
        {
          rendObj = ROBJ_IMAGE
          size = static [hdpx(600), hdpx(400)]
          imageValign = ALIGN_TOP
          imageHalign = ALIGN_CENTER
          keepAspect = KEEP_ASPECT_FILL
          image = Picture("ui/gate_portal_thumbnails/gate_to_monolith_activated.avif")
        }
      ]
    }
    buttons = [
      {
        text = loc("market/goToMonolith"),
        action = @() openMenu(MonolithMenuId)
        customStyle = accentButtonStyle
      }
      { text = loc("mainmenu/btnBack"), isCancel = true }
    ]
  }), disabledQuickMatchBtnParams.__merge({
    textParams = body_txt
    style = {}
    transform = {}
    animations = [{ prop = AnimProp.fillColor, from = BtnBgHover, to = BtnBgDisabled,
      duration = 1, play = true, loop = true, easing = CosineFull
    }]
  }))


function onboardingRaidButton() {
  if (!isOnboarding.get())
    return { watch = isOnboarding }
  return {
    watch = [isOnboarding, onboardingStateMachineCurrentStateEid, onboardingStateMachineBaseFirstTimeStateEid]
    size = FLEX_H
    children = onboardingStateMachineCurrentStateEid.get() == onboardingStateMachineBaseFirstTimeStateEid.get()
      ? onboardingRaidStartButton
      : (onboardingContractReported.get() ? onboardingLockedButton : onboardingFinishButton)
  }
}

return {
  startButton,
  consoleRaidAdditionalButton,
  onboardingRaidButton,
  quickMatchBtnParams,
  leaveBtnParams,
}
