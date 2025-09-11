from "%ui/fonts_style.nut" import h2_txt, body_txt
from "%ui/components/colors.nut" import InfoTextValueColor
from "%ui/components/itemIconComponent.nut" import itemIconNoBorder
from "%ui/components/commonComponents.nut" import mkText
from "%ui/components/msgbox.nut" import showMessageWithContent
from "%ui/mainMenu/currencyIcons.nut" import creditsTextIcon, monolithTokensTextIcon, premiumColor,
  premiumCreditsTextIcon, creditsColor, monolithTokensColor
from "%ui/mainMenu/currencyPanel.nut" import currencyPanel, showNotEnoghPremiumMsgBox
import "%ui/components/colorize.nut" as colorize
from "%ui/components/accentButton.style.nut" import accentButtonStyle

from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs


function mkPurchaseIcon(item) {
  let { templateName = null } = item
  let itemIcon = freeze(itemIconNoBorder(templateName,
    {
      width = static hdpxi(300)
      height = static hdpxi(300)
      shading = "full"
      vplace = ALIGN_CENTER
    }))
  return itemIcon
}

function showCurrencyPurchaseMsgBox(params) {
  let { name, price = null, cb = null, currency = null, icon = null, item = null, buttons = null, customPrice = null } = params
  let yesNoButtons = [
    {
      text = loc("Yes")
      action = cb
      isCurrent = true
      customStyle = { textParams = { rendObj = ROBJ_TEXTAREA, behavior = Behaviors.TextArea } }.__merge(accentButtonStyle)
    },
    {
      text = loc("No")
      isCancel = true
    }
  ]
  showMessageWithContent({
    content = {
      size = [sw(80), SIZE_TO_CONTENT]
      children = [
        {
          hplace = ALIGN_RIGHT
          pos = static [0, -hdpx(40)]
          flow = FLOW_HORIZONTAL
          gap = static hdpx(12)
          children = currencyPanel
        }
        {
          size = FLEX_H
          flow = FLOW_VERTICAL
          gap = hdpx(20)
          halign = ALIGN_CENTER
          children = [
            {
              rendObj = ROBJ_TEXTAREA
              size = FLEX_H
              behavior = Behaviors.TextArea
              halign = ALIGN_CENTER
              text = (loc("shop/wantPurchaseMsg", { purchase = colorize(InfoTextValueColor, name) }))
            }.__merge(h2_txt)
            icon ?? mkPurchaseIcon(item)
            customPrice ?? function() {
              local color = premiumColor
              local currencyIcon = premiumCreditsTextIcon
              if (currency == "monolith") {
                color = monolithTokensColor
                currencyIcon = monolithTokensTextIcon
              }
              else if (currency == "credits") {
                color = creditsColor
                currencyIcon = creditsTextIcon
              }
              return {
                rendObj = ROBJ_TEXTAREA
                size = FLEX_H
                behavior = Behaviors.TextArea
                halign = ALIGN_CENTER
                text = $"{loc("price")} {colorize(color, currencyIcon)}{price}"
              }.__merge(body_txt)
              }
          ]
        }
      ]
    }
    buttons = buttons ?? yesNoButtons
  })
}

return {
  showCurrencyPurchaseMsgBox
  showNotEnoghPremiumMsgBox
}
