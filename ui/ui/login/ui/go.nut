from "%ui/ui_library.nut" import *

let { h2_txt, body_txt, sub_txt } = require("%ui/fonts_style.nut")
let background = require("background.nut")
let {local_storage} = require("app")
let {YU2_2STEP_AUTH, YU2_WRONG_LOGIN} = require("auth")
let {get_time_msec} = require("dagor.time")
let urlText = require("%ui/components/urlText.nut")
let { save_settings, get_setting_by_blk_path, set_setting_by_blk_path } = require("settings")
let { isInternalCircuit } = require("%sqGlob/appInfo.nut")
let {textInputUnderlined} = require("%ui/components/textInput.nut")
let checkBox = require("%ui/components/checkbox.nut")
let progressText = require("%ui/components/progressText.nut")
let {fontIconButton, textButton} = require("%ui/components/button.nut")
let {safeAreaHorPadding, safeAreaVerPadding} = require("%ui/options/safeArea.nut")
let {exitGameMsgBox} = require("%ui/mainMsgBoxes.nut")
let { showMsgbox, getCurMsgbox, msgboxGeneration } = require("%ui/components/msgbox.nut")
let regInfo = require("reginfo.nut")
let supportLink = require("supportLink.nut")
let {get_arg_value_by_name} = require("dagor.system")
let {showSettingsMenu} = require("%ui/mainMenu/menus/settings_menu.nut")
let {isLoggedIn} = require("%ui/login/login_state.nut")
let {startLogin, currentStage} = require("%ui/login/login_chain.nut")
let loginDarkStripe = require("loginDarkStripe.nut")
let { accentButtonStyle } = require("%ui/components/accentButton.style.nut")


let forgotPasswordUrl = get_setting_by_blk_path("forgotPasswordUrl") ?? "https://login.gaijin.net/ru/sso/forgot"
let forgotPassword  = urlText(loc("forgotPassword"), forgotPasswordUrl, {opacity=0.7}.__update(sub_txt))

const autologinBlkPath = "autologin"
let doAutoLogin = mkWatched(persist, "doAutoLogin", get_setting_by_blk_path(autologinBlkPath) ?? false)

const DUPLICATE_ACTION_DELAY_MSEC = 100 
let AFTER_ERROR_PROCESSED_ID = "after_go_login_error_processed"

let arg_login = get_arg_value_by_name("auth_login")
let arg_password = get_arg_value_by_name("auth_password")
let storedLogin = arg_login ? arg_login : local_storage.hidden.get_value("login")
let storedPassword = arg_password ? arg_password : local_storage.hidden.get_value("password")
let need2Step = mkWatched(persist, "need2Step", false)
local lastLoginCalled = - DUPLICATE_ACTION_DELAY_MSEC
local focusedFieldIdxBeforeExitMsg = -1

isLoggedIn.subscribe(@(_v) need2Step(false))

let formStateLogin = Watched(storedLogin ?? "")
let formStatePassword = Watched(storedPassword ?? "")
let formStateTwoStepCode = Watched(get_arg_value_by_name("two_step") ?? "")
let formStateSaveLogin = Watched(storedLogin != null)
let formStateSavePassword = Watched(storedPassword != null)
let formStateFocusedFieldIdx = Watched(null)
let formStateAutoLogin = Watched(get_setting_by_blk_path(autologinBlkPath) ?? false)

formStateAutoLogin.subscribe(function(v) {
  set_setting_by_blk_path(autologinBlkPath, v)
  save_settings()
})
function availableFields() {
  return [
    formStateLogin,
    formStatePassword,
    (need2Step.get() ? formStateTwoStepCode : null),
    formStateSaveLogin,
    (formStateSaveLogin.get() ? formStateSavePassword : null),
    formStateAutoLogin
  ].filter(@(val) val)
}


function tabFocusTraverse(delta) {
  let tabOrder = availableFields()
  let curIdx = formStateFocusedFieldIdx.get()
  if (curIdx==null)
    set_kb_focus(tabOrder[0])
  else {
    let newIdx = (curIdx + tabOrder.len() + delta) % tabOrder.len()
    set_kb_focus(tabOrder[newIdx])
  }
}
let persistActions = persist("persistActions", @() {})

persistActions[AFTER_ERROR_PROCESSED_ID] <- function(processState) {
  let status = processState?.status
  if (status == YU2_2STEP_AUTH) {
    need2Step(true)
    formStateTwoStepCode("")
    set_kb_focus(formStateTwoStepCode)
  }
  else if (status == YU2_WRONG_LOGIN) {
    set_kb_focus(formStateLogin)
    anim_start(formStateLogin)
  }
}
formStateLogin.subscribe(@(_) need2Step(false))
function doPasswordLogin() {
  if (currentStage.get()!=null) {
    log($"Ignore start login due current loginStage is {currentStage.get()}")
    return
  }
  let curTime = get_time_msec()
  if (curTime < lastLoginCalled + DUPLICATE_ACTION_DELAY_MSEC) {
    log("Ignore start login due duplicate action called")
    return
  }

  lastLoginCalled = curTime
  local isValid = true
  foreach (f in availableFields()) {
    if (typeof(f.get())=="string" && !f.get().len()) {
      anim_start(f)
      isValid = false
    }
  }
  if (isValid) {
    let twoStepCode = need2Step.get() ? formStateTwoStepCode.get() : null
    startLogin({
      login_id = formStateLogin.get(),
      password = formStatePassword.get(),
      saveLogin = !doAutoLogin.get() && formStateSaveLogin.get(),
      savePassword = !doAutoLogin.get() && formStateSavePassword.get() && formStateSaveLogin.get(),
      two_step_code = twoStepCode
      needShowError = @(processState) processState?.status != YU2_2STEP_AUTH
      afterErrorProcessed = @(processState) persistActions[AFTER_ERROR_PROCESSED_ID](processState)
    })
  }
}

function onMessageBoxChange(_) {
  if (!getCurMsgbox() && focusedFieldIdxBeforeExitMsg!=-1) {
    let fields = availableFields()
    if (focusedFieldIdxBeforeExitMsg in fields)
      set_kb_focus(fields[focusedFieldIdxBeforeExitMsg])
    focusedFieldIdxBeforeExitMsg = -1
  }
}

function showExitMsgBox(){
  focusedFieldIdxBeforeExitMsg = formStateFocusedFieldIdx.get()
  set_kb_focus(null)
  exitGameMsgBox()
}

function makeFormItemHandlers(field, debugKey=null, idx=null) {
  return {
    onFocus = @() formStateFocusedFieldIdx.update(idx)
    onBlur = @() formStateFocusedFieldIdx.update(null)
    onEscape = @() showExitMsgBox()
    onAttach = function(elem) {
      if (getCurMsgbox() != null)
        return
      let focusOn = need2Step.get() ? formStateTwoStepCode
            : ((formStatePassword.get()=="" && formStateLogin.get()!="") ? formStatePassword : formStateLogin)
      if (field == focusOn)
        set_kb_focus(elem)
    }

    onReturn = function() { log("Start Login from text field", debugKey); doPasswordLogin() }
  }
}


function formText(field, options={}, idx=null) {
  return textInputUnderlined(field, options.__merge(makeFormItemHandlers(field, options?.title, idx)))
}

let capslockText = {rendObj = ROBJ_TEXT text="Caps Lock" color = Color(50,200,255)}
let capsDummy = {rendObj = ROBJ_TEXT text=null}
function capsLock() {
  let children = (gui_scene.keyboardLocks.get() & KBD_BIT_CAPS_LOCK) ? capslockText : capsDummy
  return {
    watch = gui_scene.keyboardLocks
    size = SIZE_TO_CONTENT
    hplace = ALIGN_CENTER
    children = children
  }
}

let keyboardLangColor = Color(100,100,100)
function keyboardLang(){
  local text = gui_scene.keyboardLayout.get()
  if (type(text)=="string")
    text = text.slice(0,5)
  else
    text = ""
  return {
    watch = gui_scene.keyboardLayout
    rendObj = ROBJ_TEXT text=text color=keyboardLangColor  hplace=ALIGN_RIGHT vplace=ALIGN_CENTER padding=[0,hdpx(5),0,0]
  }
}

function formPwd(field, options={}, idx=null) {
  return {
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_VERTICAL
    children = [
      {
        size = [flex(), SIZE_TO_CONTENT]
        children = [
          textInputUnderlined(field, options.__merge(makeFormItemHandlers(field, options?.debugKey, idx)))
          keyboardLang
        ]
      }
      capsLock
    ]
  }
}
let formCheckbox = @(field, options={}, idx=null) checkBox(field,
      options.title, makeFormItemHandlers(field, options?.title, idx))


let loginBtn = textButton(loc("Login"),
  function() {
    log("Start Login by login btn");
    if (!isInternalCircuit.get()) {
      showMsgbox({
        text = loc("cbtDisclaimer")
        onClose = doPasswordLogin
      })
    }
    else
      doPasswordLogin()
  },
  { size = [flex(), hdpx(70)], halign = ALIGN_CENTER, margin = 0
    hotkeys = [["^J:Y", { description = { skip = true }}]]
    sound = {
      click = "ui_sounds/menu_enter"
      hover = "ui_sounds/menu_highlight"
    }
  }.__update(accentButtonStyle, h2_txt)
)

let hotkeysRootChild = {hotkeys = [["^Tab", @() tabFocusTraverse(1)], ["^L.Shift Tab | R.Shift Tab", @() tabFocusTraverse(-1)],
  ["^Esc", @() showExitMsgBox()]]}

function createLoginForm() {
  let logo = {
    vplace = ALIGN_TOP
    rendObj = ROBJ_IMAGE
    keepAspect = true
    size = [ flex(), hdpx(100) ]
    image = Picture("!ui/uiskin/amLogo.svg:{0}:{1}:K".subst(512, 128))
  }

  let loginOptions = [
    {t = formText, w = formStateLogin, p = {placeholder=loc("login (e-mail)"), inputType="mail", title="login", showPlaceHolderOnFocus=true}.__update(body_txt)},
    {t = formPwd, w = formStatePassword, p = {placeholder=loc("password"), password="\u2022", title="password", showPlaceHolderOnFocus=true}.__update(body_txt)},
    need2Step.get() ? {t=formText, w = formStateTwoStepCode, p = { placeholder=loc("2 step code"), title="twoStepCode", showPlaceHolderOnFocus=true}.__update(body_txt)} : null,
    {t = formCheckbox, w = formStateSaveLogin, p = {title=loc("Store login (e-mail)")}},
    formStateSaveLogin.get() ? {t = formCheckbox, w = formStateSavePassword, p = {title=loc("Store password (this is unsecure!)")}} : null
  ].filter(@(v) v!=null).map(@(v, idx) v.t(v.w, v.p, idx))
  loginOptions.append(forgotPassword)
  return [
    logo
    @() {
      flow = FLOW_VERTICAL
      vplace = ALIGN_CENTER
      size = [ flex(), SIZE_TO_CONTENT ]
      children = loginOptions
      watch = formStateSaveLogin
    }
    {
      vplace = ALIGN_BOTTOM
      halign = ALIGN_CENTER
      size = [flex(), SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      gap = hdpx(10)
      children = currentStage.get() == null ? loginBtn : null
    }
    regInfo
    hotkeysRootChild
  ]
}

function loginRoot() {
  let watch = [currentStage, need2Step, formStateSaveLogin,
    isLoggedIn]
  let children = (currentStage.get() || isLoggedIn.get())
    ? [progressText(loc("loggingInProcess"))]
    : createLoginForm()
  return {
    watch
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    size = [fsh(40), fsh(55)]
    pos = [-sw(15), -sh(5)]
    hplace = ALIGN_RIGHT
    vplace = ALIGN_CENTER
    function onAttach() {
      msgboxGeneration.subscribe(onMessageBoxChange)
      if (doAutoLogin.get()) {
        doAutoLogin.set(false)
        doPasswordLogin()
      }
    }
    function onDetach() {
       msgboxGeneration.unsubscribe(onMessageBoxChange)
    }
    children
  }
}

let enterHandler = @(){
  hotkeys = [["^Enter", function() {
  if ((formStateLogin.get() ?? "").len()>1 && (formStatePassword.get() ?? "").len()>1)
    doPasswordLogin()
  }]]
}
return @() {
  size = flex()
  children = [
    background
    loginDarkStripe
    enterHandler
    loginRoot
    supportLink
    {
      flow = FLOW_HORIZONTAL
      hplace = ALIGN_RIGHT
      margin = [fsh(2)+safeAreaVerPadding.get(), safeAreaHorPadding.get()+fsh(2)]
      gap  = hdpx(2)
      children = [
        fontIconButton("icon_buttons/sett_btn.svg", @() showSettingsMenu.modify(@(v) !v) )
        fontIconButton("icon_buttons/eac_btn.svg", showExitMsgBox )
      ]
    }
  ]
}

