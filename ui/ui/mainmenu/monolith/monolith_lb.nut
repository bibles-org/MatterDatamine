from "%ui/ui_library.nut" import *

let { h2_txt, body_txt } = require("%ui/fonts_style.nut")
let { curLbData, curLbPlayersCount } = require("%ui/leaderboard/lb_state_base.nut")
let { mkText, mkTextArea } = require("%ui/components/commonComponents.nut")
let { ceil } = require("math")
let { mkHorizPaginatorList } = require("%ui/components/mkDotPaginatorList.nut")
let { format_unixtime } = require("dagor.time")
let { playerBaseState } = require("%ui/profile/profileState.nut")
let { BtnBdFocused, BtnBdTransparent, BtnBgSelected } = require("%ui/components/colors.nut")

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
    valueToShow = @(idx) curLbPlayersCount.get() - idx
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
]

function monolithProgress() {
  let { playersCountToRestartProgress = 0 } = playerBaseState.get()
  if (playersCountToRestartProgress == 0 || curLbPlayersCount.get() == null)
    return const { watch = [playerBaseState, curLbData]}
  let percent = curLbPlayersCount.get() / playersCountToRestartProgress.tofloat() * 100

  return {
    watch = const [playerBaseState, curLbData]
    size = const [flex(), SIZE_TO_CONTENT]
    flow = FLOW_VERTICAL
    gap = const hdpx(6)
    children = [
      const mkText(loc("monolith/resetProgress"), body_txt)
      {
        rendObj = ROBJ_BOX
        size = const [flex(), hdpx(40)]
        borderWidth = hdpx(2)
        borderColor = BtnBdTransparent
        transform = const {}
        animations = const [
          {
            prop = AnimProp.borderColor, from = BtnBdTransparent, to = BtnBdFocused, easing = CosineFull,
            duration = 10, loop = true, play = true
          }
        ]
        children = [
          {
            rendObj = ROBJ_SOLID
            size = [pw(percent), flex()]
            margin = const [hdpx(2), 0, hdpx(2), hdpx(2)]
            color = BtnBgSelected
          }
          mkText($"{curLbPlayersCount.get()}/{playersCountToRestartProgress}", const {
            vplace = ALIGN_CENTER
            hplace = ALIGN_CENTER
          }.__update(body_txt, { fontSize=hdpx(22)}))
        ]
      }
    ]
  }
}

let mkLbTitle = @(locId, override = const {}) {
  rendObj = ROBJ_SOLID
  size = const [flex(), hdpx(rowHeight)]
  color = 0xF01C1C1C
  padding = const [0, hdpx(8)]
  valign = ALIGN_CENTER
  children = mkText(loc(locId), const body_txt.__merge({ fontSize=hdpx(22) }))
}.__update(override)

let mkDataRow = @(data, ctor, idx, override) data == null ? null : {
  rendObj = ROBJ_SOLID
  size = const [flex(), hdpx(rowHeight)]
  color = idx == 0 || idx % 2 == 0 ?  0xDD0F0F0F : 0xDD1C1C1C
  valign = ALIGN_CENTER
  padding = const [0, hdpx(8)]
  children = mkText(ctor(data), const body_txt.__merge({ fontSize=hdpx(22) }))
}.__update(override)

function mkDataTable(dataToAdd) {
  let pageCols = lbCategories.map(function(category) {
    let { locId, width, dataIdx, valueToShow, override = const {} } = category
    let title = mkLbTitle(locId, override)
    return {
      size = const [width, SIZE_TO_CONTENT]
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
  if (curLbData.get() == null || curLbData.get().len() == 0)
    return {
      watch = curLbData
      size = flex()
      children = emptyText
    }

  let res = []
  let totalRows = curLbData.get().len()
  let totalCols = ceil(totalRows.tofloat() / LB_ROWS_PER_COL)
  let data = curLbData.get()

  for (local table = 0; table < totalCols; table++) {
    let dataToAdd = data.slice(table * LB_ROWS_PER_COL, min(data.len(), (table + 1) * LB_ROWS_PER_COL))
    let pageCols = mkDataTable(dataToAdd)
    res.append(pageCols)
  }

  return {
    watch = [curLbData, curLbPlayersCount]
    size = flex()
    flow = FLOW_HORIZONTAL
    gap = hdpx(10)
    children = mkHorizPaginatorList(
      res.map(@(v) {
        size = [pw(33), hdpx(560)]
        flow = FLOW_HORIZONTAL
        children = v
      }), COLS_PER_PAGE, currentLbPage, {
        size = [flex(), SIZE_TO_CONTENT]
        flow = FLOW_HORIZONTAL
        gap = hdpx(10)
      })
  }
}

let lbContent = {
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  gap = hdpx(4)
  children = [
    lbListTitle
    lbList
  ]
}

let tabTitle = {
  size = [flex(), titleHeight]
  valign = ALIGN_CENTER
  children = mkText(loc("monolith/lbTitle"), h2_txt)
}

let monolithLbUi = {
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

return {
  monolithLbUi
  MONOLITH_LB_ID
}