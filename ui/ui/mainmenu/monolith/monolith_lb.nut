from "%ui/fonts_style.nut" import h2_txt, body_txt
from "%ui/components/commonComponents.nut" import mkText, mkTextArea
from "math" import ceil
from "%ui/components/mkDotPaginatorList.nut" import mkHorizPaginatorList
from "dagor.time" import format_unixtime
from "%ui/components/colors.nut" import BtnBdFocused, BtnBdTransparent, BtnBgSelected
from "%ui/leaderboard/lb_state_base.nut" import curMonolithLbData, curMonolithLbPlayersCount, curMonolithLbVotesCount

from "%ui/ui_library.nut" import *

let { playerBaseState } = require("%ui/profile/profileState.nut")

const MONOLITH_LB_ID = "monolithLbId"
const LB_ROWS_PER_COL = 13
const COLS_PER_PAGE = 3
const TIME_FMT = "%d %b %Y"

let currentLbPage = Watched(0)

let titleHeight = hdpx(50)
let rowHeight = 40

let lbCategories = [
  {
    field = "idx"
    locId = "lb/index"
    width = flex(0.5)
    dataIdx = 0
    valueToShow = @(idx) curMonolithLbPlayersCount.get() - idx + 1
  }
  {
    field = "name"
    locId = "lb/name"
    width = flex()
    dataIdx = 2
    valueToShow = @(name) name
  }
  {
    field = "time"
    locId = "lb/time"
    width = flex(0.7)
    dataIdx = 3
    override = {
      halign = ALIGN_RIGHT
    }
    valueToShow = @(timestamp) format_unixtime(TIME_FMT, timestamp)
  }
  {
    field = "path_selection_count"
    locId = "lb/path_selection_count"
    width = flex(0.7)
    dataIdx = 4
    override = {
      halign = ALIGN_RIGHT
    }
    valueToShow = @(count) count
  }
]

function monolithProgress() {
  let { playersCountToRestartProgress = 0 } = playerBaseState.get()
  if (playersCountToRestartProgress == 0 || curMonolithLbVotesCount.get() == null)
    return static { watch = [playerBaseState, curMonolithLbData, curMonolithLbVotesCount]}
  let percent = curMonolithLbVotesCount.get() / playersCountToRestartProgress.tofloat() * 100

  return {
    watch = static [playerBaseState, curMonolithLbData, curMonolithLbVotesCount]
    size = FLEX_H
    flow = FLOW_VERTICAL
    gap = static hdpx(6)
    children = [
      static mkText(loc("monolith/resetProgress"), body_txt)
      {
        rendObj = ROBJ_BOX
        size = static [flex(), hdpx(40)]
        borderWidth = hdpx(2)
        borderColor = BtnBdTransparent
        transform = static {}
        animations = static [
          {
            prop = AnimProp.borderColor, from = BtnBdTransparent, to = BtnBdFocused, easing = CosineFull,
            duration = 10, loop = true, play = true
          }
        ]
        children = [
          {
            rendObj = ROBJ_SOLID
            size = [pw(percent), flex()]
            margin = static [hdpx(2), 0, hdpx(2), hdpx(2)]
            color = BtnBgSelected
          }
          mkText($"{curMonolithLbVotesCount.get()}/{playersCountToRestartProgress}", static {
            vplace = ALIGN_CENTER
            hplace = ALIGN_CENTER
          }.__update(body_txt, { fontSize=hdpx(22)}))
        ]
      }
    ]
  }
}

let mkLbTitle = @(locId, override = static {}) {
  rendObj = ROBJ_SOLID
  size = static [flex(), hdpx(rowHeight)]
  color = 0xF01C1C1C
  padding = static [0, hdpx(8)]
  valign = ALIGN_CENTER
  children = mkText(loc(locId), static body_txt.__merge({ fontSize=hdpx(22) }))
}.__update(override)

let mkDataRow = @(data, ctor, idx, override) data == null ? null : {
  rendObj = ROBJ_SOLID
  size = static [flex(), hdpx(rowHeight)]
  color = idx == 0 || idx % 2 == 0 ?  0xDD0F0F0F : 0xDD1C1C1C
  valign = ALIGN_CENTER
  padding = static [0, hdpx(8)]
  children = mkText(ctor(data), static body_txt.__merge({ fontSize=hdpx(22) }))
}.__update(override)

function mkDataTable(dataToAdd) {
  if (dataToAdd.len() <= 0)
    return null
  let pageCols = lbCategories.map(function(category) {
    let { locId, width, dataIdx, valueToShow, override = static {} } = category
    let title = mkLbTitle(locId, override)
    return {
      size = [width, SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      children = [
        title
      ].extend(dataToAdd.map(@(v, idx) mkDataRow(v?[dataIdx], valueToShow, idx, override)))
    }
  })
  return pageCols
}

let emptyText = mkTextArea(loc("monolith/lbEmpty"), {
  vplace = ALIGN_CENTER
  halign = ALIGN_CENTER
}.__update(h2_txt))

let lbListTitle = mkText(loc("monolith/lbListTitle"), body_txt)

function lbList() {
  if (curMonolithLbData.get() == null || curMonolithLbData.get().len() == 0)
    return {
      watch = curMonolithLbData
      size = flex()
      children = emptyText
    }

  let res = []
  let data = curMonolithLbData.get().filter(@(v) v?[1] != 208876377)
  let totalRows = data.len()
  let totalCols = ceil(totalRows.tofloat() / LB_ROWS_PER_COL)

  for (local table = 0; table < totalCols; table++) {
    let dataToAdd = data.slice(table * LB_ROWS_PER_COL, min(data.len(), (table + 1) * LB_ROWS_PER_COL))
    let pageCols = mkDataTable(dataToAdd)
    res.append(pageCols)
  }

  return {
    watch = [curMonolithLbData, curMonolithLbPlayersCount]
    size = flex()
    flow = FLOW_HORIZONTAL
    gap = hdpx(10)
    children = mkHorizPaginatorList(
      res.map(@(v) {
        size = static [pw(33), hdpx(560)]
        flow = FLOW_HORIZONTAL
        children = v
      }), COLS_PER_PAGE, currentLbPage, {
        size = FLEX_H
        flow = FLOW_HORIZONTAL
        gap = hdpx(10)
      })
  }
}

let lbContent = @() {
  size = FLEX_H
  flow = FLOW_VERTICAL
  gap = hdpx(4)
  children = [
    lbListTitle
    lbList
  ]
}

let tabTitle = freeze({
  size = [flex(), titleHeight]
  valign = ALIGN_CENTER
  children = mkText(loc("monolith/lbTitle"), h2_txt)
})

let monolithLbUi = @() {
  size = flex()
  flow = FLOW_VERTICAL
  children = [
    tabTitle
    {
      size = flex()
      flow = FLOW_VERTICAL
      gap = hdpx(20)
      children = [
        monolithProgress
        lbContent
      ]
    }
  ]
}

return freeze({
  monolithLbUi
  MONOLITH_LB_ID
})