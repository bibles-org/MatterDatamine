from "%ui/control/active_controls.nut" import isGamepad
from "%ui/ui_library.nut" import *
from "%ui/components/scrollbar.nut" import makeVertScrollExt
import "%ui/components/spinner.nut" as spinner
from "%ui/changeLogState.nut" import curPatchnote, chosenPatchnoteContent, selectPatchnote, chosenPatchnoteTitle, chosenPatchnoteLoaded, versions, patchnotesReceived, extNewsUrl
from "%ui/components/formatText.nut" import formatText
from "%ui/helpers/localizationUtils.nut" import processHyphenations
import "%ui/components/colors.nut" as colors
from "%ui/components/colors.nut" import TextNormal, TextHighlight, SelBgNormal, SelBdHover, TextHover, BtnBdNormal
import "math" as math

let waitingSpinner = spinner()

let scrollHandler = ScrollHandler()
let smallPadding = hdpx(5)

function onTabClicked(v) {
  if (curPatchnote.get() != v) {
    selectPatchnote(v)
    scrollHandler.scrollToY(0)
  }
}

function mkVersionTab(v) {
  let isCurrent = Computed(@() curPatchnote.get() == v)
  let group = ElemGroup()
  return watchElemState(@(sf) {
    watch = isCurrent
    rendObj = ROBJ_BOX
    size = flex()
    valign = ALIGN_CENTER
    group
    behavior = Behaviors.Button
    fillColor = sf & S_HOVER ? SelBdHover
      : isCurrent.get() ? SelBgNormal
      : 0
    borderWidth = isCurrent.get() ? [0, 0, hdpx(4), 0] : 0
    borderColor = BtnBdNormal
    onClick = @() onTabClicked(v)
    skipDirPadNav = false 
    maxWidth = hdpx(200)
    padding = smallPadding
    children = {
      rendObj = ROBJ_TEXTAREA
      size = FLEX_H
      group
      behavior = Behaviors.TextArea
      halign = ALIGN_CENTER
      color = sf & S_HOVER
        ? TextHover
        : isCurrent.get() ? TextHighlight : TextNormal
      text = v?.titleshort ?? v.tVersion
    }
  })
}

let missedPatchnoteText = formatText([loc("NoUpdateInfo", "Oops... No information yet :(")])
let isVersionsExists = Computed(@() versions.get().len() > 0)

let patchnoteSelector = @() {
  watch = [versions, patchnotesReceived, isVersionsExists, isGamepad]
  size = static [flex(), fsh(6)]
  flow = FLOW_HORIZONTAL
  padding = static [0, hdpx(5)]
  halign = isGamepad.get() ? ALIGN_CENTER : ALIGN_LEFT
  valign = ALIGN_CENTER
  onAttach = function(){
    if (patchnotesReceived.get() && curPatchnote.get()!=null)
      selectPatchnote(curPatchnote.get())
  }
  children = patchnotesReceived.get() && isVersionsExists.get()
    ? (clone versions.get()).reverse().map(mkVersionTab)
    : {  padding = static [0, hdpx(10)] children = missedPatchnoteText size = FLEX_H, halign = ALIGN_CENTER}
}

let seeMoreUrl = {
  t="url"
  platform="pc,ps4"
  url=extNewsUrl
  v=loc("visitGameSite", "See game website for more details")
  margin = static [hdpx(50), 0, 0, 0]
}

let patchnoteLoading = freeze({
  flow  = FLOW_VERTICAL
  halign = ALIGN_CENTER
  gap = hdpx(20)
  valign = ALIGN_CENTER size = static [flex(), fsh(20)]
  padding = fsh(2)
  children = [
    formatText([{v = loc("Loading"), t = "h2", halign = ALIGN_CENTER}])
    waitingSpinner
  ]
})

function currentPatchnote(){
  local text = chosenPatchnoteContent.get() ?? ""
  if (text == "")
    text = missedPatchnoteText
  if (type(text)!="array")
    text = [text, seeMoreUrl]
  else
    text = (clone text).append(seeMoreUrl)
  if (chosenPatchnoteTitle.get() != "")
    text = [{v = chosenPatchnoteTitle.get(), t="h1"}].extend(text)
  text = processHyphenations(text)
  return {
   rendObj = ROBJ_BOX
   borderWidth = static [hdpx(1), 0]
   padding = static [hdpx(1), 0]
   borderColor = colors.ConsoleBorderColor
   fillColor = colors.ModalBgTint
    watch = [chosenPatchnoteLoaded, chosenPatchnoteContent, chosenPatchnoteTitle, curPatchnote]
    children = makeVertScrollExt({
      size = FLEX_H
      padding = [smallPadding, hdpx(20)]
      children = chosenPatchnoteLoaded.get()
        ? [{
            rendObj = ROBJ_TEXT
            text = curPatchnote.get()?.date.split("T")[0]
            hplace = ALIGN_RIGHT
            color = TextNormal
          }].append(formatText(text))
        : patchnoteLoading
    }, { scrollHandler })
    size = [math.min(sw(75), sh(75)*16/9), sh(75)]
  }
}

return {
  currentPatchnote
  patchnoteSelector
}
