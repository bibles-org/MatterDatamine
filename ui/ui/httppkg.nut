from "%dngscripts/platform.nut" import platformId
from "%ui/state/clientState.nut" import gameLanguage

let platformMap = {
  win32 = "pc"
  win64 = "pc"
}

let languageMap = {
  Russian = "ru"
  English = "en"
  French = "fr"
  Italian = "it"
  German = "de"
  Spanish = "es"
  Korean = "ko"
  Japanese = "jp"
  Chinese = "zh"
  Polish = "pl"
  HChinese = "cn"
}

return {
  getPlatformId = @() platformMap?[platformId] ?? platformId
  getLanguageId = @() languageMap?[gameLanguage] ?? languageMap.English
}
