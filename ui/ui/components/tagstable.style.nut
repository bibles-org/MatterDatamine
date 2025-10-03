from "%ui/ui_library.nut" import *
from "%ui/components/colors.nut" import InfoTextValueColor, DangerTextValueColor, GreenSuccessColor
from "%ui/mainMenu/currencyIcons.nut" import premiumColor

let defaultTagsTable = freeze({
  accented = { color = InfoTextValueColor }
  danger = { color = DangerTextValueColor }
  safe = { color = GreenSuccessColor }
  reddoor = { color = Color(228, 72, 68) }
  bluedoor = { color = Color(68, 72, 228) }
  premiumColor = { color = premiumColor }
})

return {
  defaultTagsTable
}
