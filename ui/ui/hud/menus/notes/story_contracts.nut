from "%ui/ui_library.nut" import *
import "%ui/components/faComp.nut" as faComp

from "%ui/fonts_style.nut" import body_txt, h1_txt
from "%ui/profile/profileState.nut" import completedStoryContracts
from "%ui/components/colors.nut" import ControlBg, InfoTextDescColor
from "%ui/components/commonComponents.nut" import mkSelectPanelItem, mkTextArea, mkSelectPanelTextCtor, mkText, mkDescTextarea, VertSelectPanelGap, BD_LEFT
from "%ui/components/formatText.nut" import formatText
from "%ui/components/scrollbar.nut" import makeVertScrollExt, thinAndReservedPaddingStyle
from "%ui/mainMenu/contractWidget.nut" import mkRewardBlock
from "%ui/hud/objectives/objective_components.nut" import getContractProgressionText

#allow-auto-freeze

let iconHeight = hdpxi(20)

let selectedContract = Watched(null)

let contractIcon = faComp("book", {
  fontSize = iconHeight,
  color = InfoTextDescColor
})

function mkStoryContractsTab() {
  function contractsListBlock() {
    let sortedArr = completedStoryContracts.get().sort(@(a, b) a.k <=> b.k)
    return {
      watch = completedStoryContracts
      size = FLEX_H
      flow = FLOW_VERTICAL
      gap = VertSelectPanelGap
      hplace = ALIGN_RIGHT
      onAttach = @() selectedContract.set(sortedArr[0].k)
      children = sortedArr
        .map(function(data) {
          let textCtor = mkSelectPanelTextCtor(loc($"contract/{data.v.name}"), { size = FLEX_H  }.__update(body_txt))
          return mkSelectPanelItem({
            state = selectedContract
            idx = data.k
            border_align = BD_LEFT
            visual_params = {
              size = static [flex(), hdpx(50)]
              xmbNode = XmbNode()
            }
            children = @(params) {
              size = FLEX_H
              flow = FLOW_HORIZONTAL
              gap = static hdpx(5)
              valign = ALIGN_CENTER
              vplace = ALIGN_CENTER
              clipChildren = true
              children = [
                contractIcon
                textCtor(params, data)
              ]
            }
          })
        })
    }
  }

  let leftColumn = {
    size = static [sw(20), flex()]
    color = ControlBg
    flow = FLOW_VERTICAL
    gap = static hdpx(40)
    xmbNode = XmbContainer({
      canFocus = false
      wrap = false
      scrollSpeed = 5.0
    })
    children = [
      makeVertScrollExt(contractsListBlock, {
        size = flex()
        styling = thinAndReservedPaddingStyle
      })
    ]
  }

  function mkContractContent(data) {
    let { name } = data
    return {
      size = FLEX_H
      flow = FLOW_VERTICAL
      gap = static hdpx(16)
      children = [
        mkDescTextarea(getContractProgressionText(data, false), static { color = Color(220,220,250) }.__update(h1_txt))
        mkDescTextarea(loc($"contract/{name}/desc"), body_txt)
        mkRewardBlock(data, 7)
      ]
    }
  }

  function mkContractContentBlock() {
    let selectedContractData = Computed(@() completedStoryContracts.get().findvalue(@(v) v.k == selectedContract.get() ))
    return function () {
      let watch = selectedContractData
      if (selectedContractData.get() == null)
        return { watch }
      let content = mkContractContent(selectedContractData.get().v)
      return {
        watch
        rendObj = ROBJ_SOLID
        size = static [flex(3), flex()]
        color = ControlBg
        padding = static hdpx(10)
        children = makeVertScrollExt(content, { size = flex() })
      }
    }
  }

  let noDataBlock = mkTextArea(loc("journal/contractsEmpty"), {
    halign = ALIGN_CENTER
    vplace = ALIGN_CENTER
  }.__update(body_txt))

  return @() {
    watch = completedStoryContracts
    size = flex()
    flow = FLOW_HORIZONTAL
    gap = static hdpx(10)
    children = completedStoryContracts.get().len() <= 0
      ? noDataBlock
      : [
          leftColumn
          mkContractContentBlock()
        ]
  }
}

return {
  mkStoryContractsTab
}