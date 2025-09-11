from "%sqGlob/dasenums.nut" import NexusStatType
from "%dngscripts/sound_system.nut" import sound_play
from "%sqGlob/app_control.nut" import switch_to_menu_scene
from "%sqstd/math.nut" import getRomanNumeral
from "%sqstd/string.nut" import utf8ToUpper
from "%ui/mainMenu/stdPanel.nut" import screenSize
from "%ui/components/colors.nut" import BtnBgNormal, ItemBgColor, RedWarningColor, BtnBdNormal,
  InfoTextValueColor, TextHighlight, ConsoleFillColor, TextNormal
from "%ui/popup/player_event_log.nut" import addPlayerReward, mkPlayerRewardLog, addSpecialPlayerReward
from "%ui/fonts_style.nut" import body_txt, h2_txt, h1_txt, giant_txt, sub_txt
from "%ui/components/commonComponents.nut" import mkText, mkTabs, mkTextArea, mkTimeComp
from "%ui/components/cursors.nut" import setTooltip
import "%ui/components/tooltipBox.nut" as tooltipBox
from "%ui/mainMenu/stdPanel.nut" import wrapInStdPanel
from "%ui/helpers/remap_nick.nut" import remap_nick
from "dasevents" import EventNexusSimpleStatChanged, EventNexusKillStatChanged, EventNexusKillGroupStatChanged, EventNexusAssistStatChanged
from "dagor.time" import get_time_msec
import "%ui/components/colorize.nut" as colorize
import "%ui/components/faComp.nut" as faComp
from "%ui/components/modalWindows.nut" import addModalWindow, removeModalWindow
from "%ui/components/button.nut" import textButton, button
from "%ui/helpers/timers.nut" import mkCountdownTimerPerSec
from "%ui/components/scrollbar.nut" import makeVertScrollExt, thinAndReservedPaddingStyle
from "%ui/mainMenu/menus/options/player_interaction_option.nut" import isStreamerMode, playerRandName
from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { localPlayerTeam, localPlayerEid, localPlayerName } = require("%ui/hud/state/local_player.nut")
let { hudIsInteractive } = require("%ui/hud/state/interactive_state.nut")
let { isOnPlayerBase } = require("%ui/hud/state/gametype_state.nut")
let { nexusRoundModeRoundNumber, nexusRoundModeRoundsToWin, nexusRoundModeGameEndTimer } = require("%ui/hud/state/nexus_round_mode_state.nut")
let { nexusModeTeamColors, isNexusEndGameDebriefing, nexusGameWinner, nexusAllyTeam,  allyTeam, enemyTeam,
  nexusEnemyTeam } = require("%ui/hud/state/nexus_mode_state.nut")
let { currentMenuId } = require("%ui/hud/hud_menus_state.nut")
let { playerSpecialRewards } = require("%ui/popup/player_event_log.nut")
let { nexusRoundEndReasonMap } = require("%ui/hud/tips/nexus_round_mode_round_result.nut")
let { creditsTextIcon } = require("%ui/mainMenu/currencyIcons.nut")

let statWidth = hdpx(30)
let statIconSize = hdpxi(23)
let killIconSize = hdpxi(33)
let infoTitleHeight = hdpx(106)
const NEXUS_STATS_ID = "nexusStatsWnd"
const TOTAL_STATS_ID = "totalScore"
const END_GAME_DEBRIEFING_ID = "endGameDebriefing"
let nexusTabHeader = loc("nexus/nexusStatsWnd")
let nexusStatsWndTitle = loc("nexus/statsTitle")

let hoveredStatLine = Watched(null)
let playersStats = Watched({})
let playersRoundStats = Watched({})
let killRoundTypes = Watched({})
let statsToShow = Watched(TOTAL_STATS_ID)

function nexusPlayersEids(eid, comps, localTeam) {
  let playerData = {
    eid
    name = comps?.name
  }
  if (comps.team == localTeam)
    allyTeam.mutate(@(value) value[eid] <- playerData)
  else
    enemyTeam.mutate(@(value) value[eid] <- playerData)
}

let nexus_players_info_query = ecs.SqQuery("nexus_players_info",
  {
    comps_ro = [
      ["team", ecs.TYPE_INT],
      ["name", ecs.TYPE_STRING],
      ["possessed", ecs.TYPE_EID]
    ],
  }
)

let nexus_score_info_query = ecs.SqQuery("nexus_score_info",
  {
    comps_ro = [
      ["nexus_stats__scoresheet", ecs.TYPE_OBJECT]
    ]
  }
)

function getScoresTbl() {
  local res = {}
  nexus_score_info_query.perform(function(_eid, comps) {
    res = comps.nexus_stats__scoresheet.getAll()
  })
  return res.map(@(v) v.score)
}

let defKillTypes = {
  melee_kill = 0
  grenade_kill = 0
  headshot_kill = 0
  longshot_kill = 0
  double_kill = 0
  triple_kill = 0
  multiple_kill = 0
  round = 0
}

let defStats = {
  kill = 0
  team_kill = 0
  assist = 0
  death = 0
  beacon_capture = 0
  beacon_reset = 0
  round = 0
  score = 0
}.__update(defKillTypes)


let killTypesOrder = [
  {
    id = "kill"
    icon = "kill_icon"
    locId = "stats/kills"
  }
  {
    id = "melee_kill"
    icon = "melee_kill"
    locId = "stats/meleeKills"
    reasonLocId = "reason/meleeKill"
    reasonOrder = 1
    alertReason = NexusStatType.MELEE_KILL
  }
  {
    id = "grenade_kill"
    icon = "grenade_kill"
    locId = "stats/grenadeKills"
    reasonLocId = "reason/grenadeKill"
    reasonOrder = 2
    alertReason = NexusStatType.GRENADE_KILL
  }
  {
    id = "headshot_kill"
    icon = "headshot_kill"
    locId = "stats/headshotKills"
    reasonLocId = "reason/headshotKill"
    reasonOrder = 4
    alertReason = NexusStatType.HEADSHOT_KILL
  }
  {
    id = "longshot_kill"
    icon = "longshot_kill"
    locId = "stats/longshotKills"
    reasonLocId = "reason/longshotKill"
    reasonOrder = 3
    alertReason = NexusStatType.LONGSHOT_KILL
  }
  {
    id = "double_kill"
    icon = "double_kill"
    locId = "stats/doubleKills"
    reasonLocId = "reason/doubleKill"
    alertReason = "DOUBLE_KILL"
  }
  {
    id = "triple_kill"
    icon = "tripple_kill"
    locId = "stats/trippleKills"
    reasonLocId = "reason/trippleKill"
    alertReason = "TRIPLE_KILL"
  }
  {
    id = "multiple_kill"
    icon = "multy_kill"
    locId = "stats/multipleKills"
    reasonLocId = "reason/multipleKill"
    alertReason = "MULTIPLE_KILL"
  }
]

let scoreHitnsOrder = [
  {
    id = "kill"
    icon = "kill_icon"
    name = loc("stats/kills")
  }
  {
    id = "assist"
    icon = "assist_icon"
    name = loc("stats/assists")
  }
  {
    id = "hit"
    name = loc("stats/hits")
  }
  {
    id = "beacon_capture"
    icon = "portal_take"
    name = loc("stats/portals")
    alertReason = NexusStatType.BEACON_CAPTURE
  }
  {
    id = "beacon_reset"
    icon = "portal_retake"
    name = loc("stats/portalsReset")
    alertReason = NexusStatType.BEACON_RESET
  }
  {
    id = "team_kill"
    icon = "team_kill_icon"
    name = loc("stats/teamKills")
    reasonLocId = "reason/teammateKill"
    alertReason = NexusStatType.TEAM_KILL
  }
]

let scoreGap = {
  size = static [hdpx(15), flex()]
  halign = ALIGN_CENTER
  children = {
    rendObj = ROBJ_SOLID
    size = static [hdpx(1), flex()]
    color = BtnBdNormal
  }
}

let mkStatIcon = @(icon, size = statIconSize) {
  rendObj = ROBJ_IMAGE
  size
  image = Picture($"ui/skin#stats_icons/{icon}.svg:{size}:{size}:K")
}

let allKillStats = ["kill", "longshot_kill", "grenade_kill", "double_kill", "headshot_kill",
  "triple_kill", "melee_kill", "multiple_kill"]

function mkStatsHint(data, v, idx, scoreTbl) {
  let count = data?[v.id] ?? 0
  local points = null
  if (v.id == "kill") {
    points = allKillStats.reduce(function(res, id) {
      return res += data[id] * scoreTbl[id]
    }, 0)
  }
  return {
    rendObj = ROBJ_BOX
    size = static [hdpx(400), SIZE_TO_CONTENT]
    fillColor = mul_color(idx == 0 || idx % 2 == 0 ? ItemBgColor : BtnBgNormal, 1.0, 0.4)
    minHeight = SIZE_TO_CONTENT
    padding = static [hdpx(8), fsh(1)]
    flow = FLOW_HORIZONTAL
    gap = { size = flex() }
    children = [
      mkText(v?.name ?? loc(v.locId))
      {
        size = static [hdpx(110), SIZE_TO_CONTENT]
        flow = FLOW_HORIZONTAL
        gap = scoreGap
        children = [
          mkText(count, {
            size = static [hdpx(30), SIZE_TO_CONTENT]
            halign = ALIGN_CENTER
          })
          {
            size = FLEX_H
            flow = FLOW_HORIZONTAL
            valign = ALIGN_CENTER
            halign = ALIGN_RIGHT
            children = [
              mkText(points ?? (count * (scoreTbl?[v.id] ?? 0)), {
                halign = ALIGN_CENTER
                size = FLEX_H
              })
              mkStatIcon("all_score", hdpxi(15))
            ]
          }
        ]
      }
    ]
  }
}

let statsOrder = [
  {
    id = "kill"
    icon = "kill_icon"
    name = loc("stats/kills")
    reasonLocId = loc("reason/kill")
    alertReason = NexusStatType.KILL
    reasonOrder = 0
    mkTooltip = @(data, scoreTbl) tooltipBox({
      flow = FLOW_VERTICAL
      children = killTypesOrder.map(@(v, idx) mkStatsHint(data, v, idx, scoreTbl))
    }, { padding = 0 })
  }
  {
    id = "death"
    icon = "death_icon"
    name = loc("stats/deaths")
  }
  {
    id = "assist"
    icon = "assist_icon"
    name = loc("stats/assists")
    reasonLocId = loc("reason/assist")
    reasonOrder = 99
    alertReason = NexusStatType.ASSIST
  }
  {
    id = "score"
    icon = "all_score"
    width = hdpxi(100)
    name = loc("stats/score")
    mkTooltip = @(data, scoreTbl) tooltipBox({
      flow = FLOW_VERTICAL
      children = scoreHitnsOrder.map(@(v, idx) mkStatsHint(data, v, idx, scoreTbl))
    }, static { padding = 0 })
  }
]

let defStatsComps = [
  ["nexus_stats__kills", ecs.TYPE_INT],
  ["nexus_stats__teamKills", ecs.TYPE_INT],
  ["nexus_stats__assists", ecs.TYPE_INT],
  ["nexus_stats__beaconCaptures", ecs.TYPE_INT],
  ["nexus_stats__beaconResets", ecs.TYPE_INT],
  ["nexus_stats__deaths", ecs.TYPE_INT],
  ["nexus_stats__score", ecs.TYPE_INT],
  ["nexus_stats__hits", ecs.TYPE_INT]
]

let killsComps = [
  ["nexus_stats__meleeKills", ecs.TYPE_INT],
  ["nexus_stats__grenadeKills", ecs.TYPE_INT],
  ["nexus_stats__headshotKills", ecs.TYPE_INT],
  ["nexus_stats__longshotKills", ecs.TYPE_INT],
  ["nexus_stats__doubleKills", ecs.TYPE_INT],
  ["nexus_stats__tripleKills", ecs.TYPE_INT],
  ["nexus_stats__multipleKills", ecs.TYPE_INT]
]

ecs.register_es("track_nexus_stats_es", {
  [["onInit", "onChange"]] = function(_evt, _eid, comps) {
    let playerData = {
      kill = comps.nexus_stats__kills
      team_kill = comps.nexus_stats__teamKills
      assist = comps.nexus_stats__assists
      death = comps.nexus_stats__deaths
      beacon_capture = comps.nexus_stats__beaconCaptures
      beacon_reset = comps.nexus_stats__beaconResets
      melee_kill = comps.nexus_stats__meleeKills
      grenade_kill = comps.nexus_stats__grenadeKills
      headshot_kill = comps.nexus_stats__headshotKills
      longshot_kill = comps.nexus_stats__longshotKills
      double_kill = comps.nexus_stats__doubleKills
      triple_kill = comps.nexus_stats__tripleKills
      multiple_kill = comps.nexus_stats__multipleKills
      hit = comps.nexus_stats__hits
      score = comps.nexus_stats__score
      team = comps.nexus_stats__team
    }
    playersStats.mutate(@(value) value[comps.nexus_stats__owner] <- playerData)
  }
  onDestroy = @(...) playersStats.set({})
}, {
  comps_rq = [
    ["nexus_stats_total"],
  ]
  comps_ro = [
    ["nexus_stats__owner", ecs.TYPE_EID],
    ["nexus_stats__team", ecs.TYPE_INT]
  ]
  comps_track = defStatsComps.extend(killsComps)
}, {tags = "gameClient"})

ecs.register_es("track_nexus_round_stats_es", {
  [["onInit", "onChange"]] = function(_evt, _eid, comps) {
    let playerData = {
      kill = comps.nexus_stats__kills
      team_kill = comps.nexus_stats__teamKills
      assist = comps.nexus_stats__assists
      death = comps.nexus_stats__deaths
      beacon_capture = comps.nexus_stats__beaconCaptures
      beacon_reset = comps.nexus_stats__beaconResets
      melee_kill = comps.nexus_stats__meleeKills
      grenade_kill = comps.nexus_stats__grenadeKills
      headshot_kill = comps.nexus_stats__headshotKills
      longshot_kill = comps.nexus_stats__longshotKills
      double_kill = comps.nexus_stats__doubleKills
      triple_kill = comps.nexus_stats__tripleKills
      multiple_kill = comps.nexus_stats__multipleKills
      score = comps.nexus_stats__score
      team = comps.nexus_stats__team
    }
    playersRoundStats.mutate(function(value) {
      if (comps.nexus_stats__round not in value)
        value[comps.nexus_stats__round] <- {}
      value[comps.nexus_stats__round].__update({[comps.nexus_stats__owner] = playerData})
    })
  }
  onDestroy = @(...) playersRoundStats.set({})
}, {
  comps_rq = [
    ["nexus_stats_current_round"],
  ]
  comps_ro = [
    ["nexus_stats__owner", ecs.TYPE_EID],
    ["nexus_stats__team", ecs.TYPE_INT],
    ["nexus_stats__round", ecs.TYPE_INT, 0]
  ]
  comps_track = defStatsComps.extend(killsComps)
}, {tags = "gameClient"})

ecs.register_es("get_nexus_kill_round_types_es", {
  [["onInit", "onChange"]] = function(_evt, _eid, comps) {
    let kills = {
      melee_kill = comps.nexus_stats__meleeKills
      grenade_kill = comps.nexus_stats__grenadeKills
      headshot_kill = comps.nexus_stats__headshotKills
      longshot_kill = comps.nexus_stats__longshotKills
      double_kill = comps.nexus_stats__doubleKills
      triple_kill = comps.nexus_stats__tripleKills
      multiple_kill = comps.nexus_stats__multipleKills
      team = comps.nexus_stats__team
      round = comps.nexus_stats__round
    }
    killRoundTypes.mutate(@(value) value[comps.nexus_stats__owner] <- kills)
  }
  onDestroy = @(...) killRoundTypes.set({})
}, {
  comps_rq = [
    ["nexus_stats_current_round"],
  ]
  comps_ro = [
    ["nexus_stats__owner", ecs.TYPE_EID],
    ["nexus_stats__team", ecs.TYPE_INT],
    ["nexus_stats__round", ecs.TYPE_INT, 0]
  ]
  comps_track = killsComps
}, {tags = "gameClient"})

let nexusStatsForRoundQueue = ecs.SqQuery("nexusStatsForRoundQueue", {
  comps_ro = [
    ["nexus_stats__round", ecs.TYPE_INT],
    ["nexus_stats__team", ecs.TYPE_INT],
    ["nexus_stats__owner", ecs.TYPE_EID]
  ].extend(defStatsComps, killsComps)
})

let nexusWinHistoryQueue = ecs.SqQuery("nexusWinHistoryQueue", {
  comps_ro = [
    ["nexus_history__team", ecs.TYPE_INT],
    ["nexus_history__winReason", ecs.TYPE_INT],
    ["nexus_history__round", ecs.TYPE_INT]
  ]
})

function getWinHistoryData(round) {
  local res = null
  nexusWinHistoryQueue.perform(function(_evt, comps) {
    if (round == comps.nexus_history__round) {
      res = {
        winnerTeam = comps.nexus_history__team
        winReason = comps.nexus_history__winReason
      }
    }
  })
  return res
}

function getRoundData(round, data) {
  let res = {}
  foreach (player in data) {
    let { eid } = player
    nexusStatsForRoundQueue.perform(function(_evt, comps) {
      if (comps.nexus_stats__round == round && comps.nexus_stats__owner == eid) {
        res[eid] <- {
          kill = comps.nexus_stats__kills
          team_kill = comps.nexus_stats__teamKills
          assist = comps.nexus_stats__assists
          death = comps.nexus_stats__deaths
          beacon_capture = comps.nexus_stats__beaconCaptures
          beacon_reset = comps.nexus_stats__beaconResets
          melee_kill = comps.nexus_stats__meleeKills
          grenade_kill = comps.nexus_stats__grenadeKills
          headshot_kill = comps.nexus_stats__headshotKills
          longshot_kill = comps.nexus_stats__longshotKills
          double_kill = comps.nexus_stats__doubleKills
          triple_kill = comps.nexus_stats__tripleKills
          multiple_kill = comps.nexus_stats__multipleKills
          hit = comps.nexus_stats__hits
          score = comps.nexus_stats__score
          team = comps.nexus_stats__team
        }
      }
    })
  }
  return res
}

let mkPlayerStat = @(value, statData, fullData) value == null ? null : @() {
  watch = [hudIsInteractive, hoveredStatLine, localPlayerTeam, currentMenuId, isNexusEndGameDebriefing, isOnPlayerBase]
  size = [statData?.width ?? statWidth, statWidth]
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  behavior = hudIsInteractive.get()
    || isNexusEndGameDebriefing.get()
    || isOnPlayerBase.get()
    || currentMenuId.get() == NEXUS_STATS_ID ? Behaviors.Button : null
  skipDirPadNav=true
  onHover = function(on) {
    let scoreTbl = getScoresTbl()
    setTooltip(on ? statData?.mkTooltip(fullData, scoreTbl) ?? statData?.name ?? loc(statData?.locId) : null)
  }
  children = mkText(value, body_txt)
}

let mkPlayerStats = @(stats) {
  flow = FLOW_HORIZONTAL
  size = static [SIZE_TO_CONTENT, ph(100)]
  gap = hdpx(4)
  children = statsOrder.map(@(v) mkPlayerStat(stats?[v.id], v, stats))
}

function mkStatsHeader(statData, isEnemy) {
  let { icon, id, name = null, locId = null, width = null } = statData
  return @() {
    watch = [hudIsInteractive, currentMenuId, isOnPlayerBase]
    size = [width ?? statWidth, statWidth]
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    flow = FLOW_HORIZONTAL
    gap = hdpx(4)
    behavior = hudIsInteractive.get()
      || currentMenuId.get() == NEXUS_STATS_ID
      || isOnPlayerBase.get() ? Behaviors.Button : null
    skipDirPadNav = true
    onHover = function(on) {
      if (on) {
        setTooltip(name ?? loc(locId))
        hoveredStatLine.set($"{id}_{isEnemy ? -1 : localPlayerTeam.get()}")
      }
      else {
        setTooltip(null)
        hoveredStatLine.set(null)
      }
    }
    children = mkStatIcon(icon)
  }
}

let statsHeader = @(isEnemy = false) {
  flow = FLOW_HORIZONTAL
  gap = hdpx(4)
  hplace = ALIGN_RIGHT
  vplace = ALIGN_BOTTOM
  valign = ALIGN_CENTER
  padding = static [0, hdpx(8) + thinAndReservedPaddingStyle.BarNoScrollStyle._width,0,0]
  children = statsOrder.map(@(v) mkStatsHeader(v, isEnemy))
}

let mkPlayerStatRow = @(v, idx, statsData) @() {
  watch = [localPlayerEid, statsToShow]
  key = statsToShow.get()
  rendObj = ROBJ_SOLID
  size = FLEX_H
  padding = static [hdpx(10), hdpx(8)]
  color = v.eid == localPlayerEid.get() ? ItemBgColor
    : mul_color(idx == 0 || idx % 2 == 0 ? ItemBgColor : BtnBgNormal, 1.0, 0.4)
  flow = FLOW_HORIZONTAL
  gap = static { size = flex() }
  children = [
    {
      flow = FLOW_HORIZONTAL
      gap = static hdpx(10)
      valign = ALIGN_CENTER
      children = [
        mkText(idx + 1, {
          size = static [hdpx(40), SIZE_TO_CONTENT]
          halign = ALIGN_CENTER
        }.__update(body_txt))
        @() {
          watch = [isStreamerMode, playerRandName, localPlayerName]
          children = isStreamerMode.get() && v.name == localPlayerName.get()
            ? mkText(playerRandName.get(), body_txt)
            : mkText(remap_nick(v.name), body_txt)
        }
      ]
    }
    mkPlayerStats(statsData?[v.eid] ?? defStats)
  ]
}

function mkPlayerStatsBlock(data) {
  let playersStatsData = Computed(function() {
    local res = null
    if (statsToShow.get() == TOTAL_STATS_ID)
      res = playersStats.get()
    else {
      res = statsToShow.get() == nexusRoundModeRoundNumber.get()
        ? playersRoundStats.get()?[nexusRoundModeRoundNumber.get()]
        : getRoundData(statsToShow.get(), data)
    }
    return res
  })

  return @() {
    watch = playersStatsData
    size = flex()
    children = makeVertScrollExt(@() {
      watch = statsToShow
      key = statsToShow.get()
      size = FLEX_H
      flow = FLOW_VERTICAL
      children = data
        .sort(@(a, b) (playersStatsData.get()?[b.eid].score ?? 0) <=> (playersStatsData.get()?[a.eid].score ?? 0)
          || a.name <=> b.name)
        .map(@(v, idx) mkPlayerStatRow(v, idx, playersStatsData.get()))
    }, { styling = thinAndReservedPaddingStyle })
  }
}

let dummyStatsBlock = mkTextArea(loc("stats/emptyList"), {
  halign = ALIGN_CENTER
  vplace = ALIGN_CENTER
}.__update(h2_txt))

let teamStatsBlock = freeze({
  size = flex()
  flow = FLOW_HORIZONTAL
  gap = static {
    rendObj = ROBJ_SOLID
    color = BtnBdNormal
    size = static [hdpx(2), ph(94)]
    vplace = ALIGN_BOTTOM
    margin = static [0, hdpx(10)]
  }
  children = [
    @() {
      watch = [allyTeam, nexusModeTeamColors]
      size = flex()
      halign = ALIGN_CENTER
      flow = FLOW_VERTICAL
      children = allyTeam.get().len() <= 0 ? dummyStatsBlock : [
        mkText(static loc("nexus/playerTeam"), { color = nexusModeTeamColors.get()[1] }.__update(h2_txt))
        {
          size = flex()
          flow = FLOW_VERTICAL
          gap = static hdpx(10)
          children = [
            statsHeader
            mkPlayerStatsBlock(allyTeam.get().values())
          ]
        }
      ]
    }
    @() {
      watch = enemyTeam
      size = flex()
      flow = FLOW_VERTICAL
      halign = ALIGN_CENTER
      children = enemyTeam.get().len() <= 0 ? dummyStatsBlock : [
        static mkText(loc("nexus/enemyTeam"), { color = RedWarningColor }.__update(h2_txt))
        {
          size = flex()
          flow = FLOW_VERTICAL
          gap = static hdpx(10)
          children = [
            statsHeader(true)
            mkPlayerStatsBlock(enemyTeam.get().values())
          ]
        }
      ]
    }
  ]
})

function statTabs() {
  let roundsToExtend = nexusRoundModeRoundNumber.get() >= 0 ? array(nexusRoundModeRoundNumber.get()) : []
  let tabsList = [TOTAL_STATS_ID]
    .extend(roundsToExtend)
    .map(@(v, idx) {
      id = v ?? idx
      text = idx == 0 ? loc("stats/total") : loc("nexus/roundNumber", { number = getRomanNumeral(idx) })
    })
  let tabsUi = mkTabs({
    tabs = tabsList
    currentTab = statsToShow.get()
    onChange = function(tab) {
      statsToShow.set(tab.id)
    }
  })
  return {
    watch = [nexusRoundModeRoundNumber, statsToShow]
    flow = FLOW_HORIZONTAL
    children = tabsUi
  }
}

function fillPlayersToGetStats() {
  nexus_players_info_query.perform(@(eid, comps) nexusPlayersEids(eid, comps, localPlayerTeam.get()))
}

function mkWinHistoryBlock() {
  let winHistoryData = Computed(function() {
    local res = null
    if (statsToShow.get() == TOTAL_STATS_ID
      || (statsToShow.get() == nexusRoundModeRoundNumber.get() && !isNexusEndGameDebriefing.get())
    )
      return res
    res = getWinHistoryData(statsToShow.get())
    return res
  })
  return function() {
    let { winnerTeam = null, winReason = null } = winHistoryData.get()
    if (winnerTeam == null || winReason == null)
      return { watch = winHistoryData }
    let result = winnerTeam == nexusAllyTeam.get() ? loc("nexus/victory")
      : winnerTeam == nexusEnemyTeam.get() ? loc("nexus/defeat")
      : loc("nexus/draw")
    let color = winnerTeam == nexusAllyTeam.get() ? nexusModeTeamColors.get()[1]
      : winnerTeam == nexusEnemyTeam.get() ? RedWarningColor
      : TextHighlight
    let reasonLocId = nexusRoundEndReasonMap?[winReason]
    return {
      watch = [winHistoryData, nexusAllyTeam, nexusEnemyTeam, nexusModeTeamColors]
      hplace = ALIGN_CENTER
      flow = FLOW_VERTICAL
      halign = ALIGN_CENTER
      children = [
        mkText(result, { color }.__update(giant_txt))
        mkText(loc(reasonLocId), body_txt)
      ]
    }
  }
}

function targetTitle() {
  if (statsToShow.get() != nexusRoundModeRoundNumber.get() && statsToShow.get() != TOTAL_STATS_ID)
    return { watch = [statsToShow, nexusRoundModeRoundNumber] }
  let text = statsToShow.get() == TOTAL_STATS_ID && nexusRoundModeRoundNumber.get() >= 0
    ? loc("nexus/roundModeWinContidion", { count  = colorize(InfoTextValueColor, nexusRoundModeRoundsToWin.get()) })
    : loc("missionInfo/pvp")
  return {
    watch = [statsToShow, nexusRoundModeRoundsToWin, nexusRoundModeRoundNumber]
    size = [flex(), infoTitleHeight]
    valign = ALIGN_CENTER
    children = mkTextArea(text, { halign = ALIGN_CENTER }.__update(h1_txt))
  }
}

let mkMvpPlayerBlock = @(playerName, blockName, dataToShow, team, totalScore, hint = null, color = null) @() {
  watch = static [localPlayerTeam, nexusModeTeamColors]
  rendObj = ROBJ_BOX
  size = FLEX_H
  maxWidth = pw(33)
  borderColor = mul_color(color ?? (team == localPlayerTeam.get() ? nexusModeTeamColors.get()[1] : RedWarningColor), 0.6)
  borderWidth = hdpx(2)
  fillColor = ConsoleFillColor
  padding = static hdpx(10)
  flow = FLOW_VERTICAL
  behavior = Behaviors.Button
  skipDirPadNav = true
  onHover = @(on) hint == null ? null : setTooltip(on ? hint : null)
  halign = ALIGN_CENTER
  children = [
    @() {
      watch = [localPlayerName, isStreamerMode, playerRandName]
      children = isStreamerMode.get() && localPlayerName.get() == remap_nick(playerName)
        ? mkText(playerRandName.get(), { color = InfoTextValueColor }.__update(h2_txt))
        : mkText(remap_nick(playerName), { color = InfoTextValueColor }.__update(h2_txt))
    }
    mkText(blockName, body_txt)
    {
      flow = FLOW_HORIZONTAL
      valign = ALIGN_CENTER
      gap = hdpx(4)
      children = [
        mkText(dataToShow, body_txt)
        {
          flow = FLOW_HORIZONTAL
          valign = ALIGN_CENTER
          gap = hdpx(2)
          children = [
            mkText("(", body_txt)
            mkStatIcon("all_score", hdpxi(19))
            mkText(totalScore, body_txt)
            mkText(")", body_txt)
          ]
        }
      ]
    }
  ]
}

let mkMvpPlayerBlockSmall = @(playerName, blockName, dataToShow, hint = null) @() {
  watch = localPlayerTeam
  flow = FLOW_HORIZONTAL
  behavior = Behaviors.Button
  onHover = @(on) setTooltip(on && hint ? hint : null)
  children = [
    mkText($"{blockName}: ", sub_txt)
    mkText(remap_nick(playerName), { color = InfoTextValueColor }.__update(sub_txt))
    mkText($", {dataToShow}", sub_txt)
  ]
}

let mkMvpBlock = @(animDuration = null) function() {
  let ally = allyTeam.get()
  let enemy = enemyTeam.get()
  let statsId = statsToShow.get()
  let roundNum = nexusRoundModeRoundNumber.get()
  let data = statsId == TOTAL_STATS_ID
    ? playersStats.get()
    : statsId == roundNum
      ? playersRoundStats.get()?[roundNum]
      : getRoundData(statsId, [].extend(ally.values(), enemy.values()))

  let maxStats = {
    kills = { val = 0, data = null }
    captures = { val = 0, data = null }
    assists = { val = 0, data = null }
  }

  foreach (eid, st in (data ?? [])) {
    let { kill, beacon_capture, assist, beacon_reset, team } = st
    if (team != localPlayerTeam.get())
      continue
    if (kill > 0 && (kill >= maxStats.kills.val))
      maxStats.kills = { val = kill, data = { eid, team, count = kill, counts = kill } }
    if (beacon_capture > 0 && (beacon_capture > maxStats.captures.val ))
      maxStats.captures = {
        val = beacon_capture, data = { eid, team, count = beacon_capture, counts = beacon_capture }
      }

    let assistsSum = assist + beacon_reset
    if (assistsSum > 0 && (assistsSum >= maxStats.assists.val))
      maxStats.assists = {
        val = assistsSum, data = { eid, team, count = assistsSum, counts = assistsSum,
          hint = loc("nexus/mvpAssistsHint", {
            assist = colorize(InfoTextValueColor, assist),
            portal = colorize(InfoTextValueColor, beacon_reset)
          })
        }
      }
  }

  function nameByEid(eid) {
    return ally?[eid].name ?? enemy?[eid].name
  }

  function mvpBlock(stat, titleLoc, descLoc) {
    let d = stat.data
    return d == null ? null
      : mkMvpPlayerBlockSmall(nameByEid(d.eid), loc(titleLoc), loc(descLoc, d), d?.hint)
  }

  return {
    watch = [playersRoundStats, allyTeam, enemyTeam, playersStats, nexusRoundModeRoundNumber, localPlayerTeam, statsToShow]
    flow = FLOW_VERTICAL
    gap = hdpx(2)
    transform = static {}
    animations = animDuration == null ? null : [
      { prop = AnimProp.translate, from = static [-sw(100), 0], to = static [-sw(100), 0], duration = animDuration, play = true }
      {
        prop = AnimProp.translate, from = static [-sw(100), 0], to = static [0, 0],
        duration = animDuration, play = true,
        delay = animDuration, easing = InOutCubic,
        onStart = @() sound_play("ui_sounds/interface_open")
      }
    ]
    children = [
      mvpBlock(maxStats.kills, "stats/mostKills", "stats/maxKills")
      mvpBlock(maxStats.captures, "stats/mostCaptures", "stats/maxCaptures")
      mvpBlock(maxStats.assists, "stats/mostAssists", "stats/maxAssists")
    ]
  }
}

function statsUi() {
  nexus_players_info_query.perform(@(eid, comps) nexusPlayersEids(eid, comps, localPlayerTeam.get()))
  return {
    watch = localPlayerTeam
    size = flex()
    flow = FLOW_VERTICAL
    padding = static hdpx(10)
    gap = static hdpx(4)
    onDetach = function() {
      allyTeam.set({})
      enemyTeam.set({})
    }
    children = [
      statTabs
      {
        size = [flex(), infoTitleHeight]
        valign = ALIGN_BOTTOM
        children = [
          mkMvpBlock()
          mkWinHistoryBlock()
          targetTitle
        ]
      }
      teamStatsBlock
    ]
  }
}

let nexusStatsUi = wrapInStdPanel(NEXUS_STATS_ID, statsUi, nexusStatsWndTitle)

let mkGameResultTitle = @(localTeam) function() {
  let isWinner = localTeam == nexusGameWinner.get()
  let text = isWinner ? loc("nexus/victory") : loc("nexus/defeat")
  let color = isWinner ? nexusModeTeamColors.get()[1] : RedWarningColor
  return {
    watch = [nexusGameWinner, nexusModeTeamColors]
    rendObj = ROBJ_SOLID
    size = static [sw(100), SIZE_TO_CONTENT]
    halign = ALIGN_CENTER
    color = ConsoleFillColor
    padding = static [hdpx(8), 0]
    children = mkText(text, { color }.__update(giant_txt))
  }
}

let closeGameBtn = textButton(loc("nexus/returnToBase"), switch_to_menu_scene)

function mkCloseGameTimer() {
  let timer = mkCountdownTimerPerSec(nexusRoundModeGameEndTimer)
  let text = loc("nexus/rtbIn")
  return function() {
    if (timer.get() <= 0)
      return { watch = timer }
    return {
      watch = timer
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      flow = FLOW_HORIZONTAL
      padding = static [0, hdpx(4)]
      children = [
        mkText(text, static { color = TextHighlight })
        mkTimeComp(timer.get(), sub_txt, static mul_color(TextHighlight, Color(220,120,120)))
      ]
    }
  }
}

function endGameDebriefing() {
  nexus_players_info_query.perform(@(eid, comps) nexusPlayersEids(eid, comps, localPlayerTeam.get()))
  return {
    watch = localPlayerTeam
    rendObj = ROBJ_WORLD_BLUR_PANEL
    size = flex()
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    flow = FLOW_VERTICAL
    gap = hdpx(4)
    children = [
      mkGameResultTitle(localPlayerTeam.get())
      {
        size = screenSize
        flow = FLOW_VERTICAL
        padding = static hdpx(10)
        gap = static hdpx(4)
        children = [
          statTabs
          {
            size = [flex(), infoTitleHeight]
            valign = ALIGN_BOTTOM
            children = [
              mkWinHistoryBlock()
              mkMvpBlock()
            ]
          }
          teamStatsBlock
          {
            hplace = ALIGN_CENTER
            halign = ALIGN_CENTER
            flow = FLOW_VERTICAL
            gap = static hdpx(4)
            children = [
              mkCloseGameTimer()
              closeGameBtn
            ]
          }
        ]
      }
    ]
  }
}

isNexusEndGameDebriefing.subscribe_with_nasty_disregard_of_frp_update(@(v) v
  ? addModalWindow({
      key = END_GAME_DEBRIEFING_ID
      size = flex()
      onClick = @() null
      children = endGameDebriefing
    })
  : removeModalWindow(END_GAME_DEBRIEFING_ID))



let hitStats = {
  id = "hits"
  icon = "tripple_kill"
  locId = "stats/hits"
  alertReason = NexusStatType.HIT
}

let allReasons = [].extend(killTypesOrder, statsOrder).append(hitStats, scoreHitnsOrder[scoreHitnsOrder.len() - 3], scoreHitnsOrder[scoreHitnsOrder.len() - 2], scoreHitnsOrder[scoreHitnsOrder.len() - 1])

let mkCreditsBlock = @(credits) mkText($"{credits < 0 ? "" : "+"} {creditsTextIcon}{credits}",
  { color = InfoTextValueColor}.__update(body_txt) )

function mkReasonBlock(reason, count) {
  let reasonToShow = allReasons.findvalue(@(v) v?.alertReason == reason)
  if (reasonToShow == null)
    return null
  let { name = null, locId = null } = reasonToShow
  return {
    flow = FLOW_HORIZONTAL
    gap = hdpx(4)
    valign = ALIGN_CENTER
    children = [
      count <= 0 ? null
        : mkText($"{loc("ui/multiply")}{count}", { color = InfoTextValueColor}.__update(body_txt) )
      mkText(utf8ToUpper(name ?? loc(locId)), body_txt)
    ]
  }
}

function mkReasonsBlock(reasons) {
  let reasonsToShow = allReasons.filter(@(v) reasons.findvalue(@(reason) reason == v?.alertReason) != null)
  if (reasonsToShow.len() <= 0)
    return null
  let res = []
  reasonsToShow
    .sort(@(a, b) a.reasonOrder <=> b.reasonOrder)
    .each(function(v, idx) {
      let { reasonLocId = null } = v
      res.append(idx == 0 ? loc(reasonLocId) : colorize(InfoTextValueColor ,loc(reasonLocId)))
    })
  return mkTextArea(utf8ToUpper(" ".join(res)), { size = SIZE_TO_CONTENT }.__update(body_txt))
}

let mkRewardMessage = @(credits, reason, count = 1) {
  flow = FLOW_HORIZONTAL
  gap = hdpx(10)
  valign = ALIGN_CENTER
  hplace = ALIGN_CENTER
  children = [
    type(reason) == "array" ? mkReasonsBlock(reason) : mkReasonBlock(reason, count)
    mkCreditsBlock(credits)
  ]
}

let mkSkullIcon = @(count) {
  rendObj = ROBJ_IMAGE
  size = static [killIconSize, killIconSize]
  color = count < 3 ? RedWarningColor : InfoTextValueColor
  padding = static [hdpx(4), 0]
  image = Picture("ui/skin#skull.svg:{0}:{0}:K".subst(killIconSize))
}

let mkKillsSpecialMessage = @(credits, stat, count) {
  flow = FLOW_VERTICAL
  gap = hdpx(4)
  hplace = ALIGN_CENTER
  halign = ALIGN_CENTER
  children = [
    {
      rendObj = ROBJ_WORLD_BLUR_PANEL
      children = mkRewardMessage(credits, [stat], 0)
    }
    {
      flow = FLOW_HORIZONTAL
      gap = hdpx(4)
      hplace = ALIGN_CENTER
      halign = ALIGN_CENTER
      children = array(count).map(@(_v) mkSkullIcon(count))
    }
  ]
}

ecs.register_es("nexus_simple_reward_alert_es", {
  [[EventNexusSimpleStatChanged]] = function(evt, _eid, _comp) {
    let { stat, credits, count } = evt
    let reasonToShow = allReasons.findvalue(@(v) v?.alertReason == stat)
    if (reasonToShow != null)
      addPlayerReward({
        id = $"{stat}_{credits}_{get_time_msec()}"
        content = mkPlayerRewardLog({ message = mkRewardMessage(credits, stat, count)} )
      })
  },
  [[EventNexusKillStatChanged]] = function(evt, _eid, _comp) {
    let { credits, stats = null } = evt
    if (stats == null)
      return
    addPlayerReward({
      id = $"{stats[0]}_{credits}_{get_time_msec()}"
      content = mkPlayerRewardLog({ message = mkRewardMessage(credits, stats.getAll())} )
    })
    if (playerSpecialRewards.len() <= 0)
      addSpecialPlayerReward({
        id = $"{stats}_{credits}_kill_{get_time_msec()}"
        content = mkPlayerRewardLog({ message = mkSkullIcon(1)} )
      })
  },
  [[EventNexusAssistStatChanged]] = function(evt, _eid, _comp) {
    let { credits } = evt
    addPlayerReward({
      id = $"{NexusStatType.ASSIST}_{credits}_{get_time_msec()}"
      content = mkPlayerRewardLog({ message = mkRewardMessage(credits, NexusStatType.ASSIST)} )
    })
  },
  [[EventNexusKillGroupStatChanged]] = function(evt, _eid, _comp) {
    let { count, credits } = evt
    local stat = ""
    if (count == 2)
      stat = "DOUBLE_KILL"
    else if (count == 3)
      stat = "TRIPLE_KILL"
    else if (count >= 4)
      stat = "MULTIPLE_KILL"
    addSpecialPlayerReward({
      id = $"{stat}_{credits}_{get_time_msec()}"
      content = mkPlayerRewardLog({ message = mkKillsSpecialMessage(credits, stat, count)} )
    })
  }
}, {comps_rq = [ "nexus_player" ]}, { tags="gameClient" })

return freeze({
  statsHeader
  NEXUS_STATS_ID
  nexusStatsUi
  nexusTabHeader
  teamStatsBlock
  fillPlayersToGetStats
  statsToShow
  TOTAL_STATS_ID
  mkMvpBlock
  mkPlayerStats
  defStats
  mkMvpPlayerBlock
  getScoresTbl
})
