from "%ui/ui_library.nut" import *

let { body_txt, h1_txt } = require("%ui/fonts_style.nut")
let { addModalWindow, removeModalWindow } = require("%ui/components/modalWindows.nut")
let { textButton } = require("%ui/components/button.nut")
let { mkText, mkTextArea } = require("%ui/components/commonComponents.nut")
let { change_gamma, is_hdr_enabled } = require("videomode")
let { getOnlineSaveData, optionSlider } = require("%ui/mainMenu/menus/options/options_lib.nut")
let { activeMatterIcon } = require("%ui/mainMenu/currencyIcons.nut")
let { get_setting_by_blk_path, set_setting_by_blk_path_and_save } = require("settings")
let { isLoggedIn } = require("%ui/login/login_state.nut")
let { InfoTextValueColor } = require("%ui/components/colors.nut")
let { argv } = require("dagor.system")

let app_is_test_mode = @() argv.contains("-skip_modals_on_start")

const WND_UID = "gammaCorrectionWnd"
const HAS_FIRST_LAUCH_GAMMA_SETTING = "hadFirstLaunchGammaSetting"

let hasAlreadySetGamma = @() get_setting_by_blk_path(HAS_FIRST_LAUCH_GAMMA_SETTING) ?? false

let saveAndCloseBtn = textButton(loc("Ok"), function() {
  removeModalWindow(WND_UID)
  set_setting_by_blk_path_and_save(HAS_FIRST_LAUCH_GAMMA_SETTING, true)
})

let logoSize = hdpxi(300)
let logoColors = Watched([Color(5, 5, 5), Color(100, 100, 100), Color(200, 200, 200)])

let gammaCorrectionSave = getOnlineSaveData("graphics/gamma_correction", @() 1.0, @(p) clamp(p, 0.5, 1.5))

let logos = @() {
  watch = logoColors
  flow = FLOW_HORIZONTAL
  gap = hdpx(30)
  vplace = ALIGN_CENTER
  hplace = ALIGN_CENTER
  children = logoColors.get().map(@(v) activeMatterIcon(logoSize, { color = v }))
}

let option = optionSlider({
  name = loc("options/gamma_correction", "Gamma correction")
  isAvailable = @() !is_hdr_enabled()
  blkPath = "graphics/gamma_correction"
  var = gammaCorrectionSave.watch
  setValue = function(v) {
      gammaCorrectionSave.setValue(v)
      change_gamma(v)
    }
  defVal = 1.0
  min = 0.5 max = 1.5 unit = 0.05 pageScroll = 0.05
  hint = loc("guiHints/gamma_correction")
}, null, {})

let mkOptionValueText = @() {
  watch = gammaCorrectionSave.watch
  children = mkText(gammaCorrectionSave.watch.get(), { color = InfoTextValueColor }.__update(body_txt))
}

let settingBlock = {
  size = [hdpx(800), hdpx(130)]
  hplace = ALIGN_CENTER
  flow = FLOW_VERTICAL
  gap = { size = flex() }
  halign = ALIGN_CENTER
  children = [
    mkTextArea(loc("settings/gammaCorrection"), { halign = ALIGN_CENTER }.__update(body_txt))
    option
    mkOptionValueText
  ]
}

function openGammaSettingWindow() {
  if (is_hdr_enabled())
    return
  return addModalWindow({
    rendObj = ROBJ_SOLID
    size = flex()
    key = WND_UID
    color = 0xFF000000
    gap = hdpx(10)
    padding = fsh(5)
    onClick = @() null
    eventPassThrough = true
    halign = ALIGN_CENTER
    children = [
      mkText(loc("options/gamma_correction"), h1_txt)
      logos
      {
        flow = FLOW_VERTICAL
        gap = hdpx(60)
        vplace = ALIGN_BOTTOM
        hplace = ALIGN_CENTER
        halign = ALIGN_CENTER
        children = [
          settingBlock
          saveAndCloseBtn
        ]
      }
    ]
  })
}

console_register_command(openGammaSettingWindow, "ui.openGammaSettingWnd")
console_register_command(@(colorInt1, colorInt2, colorInt3) logoColors.set([colorInt1, colorInt2, colorInt3]), "ui.setGammaImageColors")

isLoggedIn.subscribe(function(v) {
  if (v && !app_is_test_mode() && !hasAlreadySetGamma())
    openGammaSettingWindow()
})

return {
  hasAlreadySetGamma
  openGammaSettingWindow
}
