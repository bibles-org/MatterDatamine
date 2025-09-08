from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { h2_txt, giant_txt } = require("%ui/fonts_style.nut")
let {isInQueue, leaveQueue, joinQueue} = require("%ui/quickMatchQueue.nut")
let { button, textButton } = require("%ui/components/button.nut")
let roomState = require("%ui/state/roomState.nut")
let {showCreateRoom} = require("%ui/mainMenu/customGames/showCreateRoom.nut")
let { showMsgbox } = require("%ui/components/msgbox.nut")
let { isInSquad, isSquadLeader, squadSelfMember, allMembersState, selfUid } = require("%ui/squad/squadState.nut")
let { BtnBgDisabled, InfoTextValueColor }  = require("%ui/components/colors.nut")
let { mkText } = require("%ui/components/commonComponents.nut")
let { myExtSquadData, leaveSquad } = require("%ui/squad/squadManager.nut")
let { isGroupAvailable, selectedSpawn, selectedRaid,
      queueRaid } = require("%ui/gameModeState.nut")
let { matchingQueuesMap, isQueueDisabledBySchedule } = require("%ui/matchingQueues.nut")
let { accentButtonStyle } = require("%ui/components/accentButton.style.nut")
let { joiningQueueName, doesZoneFitRequirements } = require("%ui/state/queueState.nut")
let { getSlotAvailableMods } = require("%ui/hud/state/item_info.nut")
let { loadoutItems, stashVolume, stashMaxVolume } = require("%ui/state/allItems.nut")
let { playerStats } = require("%ui/profile/profileState.nut")
let { closePreparationsScreens } = require("%ui/mainMenu/raid_preparation_window_state.nut")
let { isOnboarding, onboardingStateMachineCurrentStateEid, onboardingStateMachineBaseFirstTimeStateEid
      playerProfileOnboardingContracts, onboardingContractReported } = require("%ui/hud/state/onboarding_state.nut")
let { CmdRequestOnboardingRaid, CmdHideAllUiMenus, CmdRequestOnboardingReportContract } = require("dasevents")
let { weaponsList } = require("%ui/hud/state/hero_weapons.nut")
let { get_matching_utc_time } = require("%ui/state/matchingUtils.nut")
let { useAgencyPreset } = require("%ui/equipPresets/presetsState.nut")


let skip_descr = {description = {skip=true}}

let defQuickMatchBtnParams = {
  size = [flex(), hdpx(70)]
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
  let q = selectedRaid.get()
  let isDisabled = doesZoneFitRequirements(q?.extraParams.requiresToSelect, playerStats.get())
    && (q?.enabled == null || !q.enabled || isQueueDisabledBySchedule(q, get_matching_utc_time()))
  if (isDisabled) {
    showMsgbox({ text = loc("raid/unavailable") })
    closePreparationsScreens()
    return
  }
  if (roomState.room.get())
    roomState.leaveRoom(@(...) null)

  showCreateRoom.update(false)
  queueRaid.set(selectedRaid.get())

  let selectedSpawns = selectedSpawn.get()?.mteams
  let mteams = selectedSpawns ?? [-1]

  joinQueue(queueRaid.get(), {mteams})
}

let mkAbortText = @(mainText) @() {
  watch = [matchingQueuesMap, joiningQueueName]
  size = flex()
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

let setNotReadyButton = button(mkAbortText(loc("startButton/setNotReady")),
  function() {
    myExtSquadData.ready(false)
    if (isInQueue.get())
      leaveQueue()
  },
  disabledQuickMatchBtnParams.__merge({ hotkeys = [ ["^J:B", skip_descr ] ] })
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
      children = mkText(loc(v), )
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
  setCannotTakeSafepackMsg,
  disabledQuickMatchBtnParams.__merge({ hotkeys = [ ["^J:B", skip_descr ] ] }))

let mkJoinQuickMatchButton = textButton(loc("raidStart"),
  mkCheckEquipmentStateHandler(@() quickMatchFn()), quickMatchBtnParams)

let quickMatchButton = @() {
  watch = [isInQueue, loadoutItems, stashVolume, stashMaxVolume]
  size = [flex(), SIZE_TO_CONTENT]
  children = isInQueue.get() ? leaveQuickMatchButton
           : checkSafepack() ? mkJoinQuickMatchButton : setCannotTakeSafepackBtn
}

let pressWhenReadyBtn = textButton(loc("startButton/pressWhenReady"),
  mkCheckEquipmentStateHandler(@() myExtSquadData.ready(true)),
  stdQuickMatchBtnParams.__merge({ hotkeys = [ ["^J:Y", skip_descr ] ] }))

let setNotAllReadyBtn = textButton(loc("startButton/notWholeSquadIsReady"),
  @() null,
  disabledQuickMatchBtnParams.__merge({ hotkeys = [ ["^J:B", skip_descr ] ] }))

let setNotPossibleBtn = textButton(loc("startButton/raidIsNotAvailableInSquad"),
  @() showMsgbox(
    { text = loc("squad/leaveSquadQst"),
      buttons = [
        { text = loc("tooltips/disbandSquad"), action = @() leaveSquad() }
        { text = loc("mainmenu/btnBack"), isCancel = true }
      ]
    }),
  disabledQuickMatchBtnParams.__merge({ hotkeys = [ ["^J:B", skip_descr ] ] }))

function squadQuickMatchButton() {
  local myUid = selfUid.get()
  local btn = quickMatchButton
  if (!checkSafepack())
    btn = setCannotTakeSafepackBtn
  else if (isSquadLeader.get() && !isGroupAvailable())
    btn = setNotPossibleBtn
  else if (isSquadLeader.get() && allMembersState.get().len() > 1
    && !allMembersState.get().reduce(@(acc, v, k) acc && (k != myUid ? (v?.ready ?? false) : true), true)
  )
    btn = setNotAllReadyBtn
  else if (!isSquadLeader.get() && squadSelfMember.get() != null)
    btn = myExtSquadData.ready.get() ? setNotReadyButton : pressWhenReadyBtn
  return {
    watch = [isSquadLeader, squadSelfMember, myExtSquadData.ready, allMembersState, loadoutItems, stashVolume, stashMaxVolume]
    size = [flex(), SIZE_TO_CONTENT]
    children = btn
  }
}

let startButton = @() {
  watch = isInSquad
  size = [flex(), SIZE_TO_CONTENT]
  children = isInSquad.get() ? squadQuickMatchButton : quickMatchButton
}

function consoleRaidAdditionalButton() {
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
    btn = myExtSquadData.ready.get() ? setNotReadyButton : null
  return {
    watch = [isInQueue, isSquadLeader, allMembersState, selfUid]
    size = [flex(), SIZE_TO_CONTENT]
    children = btn
  }
}

let onboardingRaidStartButton = textButton(loc("raidStart"),
  function() {
    ecs.g_entity_mgr.broadcastEvent(CmdRequestOnboardingRaid())
    ecs.g_entity_mgr.broadcastEvent(CmdHideAllUiMenus())
  }, quickMatchBtnParams)

let onboardingFinishButton = textButton(loc("contract/report"),
  function() {
    foreach (_, v in playerProfileOnboardingContracts.get()) {
      if (v?.onReport)
        v.onReport()
    }
    ecs.g_entity_mgr.broadcastEvent(CmdRequestOnboardingReportContract())
    ecs.g_entity_mgr.broadcastEvent(CmdHideAllUiMenus())
  }, quickMatchBtnParams)

let onboardingLockedButton = textButton(loc("closedDoor/accessDenied"),
  @() showMsgbox(
    {text=loc("monolith/itemRequiresMonolithLevel"),
    buttons = [
      { text = loc("mainmenu/btnBack"), isCancel = true }
    ]
  }), disabledQuickMatchBtnParams)


function onboardingRaidButton() {
  if (!isOnboarding.get())
    return { watch = isOnboarding }
  return {
    watch = [isOnboarding, onboardingStateMachineCurrentStateEid, onboardingStateMachineBaseFirstTimeStateEid]
    size = [flex(), SIZE_TO_CONTENT]
    children = onboardingStateMachineCurrentStateEid.get() == onboardingStateMachineBaseFirstTimeStateEid.get()
      ? onboardingRaidStartButton
      : (onboardingContractReported.get() ? onboardingLockedButton : onboardingFinishButton)
  }
}

return {
  startButton,
  consoleRaidAdditionalButton,
  mkCheckEquipmentStateHandler,
  onboardingRaidButton,
}
