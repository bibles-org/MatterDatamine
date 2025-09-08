from "%ui/ui_library.nut" import *

let {ControlBgOpaque, BtnBgDisabled, BtnBdDisabled, BtnTextVisualDisabled} = require("%ui/components/colors.nut")
let {canChangeQueueParams, queueClusters, isInQueue} = require("%ui/quickMatchQueue.nut")
let {availableClusters, clusters, clusterLoc} = require("%ui/clusterState.nut")
let popupsState = require("%ui/popup/popupsState.nut")
let { textButton } = require("%ui/components/button.nut")
let { addModalPopup } = require("%ui/components/modalPopupWnd.nut")
let multiselect = require("%ui/components/multiselect.nut")
let { sub_txt } = require("%ui/fonts_style.nut")

let borderColor = Color(60,60,60,255)
let btnParams = {
  size = [flex(), hdpx(30)],
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
  size = [flex(), SIZE_TO_CONTENT]
  watch = [availableClusters, clusters]
  children = multiselect({
    selected = clusters
    minOptions = 1
    options = availableClusters.value.map(@(c) { key = c, text = clusterLoc(c) })
  })
}

function showCantChangeMessage() {
  let text = isInQueue.value ? loc("Can't change params while in queue") : loc("Only squad leader can change params")
  popupsState.addPopup({ id = "groupSizePopup", text = text, styleName = "error" })
}

let mkClustersUi = kwarg(function(textStyle=null){
  function openClustersMenu(event) {
    addModalPopup(event.targetRect, {
      uid = "clusters_selector"
      size = [hdpx(250), SIZE_TO_CONTENT]
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
    }.__update(textStyle ?? {})
  }
  function clustersUi() {
    return {
      watch = [queueClusters, canChangeQueueParams, availableClusters]
      size =[hdpx(250), SIZE_TO_CONTENT]
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