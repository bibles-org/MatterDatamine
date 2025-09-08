from "%ui/ui_library.nut" import *
from "math" import clamp, max, min
import "%dngscripts/ecs.nut" as ecs

let { tiny_txt, h2_txt } = require("%ui/fonts_style.nut")
let { BtnBgSelected, ControlBg }  = require("%ui/components/colors.nut")
let { playerProfileAllResearchNodes, playerProfileOpenedNodes, playerProfileOpenedRecipes, playerStats, marketItems,
  allCraftRecipes } = require("%ui/profile/profileState.nut")
let { getRecipeIcon, researchOpenedMarker, researchSelectedMarker, getNodeName } = require("craftIcons.nut")
let { button, defButtonStyle } = require("%ui/components/button.nut")
let { mkTextArea, mkText } = require("%ui/components/commonComponents.nut")
let { doesLocTextExist } = require("dagor.localize")
let { monolithLevelOffers, currentMonolithLevel } = require("%ui/mainMenu/monolith/monolith_common.nut")
let { selectedPrototype, startReplication, getRecipeMonolithUnlock, selectedPrototypeMonolithData, showMonolithMsgBox,
  mkSmallMonolithLinkIcon, onlyEarnedRecipesFilter, onlyOpenedBlueprintsFilter, selectedCategory, prototypeTypes,
  filterTextInput, getRecipeName, mkNotifMarkWithExclamationSign } = require("%ui/mainMenu/craft_common_pkg.nut")
let { utf8ToLower } = require("%sqstd/string.nut")





let mapViewPos = Watched([0, 0])
let mapSize = [hdpx(1500), hdpx(1500)]
let selectedNetNode = Watched(null)
let slotHeight = hdpxi(70)
let notifCircleSize = hdpxi(20)

let selectedColor = BtnBgSelected


function mkMapBackground(pos, size) {
  let lines = [
    [ VECTOR_WIDTH, hdpx(3) ],
    [ VECTOR_COLOR, Color(55, 55, 55, 255) ],
    [ VECTOR_LINE, 0, 0, 0, 100 ],
    [ VECTOR_LINE, 0, 0, 100, 0 ],
    [ VECTOR_LINE, 100, 100, 0, 100 ],
    [ VECTOR_LINE, 100, 100, 100, 0 ]
  ]

  let mainLinesStepX = 100.0 / size[0].tofloat() * 100
  let mainLinesStepY = 100.0 / size[1].tofloat() * 100
  lines.append([VECTOR_WIDTH, hdpx(2)])
  lines.append([VECTOR_COLOR, Color(55, 55, 55, 255)])

  for (local i = mainLinesStepY; i < 100; i += mainLinesStepY) {
    lines.append([ VECTOR_LINE, 0, i, 100, i ])
  }
  for (local i = mainLinesStepX; i < 100; i += mainLinesStepX) {
    lines.append([ VECTOR_LINE, i, 0, i, 100 ])
  }


  let secondaryLinesStepX = 25.0 / size[0].tofloat() * 100
  let secondaryLinesStepY = 25.0 / size[1].tofloat() * 100
  lines.append([VECTOR_WIDTH, hdpx(1)])
  lines.append([VECTOR_COLOR, Color(55, 55, 55, 155)])

  for (local i = secondaryLinesStepY; i < 100; i += secondaryLinesStepY) {
    lines.append([ VECTOR_LINE, 0, i, 100, i ])
  }
  for (local i = secondaryLinesStepX; i < 100; i += secondaryLinesStepX) {
    lines.append([ VECTOR_LINE, i, 0, i, 100 ])
  }

  return {
    opacity = 0.5
    pos
    size
    rendObj = ROBJ_VECTOR_CANVAS
    commands = lines
  }
}


function mkResearchMap(background, content) {
  let children = [background].extend(content)
  return @(){
    size = mapSize
    watch = [ mapViewPos ]
    pos = mapViewPos.get()

    children
  }
}


function getRecipeProgress(current, needToResearch) {
  let minVal = 0.0
  let maxVal = 1.0
  if (current == null || needToResearch == null)
    return minVal

  if (needToResearch == 0)
    return maxVal

  let val = current.tofloat() / needToResearch.tofloat()
  return clamp(val, minVal, maxVal)
}

let ResearchItemStyle = defButtonStyle.__merge({ BtnBdNormal = Color(0,0,0)})
let ResearchItemSelectedStyle = ResearchItemStyle.__merge({ BtnBgNormal = selectedColor})

function mkNode(id, node) {
  let isSelected = Computed(@() node?.containsRecipe == selectedPrototype.get())
  let nodeLocId = getNodeName(node)
  let nodeName = doesLocTextExist($"{nodeLocId}/short") ? loc($"{nodeLocId}/short") : loc(nodeLocId)
  let title = {
    rendObj = ROBJ_WORLD_BLUR_PANEL
    vplace = ALIGN_TOP
    pos = [0, (slotHeight / 2) + hdpx(4)]
    children = mkTextArea(nodeName, {
      size = SIZE_TO_CONTENT
      padding = [ hdpx(1), hdpx(4) ]
      halign = ALIGN_CENTER
      maxWidth = hdpx(110)
    }.__update(tiny_txt))
  }
  let progress = node.recipeData == null
    ? getRecipeProgress(node.openedData?.currentResearchPoints, node.requireResearchPointsToComplete)
    : 1.0
  return function() {
    let playerResearch = playerProfileOpenedNodes.get().findvalue(@(v) v.prototypeId == id)
    let locked = playerResearch == null
    let monolithUnlockData = !locked ? null
      : getRecipeMonolithUnlock(id, nodeName, marketItems.get(), monolithLevelOffers.get(),
          playerStats.get(), currentMonolithLevel.get())
    let monolithLinkIcon = monolithUnlockData == null ? null
      : mkSmallMonolithLinkIcon(monolithUnlockData, @() showMonolithMsgBox(monolithUnlockData))
    return {
      watch = [isSelected, marketItems, monolithLevelOffers, playerStats, playerProfileOpenedNodes]
      pos = [ hdpx(node.visuals.nodeViewPosition.x), hdpx(node.visuals.nodeViewPosition.y)]
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      size = [0, 0]
      gap = hdpx(2)
      children = [
        button(
          {
            children = [
              {
                children = [
                  getRecipeIcon(
                    node.containsRecipe,
                    [slotHeight, slotHeight],
                    progress,
                    node.recipeData != null ? "full" : "silhouette"
                  )
                  node.openedData && progress < 1.0 ? researchOpenedMarker : null
                  isSelected.get() ? researchSelectedMarker : null
                ]
              }
              monolithLinkIcon
              progress == 1 && node.recipeData == null ? mkNotifMarkWithExclamationSign(notifCircleSize) : null
            ]
          }
          function() {
            selectedPrototypeMonolithData.set(monolithUnlockData)
            selectedPrototype.set(node?.containsRecipe ?? id)
          }
          {
            padding = hdpx(1)
            opacity = node?.opacity ?? 1
            eventPassThrough = true
            hplace = ALIGN_CENTER
            vplace = ALIGN_CENTER
            style = isSelected.get() ? ResearchItemSelectedStyle : ResearchItemStyle
            onHover = @(on) !on ? selectedNetNode.set(null)
              : selectedNetNode.set({id})
            onDoubleClick = function() {
              if (monolithUnlockData != null) {
                showMonolithMsgBox(monolithUnlockData)
                return
              }
              startReplication()
            }
          }
        )
        title
      ]
    }
  }
}

function mkNodesNet(nodes) {
  let ret = []
  foreach (k, v in nodes) {
    ret.append(mkNode(k, v))
  }
  return ret
}

function getMaxMinOfTree(nodes) {
  let defaultMax = 10000
  let treeMax = [-defaultMax, -defaultMax]
  let treeMin = [defaultMax, defaultMax]

  foreach (_id, node in nodes) {
    let vMin = [ hdpx(node.visuals.nodeViewPosition.x), hdpx(node.visuals.nodeViewPosition.y) ]
    let vMax = [ vMin[0], vMin[1] ]

    treeMax[0] = max(treeMax[0], vMax[0])
    treeMax[1] = max(treeMax[1], vMax[1])
    treeMin[0] = min(treeMin[0], vMin[0])
    treeMin[1] = min(treeMin[1], vMin[1])
  }
  return {
    treeMin
    treeMax
  }
}

let researchNetSize = Watched([0, 0])

let noRecipesFoundMsg = const {
  size = [ flex(), sh(20) ]
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  children = mkText(loc("craft/noRecipesFoundByFiltering"), h2_txt)
}

function mkResearchNet() {
  let currentBranchNodes = Computed(function()  {
    let selectedCat = selectedCategory.get()
    let protoTypes = prototypeTypes.get()
    let allRecipes = allCraftRecipes.get()
    let openedRecipesArr = playerProfileOpenedRecipes.get()
    let openedNodesArr = playerProfileOpenedNodes.get()
    let allNodesArr = playerProfileAllResearchNodes.get()
    let earned = onlyEarnedRecipesFilter.get()
    let openedFilter = onlyOpenedBlueprintsFilter.get()

    let res = {}

    let openedRecipesMap = {}
    foreach (i, v in openedRecipesArr)
      openedRecipesMap[v.prototypeId] <- i

    let openedNodesMap = {}
    foreach (v in openedNodesArr)
      openedNodesMap[v.prototypeId] <- v

    let allNodesMap = {}
    foreach (i, v in allNodesArr)
      allNodesMap[v.containsRecipe] <- i

    foreach (proto_id, prototype in allRecipes) {
      let recipeIdx = openedRecipesMap?[proto_id]
      let playerResearch = openedNodesMap?[proto_id]
      let recipeReceived = recipeIdx != null
      let nodeId = allNodesMap?[proto_id]
      if (nodeId == null)
        continue

      let matchesCategory = selectedCat == null ||
        prototype.results.findindex(@(_v, k) protoTypes?[k] == selectedCat) != null

      local opacity = 1.0
      if (!matchesCategory)
        opacity = 0.4
      if (earned && openedFilter)
        opacity = (recipeReceived || playerResearch) ? 1.0 : 0.4
      else if (earned)
        opacity = recipeReceived ? 1.0 : 0.4
      else if (openedFilter)
        opacity = playerResearch && !recipeReceived ? 1.0 : 0.4

      if (filterTextInput.get() != ""
        && !utf8ToLower(loc(getRecipeName(prototype))).contains(utf8ToLower(filterTextInput.get()))
      )
        opacity = 0.4
      let nodeData = allNodesArr[nodeId].__merge({
        openedData = playerResearch,
        recipeData = recipeIdx
        opacity
      })
      res[nodeId] <- nodeData
    }

    return res
  })


  function onNetMoveResize(dx, dy, _dw, _dh, backgroundPos, backgroundSize, netSize) {
    let old = mapViewPos.get()
    let newPos = [
      -clamp(-(old[0] + dx), backgroundPos[0], backgroundPos[0] + max(0, backgroundSize[0] - netSize[0])),
      -clamp(-(old[1] + dy), backgroundPos[1], backgroundPos[1] + max(0, backgroundSize[1] - netSize[1]))
    ]
    mapViewPos.set(newPos)
  }

  return function() {
    if (currentBranchNodes.get().len() <= 0)
      return {
        watch  = currentBranchNodes
        rendObj = ROBJ_SOLID
        size = flex()
        color = ControlBg
        children = noRecipesFoundMsg
      }
    let centralNodeId = 1
    let firstNode = playerProfileAllResearchNodes.get()[centralNodeId]
    let firstNodePos = [firstNode.visuals.nodeViewPosition.x, firstNode.visuals.nodeViewPosition.y]

    let { treeMin, treeMax } = getMaxMinOfTree(currentBranchNodes.get())
    let treeSize = [treeMax[0] - treeMin[0], treeMax[1] - treeMin[1]]

    let backgroundOffset = hdpx(75)
    let backgroundPos = [ treeMin[0] - backgroundOffset, treeMin[1] - backgroundOffset ]
    let backgroundSize = [ treeSize[0] + backgroundOffset * 2, treeSize[1] + backgroundOffset * 2 ]

    return {
      watch = [currentBranchNodes, playerProfileAllResearchNodes]
      rendObj = ROBJ_SOLID
      key = $"researchNet"
      size = flex()
      color = ControlBg
      behavior = Behaviors.MoveResize
      clipChildren = true
      onMoveResize = @(dx, dy, dw, dh)
        onNetMoveResize(dx, dy, dw, dh, backgroundPos, backgroundSize, researchNetSize.get())
      onAttach = function(elem) {
        let selectedNode = playerProfileAllResearchNodes.get().findvalue(@(v) v.containsRecipe == selectedPrototype.get())
        let selectedNodePos = [selectedNode?.visuals.nodeViewPosition.x, selectedNode?.visuals.nodeViewPosition.y]

        researchNetSize.set([elem.getWidth(), elem.getHeight()])

        let startPos = [
          -clamp(-(elem.getWidth() / 2 - (selectedNodePos[0] ?? firstNodePos[0])),
            backgroundPos[0], backgroundPos[0] + max(0, backgroundSize[0] - researchNetSize.get()[0])),
          -clamp(-(elem.getHeight() / 2 - (selectedNodePos[1] ?? firstNodePos[1])),
            backgroundPos[1], backgroundPos[1] + max(1, backgroundSize[1] - researchNetSize.get()[1]))
        ]
        mapViewPos.set(startPos)
        onNetMoveResize(0, 0, 0, 0, backgroundPos, backgroundSize, researchNetSize.get())
      }
      children = mkResearchMap(
        mkMapBackground(backgroundPos, backgroundSize)
        mkNodesNet(currentBranchNodes.get())
      )
    }
  }
}

return {
  mkResearchNet,
  selectedNetNode,
  selectedPrototype
  getRecipeProgress
}
