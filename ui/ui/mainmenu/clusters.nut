from "%ui/components/colors.nut" import ControlBgOpaque, BtnBgDisabled, BtnBdDisabled, BtnTextVisualDisabled
from "%ui/clusterState.nut" import clusterLoc
from "%ui/components/button.nut" import textButton
from "%ui/components/modalPopupWnd.nut" import addModalPopup
import "%ui/components/multiselect.nut" as multiselect
from "%ui/fonts_style.nut" import sub_txt

from "%ui/ui_library.nut" import *

let { canChangeQueueParams, queueClusters, isInQueue } = require("%ui/quickMatchQueue.nut")
let { availableClusters, clusters } = require("%ui/clusterState.nut")
let popupsState = require("%ui/popup/popupsState.nut")

let borderColor = Color(60,60,60,255)
let btnParams = {
  size = static [flex(), hdpx(30)],
  halign = ALIGN_LEFT,
  margin = 0,
  textMargin = [0, 0, 0, fsh(1)],
  clipChildren = true
  textParams = sub_txt.__merge({ behavior = Behaviors.Marquee})
}
let visualDisabledBtnParams = btnParams.__merge({
  style = {
    BtnBgNormal = BtnBgDisabled
    BtnBdNormal = BtnBdDisabled
    TextNormal = BtnTextVisualDisabled
  }
})

let clusterSelector = @() {
  size = FLEX_H
  watch = [availableClusters, clusters]
  children = multiselect({
    selected = clusters
    minOptions = 1
    options = availableClusters.get().map(@(c) { key = c, text = clusterLoc(c) })
  })
}

function showCantChangeMessage() {
  let text = isInQueue.get() ? loc("Can't change params while in queue") : loc("Only squad leader can change params")
  popupsState.addPopup({ id = "groupSizePopup", text = text, styleName = "error" })
}

let mkClustersUi = kwarg(function(textStyle=null){
  function openClustersMenu(event) {
    addModalPopup(event.targetRect, {
      uid = "clusters_selector"
      size = static [hdpx(250), SIZE_TO_CONTENT]
      children = clusterSelector
      popupOffset = hdpx(5)
      popupHalign = ALIGN_LEFT
      fillColor = ControlBgOpaque
      borderColor = borderColor
    })
  }
  function tryOpenMenu(event){
    if (canChangeQueueParams.get())
      openClustersMenu(event)
    else
      showCantChangeMessage()
  }
  function clustersText(){
    let clustersArr = queueClusters.get()
      .filter(@(has, cluster) has && availableClusters.get().indexof(cluster) != null)
      .keys()
    let chosenText = availableClusters.get().len() == clustersArr.len() ? loc("quickMatch/Server/Any")
      : ", ".join(clustersArr.map(clusterLoc))
    return {
      watch = [queueClusters, availableClusters]
      text = "{0}: {1}".subst(loc("quickMatch/Server"), chosenText)
      rendObj = ROBJ_TEXT
      onClick = tryOpenMenu
      skipDirPadNav = true
    }.__update(textStyle ?? {})
  }
  function clustersUi() {
    return {
      watch = [queueClusters, canChangeQueueParams, availableClusters]
      size =static [hdpx(250), SIZE_TO_CONTENT]
      children = canChangeQueueParams.get()
        ? textButton(clustersText().text, openClustersMenu, btnParams)
        : textButton(clustersText().text, showCantChangeMessage, visualDisabledBtnParams)
    }
  }
  return {
    clustersText
    openClustersMenu
    canChangeQueueParams
    clustersUi
    showCantChangeMessage
    tryOpenMenu
  }
})
return {
  mkClustersUi
}