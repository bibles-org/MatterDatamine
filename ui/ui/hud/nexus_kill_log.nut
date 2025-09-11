from "%ui/components/colors.nut" import RedWarningColor, TeammateColor
from "%ui/helpers/remap_nick.nut" import remap_others
from "%ui/components/commonComponents.nut" import mkText
from "dagor.random" import rnd_int
from "%ui/components/itemIconComponent.nut" import itemIconNoBorder
from "%ui/mainMenu/menus/options/player_interaction_option.nut" import isStreamerMode, playerRandName
from "dagor.time" import get_time_msec
from "%ui/hud/menus/components/fakeItem.nut" import mkFakeAttachments
from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { localPlayerTeam, localPlayerName } = require("%ui/hud/state/local_player.nut")
let { nexusModeTeamColors } = require("%ui/hud/state/nexus_mode_state.nut")

const MAX_ROWS_TO_SHOW = 5
const SHOW_TIME = 5.0
const UPDATE_DELTA = 1.1

let killLogState = Watched([])

let weaponIconSize = static [hdpxi(50), hdpxi(15)]
local timerSet = false

let nexus_players_killLog_query = ecs.SqQuery("nexus_players_loadout_info",
  {
    comps_ro = [
      ["team", ecs.TYPE_INT],
      ["name", ecs.TYPE_STRING]
    ]
  }
)

local update
update = function() {
  let ct = get_time_msec()
  let newKillLogs = killLogState.get().filter(@(k) k.ctime + k.ttl * 1000 >= ct)
  let len = newKillLogs.len()
  if (len != killLogState.get().len())
    killLogState.set(newKillLogs)
  if (len == 0) {
    gui_scene.clearTimer(update)
    timerSet = false
  }
}

function getKillLogDataByEid(eid) {
  local res = null
  nexus_players_killLog_query.perform(eid, function(_eid, comp) {
    res = comp
  })
  return res
}

function makeFakeItemAttachments(templateName) {
  let templ = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(templateName)
  let magazineSlot = templ?.getCompValNullable("gun_mods__slots")?.magazine
  if (magazineSlot == null)
    return []
  let magazineSlotTempl = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(magazineSlot)
  let magazine = magazineSlotTempl?.getCompValNullable("slot_holder__availableItems")?.getAll()?[0]

  return magazine == null ? [] : mkFakeAttachments([magazine])
}

function mkWeaponIcon(templateName) {
  if (templateName == "")
    return null
  let icon = freeze(itemIconNoBorder(templateName,
    static {
      width = static weaponIconSize[0]
      height = static weaponIconSize[1]
      shading = "silhouette"
      vplace = ALIGN_CENTER
      itemYaw = -90
    }, makeFakeItemAttachments(templateName)))
  return {
    children = icon
  }
}

function getKillLogData(data) {
  let { killerEid, victimEid, weapon, killerName = null, victimName = null,
    victimTeam = null, killerTeam = null } = data
  if (victimEid == ecs.INVALID_ENTITY_ID)
    return null
  let killerData = getKillLogDataByEid(killerEid)
  let victimData = getKillLogDataByEid(victimEid)
  if (victimData?.name != localPlayerName.get()
    && killerData?.name != localPlayerName.get()
    && (victimData?.team != localPlayerTeam.get() || victimData?.name == localPlayerName.get())
  )
    return null
  let killerNameToUse = isStreamerMode.get() && (killerName ?? killerData?.name) == localPlayerName.get()
    ? playerRandName.get() : killerName ?? killerData?.name
  let victimNameToUse = isStreamerMode.get() && (victimName ?? victimData.name) == localPlayerName.get()
    ? playerRandName.get() : victimName ?? victimData.name
  let killerColor = killerName == localPlayerName.get() ? TeammateColor[0]
    : ((killerTeam ?? killerData?.team) == localPlayerTeam.get()) ? null
    : RedWarningColor
  let victimColor = victimName == localPlayerName.get() ? TeammateColor[0]
    : ((victimTeam ?? victimData.team) == localPlayerTeam.get()) ? null
    : RedWarningColor
  return {
    killerNameToUse
    killerColor
    weapon
    victimNameToUse
    victimColor
    ttl = SHOW_TIME
    ctime = get_time_msec()
  }
}

let appearanceAnimtaions = static [
  { prop = AnimProp.translate, from = [-sw(10), 0], to = [0, 0], duration = 0.3, play = true, easing = InOutCubic }
]

function mkKillLogRow(data) {
  if (data == null)
    return null
  let { killerNameToUse, killerColor, weapon, victimNameToUse, victimColor } = data
  return @() {
    watch = nexusModeTeamColors
    rendObj = ROBJ_WORLD_BLUR_PANEL
    flow = FLOW_HORIZONTAL
    gap = static hdpx(6)
    padding = static [hdpx(2), hdpx(4)]
    transform = {}
    animations = appearanceAnimtaions
    valign = ALIGN_CENTER
    children = [
      killerNameToUse == null ? null
        : mkText(remap_others(killerNameToUse), { color = killerColor ?? nexusModeTeamColors.get()[1] })
      mkWeaponIcon(weapon)
      mkText(remap_others(victimNameToUse), { color = victimColor ?? nexusModeTeamColors.get()[1] })
    ]
  }
}

function pushPlayerKillLog(data) {
  let kLog = getKillLogData(data)
  if (kLog == null)
    return
  killLogState.mutate(function(kl) {
    if (kl.len() == 0 || kl.len() < MAX_ROWS_TO_SHOW)
      kl.append(kLog)
    else if (kl.len() >= MAX_ROWS_TO_SHOW)
      kl.remove(0)
  })
  if (!timerSet) {
    gui_scene.setInterval(UPDATE_DELTA, update)
    timerSet = true
  }
}

ecs.register_es("nexus_killLog_state_es", {
  [["onInit", "onChange"]] = function(_eid, comp) {
    pushPlayerKillLog({
      killerEid = comp.nexus_history__offender
      victimEid = comp.nexus_history__victim
      weapon = comp.nexus_history__weapon
    })
  },
  onDestroy = @(...) killLogState.set([])
},
{
  comps_rq = [
    ["nexus_history_kill", ecs.TYPE_TAG]
  ],
  comps_track = [
    ["nexus_history__offender", ecs.TYPE_EID, ecs.INVALID_ENTITY_ID],
    ["nexus_history__victim", ecs.TYPE_EID, ecs.INVALID_ENTITY_ID],
    ["nexus_history__weapon", ecs.TYPE_STRING]
  ]
})

let killLogUi = @() {
  watch = killLogState
  flow = FLOW_VERTICAL
  halign = ALIGN_RIGHT
  children = killLogState.get().map(mkKillLogRow)
}

function fakeLog() {
  let names = ["Bob", "Destributer3000", "John", "ParadoxInParadox"]
  let weapons = ["mp_443_gun", "scorpion_evo_3_gun", "hammer_weapon", "dp_12_gun"]
  let killerEid = rnd_int(1, names.len())
  let victimEid = rnd_int(1, names.len())
  pushPlayerKillLog({
    killerEid, victimEid, weapon = weapons[killerEid - 1], killerTeam = rnd_int(2, 3), victimTeam = rnd_int(2, 3),
    killerName = names[killerEid - 1], victimName = names[victimEid - 1] }
  )
}

console_register_command(fakeLog, "ui.killLog")

return {
  killLogState
  killLogUi
}