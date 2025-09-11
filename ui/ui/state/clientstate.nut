from "%ui/ui_library.nut" import *
from "dagor.localize" import getCurrentLanguage, getForceLanguage, setLanguageToSettings
from "app" import get_app_id, hard_reload_overlay_ui_scripts, reinit_localization, reload_overlay_ui_scripts
from "modules" import reset_static_memos
from "settings" import set_setting_by_blk_path, save_settings


const LANGUAGE_BLK_PATH = "language"
let appId = get_app_id()

function initForceLanguage() {
  let forceLanguage = getForceLanguage()
  if (forceLanguage != "")
    setLanguageToSettings(forceLanguage)
}
initForceLanguage()

let gameLanguage = getCurrentLanguage()
let language = Watched(getCurrentLanguage())

function changeLanguage(v){
  language.set(v)
  setLanguageToSettings(v)
  set_setting_by_blk_path(LANGUAGE_BLK_PATH, v)
  save_settings()
  reinit_localization(v)


  hard_reload_overlay_ui_scripts()
}


let nativeLanguageNames = freeze({
  English = "English",
  Russian = "Русский",
  German = "Deutsch"
})


let isChineseLanguage = @() language.get().tolower().contains("chinese")
let isJapaneseLanguage = @() language.get().tolower().contains("japanese")

return freeze({
  appId
  gameLanguage
  language
  availableLanguages = nativeLanguageNames.keys().sort()
  nativeLanguageNames
  LANGUAGE_BLK_PATH
  changeLanguage
  initForceLanguage
  isChineseLanguage
  isJapaneseLanguage
})
