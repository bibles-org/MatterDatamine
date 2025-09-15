from "%dngscripts/sound_system.nut" import sound_play

from "%ui/components/colors.nut" import HudTipFillColor, ItemIconBlocked, InfoTextDescColor, InfoTextValueColor,
  ItemBgColor

from "%ui/fonts_style.nut" import body_txt, tiny_txt
from "%ui/components/commonComponents.nut" import mkTextArea, mkText
from "%ui/hud/menus/components/inventoryItemRarity.nut" import mkRarityCorner, getRarityColor
import "%ui/components/faComp.nut" as faComp
from "%ui/components/itemIconComponent.nut" import itemIconNoBorder
from "%ui/hud/menus/components/fakeItem.nut" import mkFakeAttachments

from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { safeAreaHorPadding } = require("%ui/options/safeArea.nut")

const MAX_LOGS_TO_SHOW = 5
const MAX_REWARDS_TO_SHOW = 2
const MAX_SPECIAL_REWARDS_TO_SHOW = 1
const LOG_DEFAULT_SOUND = "ui_sounds/new_log_message"

let playerLogs = []
let getPlayerLogs = @() clone playerLogs
let playerRewards = []
let getPlayerRewards = @() clone playerLogs
let playerSpecialRewards = []
let defPlayerLogWidth = hdpx(200)
let playerLogsGen = Watched(0)
let playerRewardsGen = Watched(0)
let playerSpecialRewardsGen = Watched(0)

let playerLogsColors = static {
  defaultLog = HudTipFillColor
  infoLog = ItemBgColor
  warningLog = Color(60, 0, 0, 100)
}

let defLogParams = freeze({
  id = ""
  content = ""
  showTime = 3.0
  size = [defPlayerLogWidth, SIZE_TO_CONTENT]
})

let defPlayerLogPos = [-safeAreaHorPadding.get() - fsh(1), -sh(50)]

let playerLogStyle = Watched({
  hplace = ALIGN_RIGHT
  vplace = ALIGN_BOTTOM
  halign = ALIGN_RIGHT
  pos = defPlayerLogPos
})

function removePlayerLog(id) {
  let idx = playerLogs.findindex(@(p) p.id == id)
  if (idx == null)
    return
  playerLogs.remove(idx)
  playerLogsGen.modify(@(v) v + 1)
}

function addPlayerLog(config) {
  let { id = null, idToIgnore = "" } = config
  if (id == null || playerLogs.findvalue(@(v) v?.idToIgnore == idToIgnore))
    return

  if (playerLogs.len() > MAX_LOGS_TO_SHOW)
    removePlayerLog(playerLogs[0].id)

  let playerLog = defLogParams.__merge(config)
  sound_play(LOG_DEFAULT_SOUND)
  let genIndex = $"{id}_{playerLogsGen.get()}"
  playerLog.visibleIdx <- Watched(-1)
  playerLog.visibleIdx.subscribe(function(_newVal) {
    playerLog.visibleIdx.unsubscribe(callee())
    gui_scene.setTimeout(playerLog.showTime, function() {
      gui_scene.clearTimer(genIndex)
      removePlayerLog(id)
    }, genIndex)
  })

  playerLogs.append(playerLog)
  playerLogsGen.modify(@(v) v + 1)
}

function playerLogBlock() {
  let children = []
  let logs = getPlayerLogs()
  foreach(idx, playerLog in logs) {
    let { id, visibleIdx, content } = playerLog
    let prevVisIdx = visibleIdx.get()
    let curVisIdx = logs.len() - idx
    if (prevVisIdx != curVisIdx) {
      let prefix = curVisIdx > prevVisIdx ? "playerLogMoveTop" : "playerLogMoveBottom"
      anim_start(prefix + id)
    }

    children.append({
      key = $"popup_{id}"
      transform = {}
      animations = [
        { prop = AnimProp.translate, from = static [sw(20), 0], to = static [0, 0], duration = 0.2, trigger = $"popupMoveTop{id}", play = true, easing=OutCubic }
        { prop = AnimProp.translate, from = static [0, -100], to = static [0, 0], duration = 0.2, trigger = $"popupMoveBottom{id}", easing=OutCubic }
      ]
      behavior = Behaviors.RecalcHandler
      onRecalcLayout = @(_initial) visibleIdx.set(curVisIdx)
      children = content
    })
  }

  return {
    watch = [playerLogsGen, playerLogStyle]
    flow = FLOW_VERTICAL
    gap = hdpx(4)
    halign = ALIGN_RIGHT
    children = children
  }.__update(playerLogStyle.get())
}

let exampleLog = {
  rendObj = ROBJ_WORLD_BLUR_PANEL
  size = static [hdpx(300), SIZE_TO_CONTENT]
  color = 0xAAAAAAAA
  fillColor = HudTipFillColor
  flow = FLOW_HORIZONTAL
  gap = hdpx(4)
  valign = ALIGN_CENTER
  children = [
    {
      rendObj = ROBJ_BOX
      size = hdpx(50)
      borderWidth = hdpx(2)
      fillColor = 0xAAAA00AA
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      children = mkText("Img")
    }
    mkTextArea("This is example of \n two lines log")
  ]
}

console_register_command(@() addPlayerLog({ content = exampleLog, id = "example" }), "playerLog.showExample")

function getMarketItemInfo(templateName, count = null) {
  let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(templateName)
  if (!template)
    return null

  return {
    name = template.getCompValNullable("item__name") ?? ""
    charges = count ?? template?.getCompValNullable("item__countPerStack") ?? 0
    rarity = template?.getCompValNullable("item__rarity") ?? "common"
  }
}


let marketIconSize = [hdpxi(80), hdpxi(40)]
let mkTitleFaIcon = @(icon) faComp(icon, { fontSize = tiny_txt.fontSize })

function mkPurchaseLogData(templateName, attachments = [], slotData = null, count = null) {
  let itemData = getMarketItemInfo(templateName, count)
  let { name = null, charges = 1, rarity = null } = itemData
  if (name == null)
    return null
  local rarityColor = null
  if (rarity != null)
    getRarityColor(rarity, templateName)
  local titleFaIcon = "shopping-cart"
  local titleText = loc("market/itemPurhcased")
  if (slotData != null && slotData != "stash" && slotData != "inventory") {
    titleFaIcon = "user"
    titleText = loc("market/itemPurhcasedEquipped")
  }

  let image = itemIconNoBorder(templateName,
    {
      width = marketIconSize[0]
      height = marketIconSize[1]
      silhouette = ItemIconBlocked
      shading = "full"
      vplace = ALIGN_CENTER
      margin = static [hdpx(4), 0, hdpx(4), hdpx(8)]
    }, mkFakeAttachments(attachments))

  return {
    titleFaIcon
    titleText
    bodyIcon = {
      children = [
        image
        charges <= 1 ? null : {
          rendObj = ROBJ_BOX
          fillColor = Color(67, 67, 67)
          borderRadius = [0, 0, hdpx(5), 0]
          children = mkText($"{loc("ui/multiply")}{charges}", { padding = hdpx(2) }.__update(tiny_txt))
        }
        rarity == null ? null : mkRarityCorner(rarityColor, {
          hplace = ALIGN_RIGHT
          vplace = ALIGN_BOTTOM
          pos = [0, hdpx(4)]
          size = hdpx(12)
        })
      ]
    }
    bodyText = loc(name)
  }
}


let mkPlayerLog = kwarg(function( titleFaIcon = null, titleText = null, bodyIcon = null,
  bodyText = null, logColor = playerLogsColors.defaultLog
) {
  if (bodyText == null)
    return null
  local titleBlock = [
    titleFaIcon == null ? null : mkTitleFaIcon(titleFaIcon)
    titleText == null ? null
      : mkText(titleText, { color = InfoTextDescColor })
  ]
  return {
    rendObj = ROBJ_WORLD_BLUR_PANEL
    minWidth = hdpx(300)
    fillColor = logColor
    valign = ALIGN_CENTER
    padding = static [0, hdpx(8)]
    children = [
      {
        flow = FLOW_HORIZONTAL
        gap = hdpx(6)
        transform = {}
        animations = [
          { prop = AnimProp.translate, from = [sw(20), 0], to = [0, 0], duration = 0.4, play = true, easing=OutCubic }
        ]
        children = [
          bodyIcon == null ? null : bodyIcon
          {
            vplace = ALIGN_CENTER
            flow = FLOW_VERTICAL
            valign = ALIGN_CENTER
            padding = static [hdpx(4), 0]
            children = [
              {
                flow = FLOW_HORIZONTAL
                gap = hdpx(4)
                valign = ALIGN_CENTER
                children = titleBlock
              }
              bodyText == null ? null : mkText(bodyText, {
                behavior = Behaviors.Marquee
                scrollOnHover = false
                color = InfoTextValueColor
              }.__update(body_txt))
            ]
          }
        ]
      }
    ]
  }
})



function removePlayerReward(id) {
  let idx = playerRewards.findindex(@(p) p.id == id)
  if (idx == null)
    return
  playerRewards.remove(idx)
  playerRewardsGen.modify(@(v) v + 1)
}

function removePlayerSpecialReward(id) {
  let idx = playerSpecialRewards.findindex(@(p) p.id == id)
  if (idx == null)
    return
  playerSpecialRewards.remove(idx)
  playerSpecialRewardsGen.modify(@(v) v + 1)
}

function addPlayerReward(config) {
  let { id = null } = config
  if (id == null || playerRewards.findvalue(@(v) v.id == id) != null)
    return

  if (playerRewards.len() > MAX_REWARDS_TO_SHOW)
    removePlayerReward(playerRewards[0].id)

  let playerReward = defLogParams.__merge(config)
  sound_play(LOG_DEFAULT_SOUND)
  let genIndex = $"{id}_{playerLogsGen.get()}"
  playerReward.visibleIdx <- Watched(-1)
  playerReward.visibleIdx.subscribe(function(_newVal) {
    playerReward.visibleIdx.unsubscribe(callee())
    gui_scene.setTimeout(playerReward.showTime,
      function() {
        gui_scene.clearTimer(genIndex)
        removePlayerReward(id)
      }, genIndex)
    })

  playerRewards.append(playerReward)
  playerRewardsGen.modify(@(v) v + 1)
}

function addSpecialPlayerReward(config) {
  let { id = null } = config
  if (id == null)
    return

  if (playerSpecialRewards.len() > MAX_SPECIAL_REWARDS_TO_SHOW)
    removePlayerSpecialReward(playerSpecialRewards[0].id)

  let playerSpecialReward = defLogParams.__merge(config)
  sound_play(LOG_DEFAULT_SOUND)
  playerSpecialReward.visibleIdx <- Watched(-1)
  playerSpecialReward.visibleIdx.subscribe(function(_newVal) {
    playerSpecialReward.visibleIdx.unsubscribe(callee())
    gui_scene.setInterval(playerSpecialReward.showTime,
      function() {
        gui_scene.clearTimer(callee())
        removePlayerSpecialReward(id)
      }, id)
    })

  playerSpecialRewards.append(playerSpecialReward)
  playerSpecialRewardsGen.modify(@(v) v + 1)
}

function playerRewardBlock() {
  local specialReward = null
  foreach(playerReward in playerSpecialRewards) {
    let { id, visibleIdx, content } = playerReward
    specialReward = {
      key = $"popup_{id}"
      transform = {}
      animations = [{ prop = AnimProp.translate, from = [sw(20), 0], to = [0, 0],
        duration = 0.2, play = true, easing = OutCubic }]
      behavior = Behaviors.RecalcHandler
      onRecalcLayout = @(_initial) visibleIdx.set(0)
      children = content
    }
  }

  let children = []
  let rewards = getPlayerRewards()
  foreach(idx, playerReward in playerRewards.reverse()) {
    let { id, visibleIdx, content } = playerReward
    let prevVisIdx = visibleIdx.get()
    let curVisIdx = rewards.len() - idx
    if (prevVisIdx != curVisIdx) {
      let prefix = prevVisIdx < curVisIdx ? "playerLogMoveTop" : "playerLogMoveBottom"
      anim_start(prefix + id)
    }

    children.append({
      rendObj = ROBJ_WORLD_BLUR_PANEL
      key = $"popup_{id}"
      transform = {}
      animations = [
        { prop = AnimProp.translate, from = [sw(20), 0], to = [0, 0], duration = 0.2, trigger = $"popupMoveTop{id}", play = true, easing=OutCubic }
        { prop = AnimProp.translate, from = [0, -100], to = [0, 0], duration = 0.2, trigger = $"popupMoveBottom{id}", easing=OutCubic }
      ]
      behavior = Behaviors.RecalcHandler
      onRecalcLayout = @(_initial) visibleIdx.set(curVisIdx)
      opacity = idx == 0 ? 1 : 1 - idx * 0.33
      children = content
    })
  }

  return {
    watch = [playerRewardsGen, playerSpecialRewardsGen]
    flow = FLOW_VERTICAL
    gap = hdpx(8)
    hplace = ALIGN_CENTER
    halign = ALIGN_CENTER
    vplace = ALIGN_CENTER
    pos = [0, sh(30)]
    children = [
      specialReward
      {
        size = static [SIZE_TO_CONTENT, hdpx(130)]
        flow = FLOW_VERTICAL
        gap = hdpx(4)
        halign = ALIGN_CENTER
        children = children
      }
    ]
  }
}

function mkPlayerRewardLog(config) {
  let { message } = config
  return {
    padding = static [hdpx(2), hdpx(8)]
    hplace = ALIGN_CENTER
    children = message
  }
}


return freeze({
  playerLogBlock
  addPlayerLog
  mkPlayerRewardLog
  mkPlayerLog
  removePlayerLog
  playerLogsColors
  mkPurchaseLogData
  playerLogStyle
  playerRewardBlock
  addPlayerReward
  addSpecialPlayerReward
  playerSpecialRewards
  marketIconSize
})