from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { h2_txt, fontawesome, body_txt, sub_txt, tiny_txt } = require("%ui/fonts_style.nut")
let { mkSelectPanelItem, mkSelectPanelTextWithFaIconCtor, mkSelectPanelTextCtor, mkPanel, mkTitleString, fontIconButton,
  mkHelpConsoleScreen, mkText, VertSelectPanelGap, BD_LEFT, mkTextArea, textButton
} = require("%ui/components/commonComponents.nut")
let { mkCloseBtn, mkHelpButton, mkBackBtn } = require("stdPanel.nut")
let { isOnboarding } = require("%ui/hud/state/onboarding_state.nut")
let { EventShowItemInShowroom, EventActivateShowroom, EventCloseShowroom, EventUIMouseMoved, EventUIMouseWheelUsed, CmdShowUiMenu } = require("dasevents")
let { Point2 } = require("dagor.math")
let { safeAreaAmount } = require("%ui/options/safeArea.nut")
let { selectedItem, selectedItemsCategory } = require("%ui/mainMenu/market/marketState.nut")
let { makeVertScroll, makeVertScrollExt } = require("%ui/components/scrollbar.nut")
let { marketItems, cleanableItems, playerStats, playerProfileCreditsCount,
      playerProfileMonolithTokensCount } = require("%ui/profile/profileState.nut")
let { itemIconNoBorder } = require("%ui/components/itemIconComponent.nut")
let fa = require("%ui/components/fontawesome.map.nut")
let { ItemIconBlocked, TextNormal, InfoTextValueColor, InfoTextDescColor, SelBgNormal, SelBdNormal
  BtnBgNormal, BtnBgSelected, RedWarningColor, GreenSuccessColor } = require("%ui/components/colors.nut")
let marketCategories = require("%ui/mainMenu/categories/marketCategories.nut")
let { addTabToDevInfo } = require("%ui/devInfo.nut")
let { creditsTextIcon, monolithTokensTextIcon } = require("%ui/mainMenu/currencyIcons.nut")
let { itemDescriptionStrings } = require("%ui/components/itemDescription.nut")
let { sound_play } = require("%dngscripts/sound_system.nut")
let { setTooltip } = require("%ui/components/cursors.nut")
let { onSoldierFacompIcon, inStashFacompIcon, inCartFacompIcon
} = require("%ui/components/inventoryTypeIcons.nut")
let faComp = require("%ui/components/faComp.nut")
let { eventbus_send, eventbus_subscribe } = require("eventbus")
let { showNoEnoughStashSpaceMsgbox } = require("%ui/mainMenu/stashSpaceMsgbox.nut")
let { mkAttachedChar } = require("%ui/hud/state/item_info.nut")
let { showMessageWithContent, showMsgbox } = require("%ui/components/msgbox.nut")
let { equipment } = require("%ui/hud/state/equipment.nut")
let { weaponsList } = require("%ui/hud/state/hero_weapons.nut")
let { inventoryItems, stashItems, backpackItems } = require("%ui/hud/state/inventory_items_es.nut")
let { floor, truncateToMultiple } = require("%sqstd/math.nut")
let { favoriteItems } = require("%ui/mainMenu/market/marketFavorites.nut")
let { textInput } = require("%ui/components/textInput.nut")
let { button } = require("%ui/components/button.nut")
let { utf8ToLower } = require("%sqstd/string.nut")
let tooltipBox = require("%ui/components/tooltipBox.nut")
let { mkRarityCorner, getRarityColor } = require("%ui/hud/menus/components/inventoryItemRarity.nut")
let { MonolithMenuId, monolithSelectedLevel, selectedMonolithUnlock, monolithLevelOffers, currentMonolithLevel } = require("%ui/mainMenu/monolith/monolith_common.nut")
let checkBox = require("%ui/components/checkbox.nut")
let { customFilter, weaponRelated, getItemTemplate,
      equipmentRelated, getTemplateType } = require("%ui/mainMenu/market/marketItems.nut")
let { backpackEid, safepackEid, backpackUniqueId, safepackUniqueId } = require("%ui/hud/state/hero_extra_inventories_state.nut")
let { controlledHeroEid } = require("%ui/hud/state/controlled_hero.nut")
let { is_inventory_have_free_volume, ceil_volume } = require("das.inventory")
let { stashEid, stashVolume, stashMaxVolume } = require("%ui/state/allItems.nut")
let { addPlayerLog, mkPurchaseLogData, mkPlayerLog, removePlayerLog, playerLogsColors
} = require("%ui/popup/player_event_log.nut")
let { marketAnimChildren, marketGlareAnim } = require("%ui/components/glareAnimation.nut")
let { accentButtonStyle } = require("%ui/components/accentButton.style.nut")
let spinner = require("%ui/components/spinner.nut")
let { nestWatched } = require("%dngscripts/globalState.nut")
let { isInBattleState } = require("%ui/state/appState.nut")
let { currencyPanel } = require("%ui/mainMenu/currencyPanel.nut")
let { isLotAvailable } = require("%ui/mainMenu/market/inventoryToMarket.nut")

function patchItemType(item, key) {
  if (item.itemType == "")
    item.itemType = getTemplateType(item.children?.items[0].templateName)

  item["id"] <- key

  return item
}

let sectionToReturn = Watched(null)
let buyInProgress = Watched(false)
let currentAnimationId = Watched(null)
let shoppingCartItems = nestWatched("shoppingCartItems", {})
let needToCleanCart = Watched(false)
let priceAnimGen = Watched(0)
let tblScrollHandler = ScrollHandler()
let hiddenCategories = [ "chronogene" ]
let itemRowHeight = hdpxi(44)
let iconSize = [hdpxi(80), hdpxi(40)]
let svgIconSize = hdpxi(20)
let itemsGap = VertSelectPanelGap
let vertHap = freeze({size=[hdpx(2), flex()], rendObj = ROBJ_SOLID color=BtnBgNormal opacity=0.8})
let priceAnimData = []
let getPriceAnimData = @() clone priceAnimData
const PRICE_ANIM_DURATION = 0.8
local animCounter = 0

let mkItemKey = @(uid) $"mkBuyItemRow_{uid}"
isInBattleState.subscribe(@(_v) shoppingCartItems.modify(@(_items) {}))

let progressPurchaseLog = {
  idToIgnore = "purchaseProgress"
  id = "purchaseProgress"
  content = mkPlayerLog({
    titleText = loc("xbox/waitingMessage")
    bodyText = loc("shop/inProgress")
    logColor = playerLogsColors.infoLog
  })
  sound = "ui_sounds/access_denied"
}

let mkNoMonotithTokensLog = @(monolithUnlockToSend) {
  id = monolithUnlockToSend
  content = mkPlayerLog({
    titleText = loc("market/transactionDeclined")
    bodyIcon = itemIconNoBorder("monolith_credit_coins_pile", { width = hdpxi(40), height = hdpxi(40) })
    bodyText = loc("monolith/notEnoughMonolithTokensLog")
    logColor = playerLogsColors.warningLog
  })
}

function setPurchaseNotInProgress() {
  buyInProgress.set(false)
  anim_skip(currentAnimationId.get())
  currentAnimationId.set(null)
  removePlayerLog("purchaseProgress")
  if (needToCleanCart.get()) {
    shoppingCartItems.modify(@(_items) {})
    needToCleanCart.set(false)
  }
}

addTabToDevInfo("marketItems", marketItems, @"console commands:
    profile.unlock_all_shop -- unlock all items in shop until first 'profile.load'
    profile.force_set_credits_count 1000000 -- set credits to shopping
    profile.force_set_monolith_credits_count 1000000 -- set monolith credits to shopping
")

addTabToDevInfo("cleanableItems", cleanableItems)

eventbus_subscribe("profile_server.buyLots.needMoreStashSpace", function(result) {
  if (result?.need_more_space) {
    setPurchaseNotInProgress()
    showNoEnoughStashSpaceMsgbox(result.need_more_space)
  }
})

eventbus_subscribe("profile_server.buyLots.result", function(res) {
  setPurchaseNotInProgress()
  let { inventory_diff = null, bought_items = null } = res
  if (inventory_diff == null || bought_items == null)
    return
  let itemsData = {}
  foreach (diff in inventory_diff) {
    let sorted = diff.sort(@(a, b) a?.parentItemId <=> b?.parentItemId)
    foreach (item in sorted) {
      let { templateName = null, itemId = null, parentItemId = "0" } = item
      if (templateName == null || itemId == null)
        continue
      if (!bought_items.contains(itemId.tostring()))
        continue
      if (parentItemId != "0" && parentItemId in itemsData) {
        itemsData[parentItemId].__update({
          slotToPurchase = itemsData[parentItemId]?.slotName
          attachments = (itemsData[parentItemId]?.attachments ?? []).append(templateName) }) 
      }
      else
        itemsData[itemId] <- {
          templateName
          slotName = item?.slotName
        }
    }
  }

  itemsData.each(@(v) addPlayerLog({
    id = v.templateName
    content = mkPlayerLog(mkPurchaseLogData(v.templateName, v?.attachments ?? [], v?.slotName))
  }))
})

function removePriceAnimation(id) {
  let idx = priceAnimData.findindex(@(p) p.id == id)
  if (idx == null)
    return
  priceAnimData.remove(idx)
  priceAnimGen.modify(@(v) v + 1)
}

function addPriceAnimation(config) {
  config.visibleIdx <- Watched(-1)
  config.visibleIdx.subscribe(function(_newVal) {
    config.visibleIdx.unsubscribe(callee())
    gui_scene.setInterval(PRICE_ANIM_DURATION,
      function() {
        gui_scene.clearTimer(callee())
        removePriceAnimation(config.id)
      })
    })

  priceAnimData.append(config)
  priceAnimGen.modify(@(v) v + 1)
}

function priceAnimationBlock() {
  let children = []
  let anims = getPriceAnimData()
  foreach(idx, anim in anims) {
    let { id, visibleIdx, price, targetRect } = anim
    let prevVisIdx = visibleIdx.get()
    let curVisIdx = anims.len() - idx
    if (prevVisIdx != curVisIdx) {
      let prefix = curVisIdx > prevVisIdx ? "playerLogMoveTop" : "playerLogMoveBottom"
      anim_start(prefix + id)
    }
    let { r, t } = targetRect
    children.append({
      key = $"amim_{id}"
      size = [0, 0]
      pos = [r + hdpx(24), t + hdpx(6)]
      transform = {}
      behavior = Behaviors.RecalcHandler
      onRecalcLayout = @(_initial) visibleIdx.set(curVisIdx)
      opacity = 0
      animations = [
        { prop = AnimProp.translate, from = [0, 0], to = [hdpx(100), -hdpx(50)], duration = 0.8,
          play = true, easing = OutCubic
        }
        { prop = AnimProp.opacity, from = 1, to = 0, duration = 0.8, play = true, easing = OutCubic }
      ]
      children = mkText($"{creditsTextIcon}{price}")
    })
  }

  return {
    watch = priceAnimGen
    children = children
  }
}

let mkPurchaseIcon = @(iconName, override = {}) {
  rendObj = ROBJ_IMAGE
  size = [svgIconSize, svgIconSize]
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
  color = TextNormal
  image = Picture($"ui/skin#market/{iconName}.svg:{svgIconSize}:{svgIconSize}:K")
}.__update(override)

let subTitleStyle = freeze({
  size = [flex(), itemRowHeight]
  behavior = [Behaviors.Marquee, Behaviors.Button]
  valign = ALIGN_CENTER
  speed = hdpx(75)
  scrollOnHover = true
})

let mkSubTitle = @(text) mkPanel(mkTitleString(text).__update({margin=0}, body_txt), subTitleStyle)

const Market_id = "Market"
let closeBtn = mkCloseBtn(Market_id)

let marketScreenName = loc("market/name")
let help_data = {
  content = "market/helpContent"
}

let avaliableBuyCategories = Computed(function() {
  let isAdmin = (playerStats.get()?.unlocks ?? []).findindex(@(v) v == "__ADMIN__") != null

  let merketItemsVal = marketItems.get()
  let categories = []
  categories.append("favoriteItems")
  foreach (item in merketItemsVal) {
    if ((item.children?.items.len() ?? 0)== 0)
      continue
    let tp = getTemplateType(item.children.items[0].templateName)

    if (!isAdmin && hiddenCategories.findindex(@(v) v == tp) != null) 
      continue

    if ((item?.buyable ?? false) && categories.findindex(@(v) v==tp) == null)
      categories.append(tp)
  }
  categories.sort(@(a, b) (marketCategories?[a]?.idx ?? 1000) <=> (marketCategories?[b]?.idx ?? 1000))
  categories.append("presets")
  if (customFilter.get().filterToUse == null)
    categories.append("cart")
  return categories
})

function getDefaultCategory() {
  if (avaliableBuyCategories.get().findindex(@(v) v == "weapons") != null)
    return "weapons"
  if (favoriteItems.get().len() != 0)
    return "favoriteItems"
  return "presets"
}

function marketSorting(a, b) {
  return a.itemType <=> b.itemType ||
    a.reqMoney <=> b.reqMoney
}

let textFilter = Watched("")
let itemToScroll = Watched(null)
let showOnlyAvailableOffers = Watched(false)
let selectedItemByCategory = {}
local oldCategory = selectedItemsCategory.get()

let notFoundStub = @() {
  watch = selectedItemsCategory
  size = flex()
  flow = FLOW_VERTICAL
  valign = ALIGN_CENTER
  halign = ALIGN_CENTER
  gap = hdpx(20)
  children = [
    {
      rendObj = ROBJ_INSCRIPTION
      font = fontawesome.font
      text = fa["search"]
      fontSize = itemRowHeight
    }
    {
      rendObj = ROBJ_TEXT
      text = selectedItemsCategory.get() == "favoriteItems" ? loc("shop/favoritesEmpty")
        : selectedItemsCategory.get() == "cart" ? loc("shop/cartEmpty")
        : loc("shop/noItem")
    }.__update(h2_txt)
  ]
}

let mkCategoryPanel = memoize(function(category, filtereditems) {
  let group = ElemGroup()
  let children = function(p) {
    let params = p.__merge({group})
    return @() {
      size = [ flex(), SIZE_TO_CONTENT ]
      halign = ALIGN_CENTER
      behavior = Behaviors.Marquee
      speed = [hdpx(90),0]
      delay = 0.1
      scrollOnHover = true
      group
      children = category != "cart"
        ? mkSelectPanelTextWithFaIconCtor(marketCategories?[category].faIcon ?? "bug", loc($"marketCategory/{category}"))(params)
        : function() {
            let count = shoppingCartItems.get().reduce(@(res, v) res += (v?.count ?? 1), 0)
            let title = loc($"marketCategory/{category}")
            return {
              watch = shoppingCartItems
              children = mkSelectPanelTextWithFaIconCtor(marketCategories?[category].faIcon ?? "bug", $"{title} ({count})")(params)
            }
          }
       }
  }
  return @() {
    watch = customFilter
    size = [flex(), SIZE_TO_CONTENT]
    children = mkSelectPanelItem({
      children,
      state = selectedItemsCategory,
      idx = category,
      group,
      disabled = customFilter.get().filterToUse != null
      visual_params = const {
        padding = hdpx(8)
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        size = [flex(), SIZE_TO_CONTENT]
        clipChildren = true
      }
      cb = function(_) {
        let curCategory = selectedItemsCategory.get()
        let itemStillExists = filtereditems.get().findvalue(@(_val, id) id == selectedItemByCategory?[curCategory])!=null
        if (oldCategory!=null)
          selectedItemByCategory[oldCategory] <- selectedItem.get()
        if (curCategory in selectedItemByCategory && itemStillExists)
          selectedItem.set(selectedItemByCategory?[curCategory])
        else {
          let firstItem = filtereditems.get()?[0].id
          selectedItem.set(firstItem)
        }
        oldCategory = curCategory
        itemToScroll.set(selectedItem.get())
      }
    })
  }
})

let buyPanelHeader = @(filtereditems) @() {
  watch = avaliableBuyCategories
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_HORIZONTAL
  gap = vertHap
  children = avaliableBuyCategories.get().map(@(v) mkCategoryPanel(v, filtereditems))
}

function getItemLoc(item){
  let template = getItemTemplate(item?.templateName)
  let itemName = loc(template?.getCompValNullable("item__name") ?? "unknown")
  return itemName
}

let getItemName = @(item) item.offerName != "" ? loc($"marketOffer/{item.offerName}") : getItemLoc(item.children.items[0])
let itemTextStyle = {
  size = flex()
  behavior = [Behaviors.Marquee, Behaviors.DragAndDrop]  
  hplace = ALIGN_LEFT
  valign = ALIGN_CENTER
  clipChildren = true
  delay = 0.5
  speed = [hdpx(50),hdpx(600)]
  scrollOnHover = true
}.__update(body_txt)

function mkItemNameCtor(item) {
  let textCtor = mkSelectPanelTextCtor(getItemName(item), itemTextStyle)
  return @(params) {
    size = const flex()
    margin = const [0, hdpx(4)]
    children = textCtor(params)
  }
}

function convertToShort(value) {
  if (value < 500)
    return value
  else if (value < 10000)
    return $"{floor(value / 100.0) / 10.0}k"
  else if (value < 100000)
    return $"{floor(value / 1000.0)}k"
  else
    return "99+k"
}

let favButtonStyle = freeze({
  BtnBgNormal = SelBgNormal
})
let favButtonStyleFav = freeze(favButtonStyle.__merge({
  TextNormal = SelBdNormal
}))

function mkFavoriteButton(lot) {
  let isFavorite = Computed(function() {
    return favoriteItems.get().findindex(@(v) v == lot) != null
  })


  function onClick() {
    if (isFavorite.get()) {
      favoriteItems.mutate(@(v) v.remove(v.findindex(@(v2) v2 == lot)))
    }
    else {
      favoriteItems.mutate(@(v) v.append(lot))
    }
  }
  let defparams = const { fontSize = hdpxi(16) size = flex() borderWidth = 0}
  return @() {
    watch = isFavorite
    size = const [ hdpx(20), flex() ]
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER

    children = fontIconButton(
      isFavorite.get() ? "star" : "star-o", onClick
      isFavorite.get()
        ? const defparams.__merge({style = favButtonStyleFav})
        : const defparams.__merge({favButtonStyle})
    )
  }
}

function countItems(itemList, item, isBoxed) {
  local count = 0

  foreach (inventoryItem in itemList) {
    if (!inventoryItem?.eid)
      continue

    let marketTemplate = item.children.items[0].templateName
    if (!marketTemplate)
      continue

    let itemTemplate = inventoryItem?.itemTemplate

    
    foreach (mod in (inventoryItem?.modInSlots ?? {})) {
      let modTemplate = mod?.itemTemplate
      if (mod?.eid && marketTemplate == modTemplate)
        count += 1
    }

    
    if (inventoryItem?.ammo.template && inventoryItem.ammo.template == marketTemplate)
        count += inventoryItem?.curAmmo ?? 0

    
    if (marketTemplate == itemTemplate)
      count += isBoxed ? (inventoryItem?.ammoCount ?? 0) : 1
  }

  return count
}

function countItemsInCart(itemList, id) {
  if (id == null)
    return 0
  if (id in itemList)
    return itemList[id]?.count ?? 1
  return 0
}


function mkExistSection(item) {
  let templ = getItemTemplate(item.children.items[0].templateName)
  let isBoxed = templ?.getCompValNullable("item__countPerStack")

  let stashCount = Computed(@() countItems(stashItems.get(), item, isBoxed))
  let { id } = item

  let onMeItemCount = Computed(@() countItems(equipment.get(), item, isBoxed)
    + countItems(weaponsList.get(), item, isBoxed)
    + countItems(backpackItems.get(), item, isBoxed)
    + countItems(inventoryItems.get(), item, isBoxed))

  let cartItemCount = Computed(@() countItemsInCart(shoppingCartItems.get(), id))

  let existColor = InfoTextDescColor
  let emptyColor = const Color(50, 50, 50)
  let defP = const {fontSize = hdpx(15) halign = ALIGN_CENTER}
  let mkRow = @(fac, txt, count) {
    behavior = Behaviors.Button
    onHover = @(on) setTooltip(on ? txt : null)
    rendObj = ROBJ_SOLID
    color = SelBgNormal
    flow = FLOW_VERTICAL
    gap = itemsGap
    size = const [ hdpx(35), flex() ]
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    padding = hdpx(15)
    children = [
      faComp(fac, count ? defP.__merge({color = existColor}) : defP.__merge({color=emptyColor}))
      const { size = [ 0, flex() ] }
      mkText($"{count ? count : "-"}", count ? const {color = existColor}.__update(tiny_txt) : const {color = emptyColor}.__update(tiny_txt))
    ]
  }
  let content = @(){
    watch = [stashCount, onMeItemCount, cartItemCount, selectedItemsCategory, customFilter]
    flow = FLOW_HORIZONTAL
    size = const [ SIZE_TO_CONTENT, flex() ]
    children = [
      mkRow(inStashFacompIcon, loc("market/tooltip/itemsInStash"), convertToShort(stashCount.get()))
      mkRow(onSoldierFacompIcon, loc("market/tooltip/itemsOnSoldier"), convertToShort(onMeItemCount.get()))
      customFilter.get().filterToUse != null ? null
        : mkRow(inCartFacompIcon, loc("market/tooltip/itemsInCart"), convertToShort(cartItemCount.get()))
    ]
  }
  return content
}

function findAttachmentsInList(items, idx = 0) {
  local iconAttachments = []
  foreach (item in items) {
    if (item?.insertIntoIdx == idx) {
      let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(item.templateName)
      let animchar = template.getCompValNullable("item__animcharInInventoryName") ?? template.getCompValNullable("animchar__res")
      iconAttachments.append(mkAttachedChar(item.insertIntoSlot, animchar))
    }
  }
  return iconAttachments
}

function mkBuyItemRowNameCol(item){
  let { templateName = null } = item.children.items[0]
  let itemIcon = freeze(itemIconNoBorder(templateName,
    {
      width=const iconSize[0]
      height=const iconSize[1]
      silhouette = ItemIconBlocked
      shading = "full"
      vplace = ALIGN_CENTER
    },
    findAttachmentsInList(item.children.items)))

  local rarityIcon = null
  let itemTemplate = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(templateName)
  let itemRarity = itemTemplate?.getCompValNullable("item__rarity")
  if (itemRarity != null) {
    let rarityColor = getRarityColor(itemRarity.tostring(), itemTemplate)
    rarityIcon = mkRarityCorner(rarityColor, {
      hplace = ALIGN_RIGHT
      vplace = ALIGN_BOTTOM
      size = const [hdpx(12), hdpx(12)]
    })
  }

  return mkSelectPanelItem({
    children = @(params) {
      size = flex()
      valign = ALIGN_CENTER
      clipChildren = true
      children = [
        {
          size = const [flex(), SIZE_TO_CONTENT]
          flow = FLOW_HORIZONTAL
          gap = const hdpx(5)
          padding = const [0, hdpx(10)]
          children = [
            itemIcon
            mkItemNameCtor(item)(params)
          ]
        }
        rarityIcon
      ]
    },
    state=selectedItem,
    idx=item.id,
    visual_params = const { padding = 0 },
    border_align = BD_LEFT
  })
}

let mkBuyItemRowPriceCol = @(item, width=hdpx(100)) {
  flow = FLOW_HORIZONTAL
  size = const [width, flex()]
  padding = 0
  gap = vertHap
  children = [
    mkPanel(
      (item?.reqMoney ?? 0) > 0
        ? mkText($"{creditsTextIcon} {item?.reqMoney}", sub_txt)
        : mkText("---", body_txt),
      { size = flex(), padding = hdpx(10), valign = ALIGN_CENTER, halign = ALIGN_RIGHT fillColor = SelBgNormal}
    )
  ]
}

function tryStashPurchase(templateName) {
  let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(templateName)
  let volume = ceil_volume(
    (template?.getCompValNullable("item__countPerStack") ?? 0) > 0
      ? max(template?.getCompValNullable("item__volumePerStack") ?? 0, template?.getCompValNullable("item__volume") ?? 0)
      : (template?.getCompValNullable("item__volume") ?? 0)
  )
  if (!is_inventory_have_free_volume(stashEid.get(), volume)) {
    let needMore = truncateToMultiple(volume - (stashMaxVolume.get() - stashVolume.get()), 0.1)
    setPurchaseNotInProgress()
    showNoEnoughStashSpaceMsgbox(needMore)
    sound_play("ui_sounds/item_insufficient_funds")
    return false
  }
  return true
}

function shopButtonPress(item_id, templateName, can_buy, animId = null) {
  if (can_buy) {
    let canPurchase = tryStashPurchase(templateName)
    if (!canPurchase)
      return
    anim_start($"currency_panel_{creditsTextIcon}")
    eventbus_send("profile_server.buyLots", [ { id = item_id, count = 1 } ])
    anim_start(animId)
    anim_start($"purchase_{templateName}descPanel")
    sound_play("ui_sounds/button_buy")
    buyInProgress.set(true)
  }
  else {
    showMsgbox({ text = loc("responseStatus/Not enough money") })
    anim_start($"currency_panel_{creditsTextIcon}")
    anim_start($"not_enough_money_{creditsTextIcon}")
    sound_play("ui_sounds/item_insufficient_funds")
  }
}

function showNotAvailableMsgbox(strings) {
  let content = {
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    flow = FLOW_VERTICAL
    gap = const hdpx(20)
    children = [ mkText(loc("market/notAvailable"), h2_txt) ]
      .extend(strings)
  }
  showMessageWithContent({ content = content })
}

function showRequireMonolithUnlock(strings, unlocksAtMonolithLevel, monolithUnlockToSend, playerStat) {
  let buttons = [
    { text = loc("Cancel"), isCurrent = true, isCancel = true }
    {
      text = loc("market/goToMonolith"),
      action = function() {
        monolithSelectedLevel.set(unlocksAtMonolithLevel)
        selectedMonolithUnlock.set(monolithUnlockToSend)
        ecs.g_entity_mgr.broadcastEvent(CmdShowUiMenu({menuName = MonolithMenuId}))
      }
    }
  ]
  let offerId = marketItems.get().findindex(@(offer) offer?.children.unlocks.contains(monolithUnlockToSend))
  local showUnlockButton = true
  if (unlocksAtMonolithLevel < currentMonolithLevel.get() && offerId) {
    let offerVal = marketItems.get()[offerId]
    let neededMonolithAccessLevel = offerVal?.requirements.monolithAccessLevel ?? 0
    if (neededMonolithAccessLevel != 0 && neededMonolithAccessLevel > currentMonolithLevel.get())
      showUnlockButton = false
    if (showUnlockButton) {
      foreach (unl in offerVal?.requirements.unlocks ?? []) {
        let hasUnlock = (playerStat?.unlocks.findindex(@(v) unl == v) != null)
        if (!hasUnlock) {
          showUnlockButton = false
          break
        }
      }
    }

    if (showUnlockButton) {
      let price = offerVal.additionalPrice?.monolithTokensCount ?? 0
      buttons.append({
        text = $"{loc("market/monolithOffer/unlockNow")} {monolithTokensTextIcon}{price}"
        action = function() {
          if (price > playerProfileMonolithTokensCount.get()) {
            addPlayerLog(mkNoMonotithTokensLog(monolithUnlockToSend))
          }
          else {
            sound_play("ui_sounds/mark_item_3d")
            eventbus_send("profile_server.buyLots", [ { id = offerId, count = 1 } ])
          }
        }
      })
    }
  }
  else
    showUnlockButton = false

  let content = {
    size = [sw(70), flex()]
    children = [
      showUnlockButton ? {
        hplace = ALIGN_RIGHT
        vplace = ALIGN_TOP
        flow = FLOW_HORIZONTAL
        gap = hdpx(10)
        children = currencyPanel
      } : null
      {
        hplace = ALIGN_CENTER
        vplace = ALIGN_CENTER
        halign = ALIGN_CENTER
        flow = FLOW_VERTICAL
        gap = hdpx(20)
        children = [
          mkText(loc("market/notAvailable"), h2_txt)
        ].extend(strings.map(@(v) v.__update(h2_txt)))
      }
    ]
  }
  showMessageWithContent({content, buttons})
}

let buyButtonSize = freeze([itemRowHeight*0.7, itemRowHeight*0.7])
let buyBtnAnimations = memoize(@(id) freeze([
  {
    prop = AnimProp.translate, from = [0, 0], to = [hdpx(30), 0],
    duration = 0.3, trigger = id, delay = 0.3
  }
  {
    prop = AnimProp.translate, from = [-hdpx(30), 0], to = [hdpx(30), 0],
    duration = 0.7, trigger = id, delay = 0.5, loop = true
  }
]))

let lockedSound = freeze({
  click = "ui_sounds/item_not_available"
  hover = "ui_sounds/button_highlight"
})

let lockedBtnTextParams = freeze({
  color = Color(225, 70, 69),
  pos = [hdpx(1), 0]
})
let buyBtnSize = freeze([itemRowHeight, itemRowHeight])
let notEnoughMoneyStyle = freeze({BtnBdNormal = Color(225, 70, 69), TextNormal = mul_color(TextNormal, 0.2, 5)})

function getRequirements(itemOffer, marketOffers, plStat, monolithLevels) {
  let { reqMoney = 0, buyable = false } = itemOffer
  if (!buyable || reqMoney <= 0)
    return {
      strings = [mkText(loc("market/tooltip/available/itemCannotBePurchased"), { color = RedWarningColor })]
      unlocksAtMonolithLevel = null
      monolithUnlockName = null
    }

  let monolithItemOffers = marketOffers.filter(@(v) (v?.requirements.monolithAccessLevel ?? 0) > 0)
  let strings = []
  local monolithUnlockName = null
  local unlocksAtMonolithLevel = null
  let req = itemOffer.requirements

  foreach(unl in req.unlocks) {
    let monolithOffer = monolithItemOffers.findvalue(@(offer) offer.children.unlocks.contains(unl))
    if (monolithOffer) {
      unlocksAtMonolithLevel = monolithOffer.requirements.monolithAccessLevel - 1
      monolithUnlockName = unl

      strings.append(mkText($"{loc("market/requreMonolithLevel")} {loc(monolithLevels?[unlocksAtMonolithLevel].offerName)}"))
      continue
    }

    let unlock = (plStat.unlocks.findindex(@(v) unl == v) != null)
    let unlockColor = unlock ? GreenSuccessColor : RedWarningColor
    strings.append(mkText(loc($"market/tooltip/available/{unl}"), { color = unlockColor }))
  }

  foreach(md, mdNeed in req.stats) {
    foreach(st, statsNeed in mdNeed) {
      let plStatVal = (plStat.stats?[md]?[st] ?? 0.0)
      let needMore = statsNeed - plStatVal
      let statColor = needMore <= 0 ? GreenSuccessColor : RedWarningColor
      strings.append( mkText(loc($"market/tooltip/available/{st}", { points=needMore >= 0 ? $"{plStatVal}/{statsNeed}" : statsNeed }), { color = statColor }) )
    }
  }

  return {
    strings
    unlocksAtMonolithLevel
    monolithUnlockName
  }
}

function mkLockedBuyButton(item) {
  return {
    rendObj = ROBJ_SOLID
    size = [hdpx(90), itemRowHeight]
    vplace = ALIGN_CENTER
    valign = ALIGN_CENTER
    halign = ALIGN_CENTER
    color = SelBgNormal
    padding = const [0, hdpx(4)]
    children = {
      size = const [hdpx(78), buyButtonSize[1]]
      children = fontIconButton(
        "lock",
        function() {
          let reqs = getRequirements(item, marketItems.get(), playerStats.get(), monolithLevelOffers.get())
          if (reqs.monolithUnlockName != null)
            showRequireMonolithUnlock(reqs.strings, reqs.unlocksAtMonolithLevel, reqs.monolithUnlockName, playerStats.get())
          else
            showNotAvailableMsgbox(reqs.strings)
        }
        {
          size = const [hdpx(78), flex()]
          sound = lockedSound
          fontSize = const hdpxi(20),
          textParams = lockedBtnTextParams
          onHover = function(on) {
            if (on) {
              let reqs = getRequirements(item, marketItems.get(), playerStats.get(), monolithLevelOffers.get())
              setTooltip(tooltipBox({
                flow = FLOW_VERTICAL
                halign = ALIGN_LEFT
                children = reqs.strings
              }))
            }
            else
              setTooltip(null)
          }

        }
      )
    }
  }
}

let mkId = memoize(@(id, additionalKey = "") $"{mkItemKey(id)}{additionalKey}")
let buySound = memoize(@(inProgress) freeze({
  click = inProgress ? "ui_sounds/button_click_inactive" : null
  hover = "ui_sounds/button_highlight"
}))

function mkBuyButton(item) {
  let haveEnoughMoney = Computed(@() playerProfileCreditsCount.get() >= item.reqMoney)
  let animId = mkId(item.id)
  let color = haveEnoughMoney.get() ? TextNormal : notEnoughMoneyStyle.TextNormal
  return {
    rendObj = ROBJ_SOLID
    size = buyBtnSize
    hplace = ALIGN_CENTER
    vplace = ALIGN_CENTER
    valign = ALIGN_CENTER
    halign = ALIGN_CENTER
    color = SelBgNormal
    children = @() {
      watch = [haveEnoughMoney, buyInProgress]
      size = buyButtonSize
      children = button(
        mkPurchaseIcon("stash_purchase", {
          color
          transform = {}
          animations = buyBtnAnimations(animId.tostring())
        }),
        function(event) {
          if (!buyInProgress.get()) {
            if (haveEnoughMoney.get())
              addPriceAnimation({ targetRect = event.targetRect, price = item.reqMoney, id = animCounter })
            animCounter++
            currentAnimationId.set(animId)
            shopButtonPress(item.id, item.children.items[0].templateName, haveEnoughMoney.get(), animId)
          }
          else
            addPlayerLog(progressPurchaseLog)
        }
        {
          size = buyButtonSize
          sound = buySound(buyInProgress.get())
          onHover = @(on) setTooltip(on ? loc("market/purchaseToStash") : null)
          style = !haveEnoughMoney.get() ? notEnoughMoneyStyle : {}
        }
      )
    }
  }
}

let inventories = [
  { eid = controlledHeroEid, parentId = Watched("0"), i = 0 },
  { eid = backpackEid, parentId = backpackUniqueId, i = 1 },
  { eid = safepackEid, parentId = safepackUniqueId, i = 2 }
]

let getInventoryToMove = @(volume)
  inventories.findvalue(@(inv) is_inventory_have_free_volume(inv.eid.get(), volume))

function purchaseToInventory(item, slotData, canBuy, event, animId = null) {
  if (!canBuy) {
    showMsgbox({ text = loc("responseStatus/Not enough money") })
    anim_start($"currency_panel_{creditsTextIcon}")
    anim_start($"not_enough_money_{creditsTextIcon}")
    sound_play("ui_sounds/item_insufficient_funds")
    return
  }

  let { children, reqMoney } = item
  let templateName = children.items[0].templateName
  let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(templateName)

  let { itemTemplate = null, mods = {} } = slotData
  let modSlotToEquip = mods.findvalue(@(v) v?.allowed_items.contains(templateName))
  local slot = "inventory"
  local parentId = "0"
  if (itemTemplate == null || itemTemplate == "") {
    slot = slotData.slot
    parentId = slotData.parentId
    customFilter.mutate(@(v) v.slotData.itemTemplate <- templateName)
  }
  else if (slotData.mods.len() > 0 && modSlotToEquip?.itemTemplate == "") {
    let { weapModSlotName, weapUniqueId } = modSlotToEquip
    slot = weapModSlotName
    parentId = weapUniqueId
    customFilter.mutate(@(v) v.slotData.mods[weapModSlotName].itemTemplate <- templateName)
  }
  else {
    let volume = ceil_volume(
      (template?.getCompValNullable("item__countPerStack") ?? 0) > 0
        ? max(template?.getCompValNullable("item__volumePerStack") ?? 0, template?.getCompValNullable("item__volume") ?? 0)
        : (template?.getCompValNullable("item__volume") ?? 0)
    )
    let inventory = getInventoryToMove(volume)
    if (!inventory) {
      showMsgbox({ text = loc("purchaseAndEquip/noSpace") })
      return
    }
    slot = "inventory"
    parentId = inventory.parentId.get()
  }

  addPriceAnimation({ targetRect = event.targetRect, price = reqMoney, id = animCounter })
  animCounter++
  currentAnimationId.set(animId)
  anim_start(animId)
  anim_start($"currency_panel_{creditsTextIcon}")
  eventbus_send("profile_server.buyLotInSlot", [{ id = item.id, slot, parentId }])
  sound_play("ui_sounds/button_buy")
  buyInProgress.set(true)
}

function mkBuyToInventoryButton(item) {
  let haveEnoughMoney = Computed(@() playerProfileCreditsCount.get() >= item.reqMoney)
  let id = mkId(item, item.id)
  let color = haveEnoughMoney.get() ? TextNormal : notEnoughMoneyStyle.TextNormal
  return @() {
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    rendObj = ROBJ_SOLID
    color = SelBgNormal
    size = buyBtnSize
    children = @() {
      watch = haveEnoughMoney
      size = buyButtonSize
      children = button(
        mkPurchaseIcon("inventory_purchase", {
          color
          transform = {}
          animations = buyBtnAnimations(id.tostring())
        }),
        function(event) {
          if (!buyInProgress.get())
            purchaseToInventory(item, customFilter.get().slotData, haveEnoughMoney.get(), event, id)
          else
            addPlayerLog(progressPurchaseLog)
        }
        {
          size = buyButtonSize
          sound = buySound(buyInProgress.get())
          onHover = @(on) setTooltip(on ? loc("market/purchaseToInventory") : null)
          style = !haveEnoughMoney.get() ? notEnoughMoneyStyle  : {}
          textParams = {
            transform = {}
            animations = buyBtnAnimations(id.tostring())
          }
        }
      )
    }
  }
}

function addToCart(item) {
  sound_play("ui_sounds/button_action")
  shoppingCartItems.mutate(function(v) {
    let { id } = item
    if (id in v)
      return v[id].count <- v[id].count + 1
    else
      return v[id] <- item.__merge({ count = 1 })
  })
}

let mkAddToCartIconButton = @(item) {
  rendObj = ROBJ_SOLID
  size = buyBtnSize
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
  valign = ALIGN_CENTER
  halign = ALIGN_CENTER
  color = SelBgNormal
  children = {
    size = buyButtonSize
    children = button(mkPurchaseIcon("cart_purchase"),
      @() addToCart(item)
      {
        size = buyButtonSize
        sound = buySound(buyInProgress.get())
        onHover = @(on) setTooltip(on ? loc("market/addToCart") : null)
      }
    )
  }
}

function chageShoppingCartCount(itemId, delta) {
  let curCount = shoppingCartItems.get()?[itemId].count
  if (curCount == null)
    return
  if ((curCount + delta) <= 0)
    shoppingCartItems.mutate(function(v) {
      let newData = v.$rawdelete(itemId)
      return newData
    })
  else
    shoppingCartItems.mutate(function(v) {
      let newData = v[itemId].__update({ count = v[itemId].count + delta })
      return newData
    })
}

let mkChangeCartItemsCount = @(deltaCount, itemId) {
  rendObj = ROBJ_SOLID
  size = buyBtnSize
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
  valign = ALIGN_CENTER
  halign = ALIGN_CENTER
  color = SelBgNormal
  children = fontIconButton(deltaCount > 0 ? "plus" : "minus",
    @() chageShoppingCartCount(itemId, deltaCount),
    {
      size = buyButtonSize
      sound = buySound(buyInProgress.get())
      onHover = @(on) setTooltip(!on ? null
        : deltaCount > 0 ? loc("market/addToCart") : loc("market/removeFromCart"))
      textParams = { pos = [hdpx(1), hdpx(1)] }
      fontSize = hdpxi(16)
    }
  )
}

function mkPriceAndBuyCol(item, isInCart, lotAvailable) {
  let { id } = item
  return {
    size = [SIZE_TO_CONTENT, itemRowHeight]
    flow = FLOW_HORIZONTAL
    gap = vertHap
    children = isInCart
      ? [
          mkChangeCartItemsCount(-1, id)
          mkChangeCartItemsCount(1, id)
        ]
      : [
          mkBuyItemRowPriceCol(item)
          function() {
            let buttons = []
            if (!lotAvailable)
              buttons.append(mkLockedBuyButton(item))
            else if (customFilter.get().filterToUse == null)
              buttons.append(mkAddToCartIconButton(item), mkBuyButton(item))
            else
              buttons.append(mkBuyToInventoryButton(item), mkBuyButton(item))
            return {
              watch = customFilter
              flow = FLOW_HORIZONTAL
              gap = vertHap
              children = buttons
            }
          }
        ]
  }
}


let halfPaddingSize = itemsGap.__merge({ size = [itemsGap.size[0], itemsGap.size[1] / 2]})
function mkBuyItemRow(item, isInCart = false) {
  let lotAvailable = Computed(@() isLotAvailable(item, playerStats.get()))
  let watch = [ showOnlyAvailableOffers, lotAvailable ]
  let { id } = item

  return function() {
    if (showOnlyAvailableOffers.get() && !lotAvailable.get())
      return { watch }
    return {
      watch
      size = [flex(), itemRowHeight]
      key = mkItemKey(id)
      clipChildren = true
      flow = FLOW_VERTICAL
      children = [
        halfPaddingSize
        {
          size = flex()
          flow = FLOW_HORIZONTAL
          gap = vertHap
          children = [
            mkFavoriteButton(id)
            mkBuyItemRowNameCol(item)
            item?.itemType != "presets" ? mkExistSection(item) : null
            mkPriceAndBuyCol(item, isInCart, lotAvailable.get())
          ]
        }
        halfPaddingSize
      ]
    }
  }
}

function mkFavoriteList(items) {
  return items.filter(@(v, id)
      (v?.buyable ?? true) &&
      (favoriteItems.get().findindex(@(v2) id == v2) != null)
    )
}

function mkCartList(items) {
  return items 
}

tblScrollHandler.subscribe(function(_) {
  let { elem = null } = tblScrollHandler
  if (elem == null || itemToScroll.get() == null)
    return

  tblScrollHandler.scrollToChildren(@(desc)
    ("key" in desc) && (desc.key == mkItemKey(itemToScroll.get())), 2, false, true)
  itemToScroll.set(null)
})

let buyPanelItemsListList = @(filtereditems, isInCart) {
  size = [flex(), SIZE_TO_CONTENT]
  margin = [0, hdpx(5), 0, 0]
  flow = FLOW_VERTICAL
  
  children = filtereditems?.get().map(@(v) mkBuyItemRow(v, isInCart))
}

let buyPanelItemsList = @(filtereditems, isInCart) @() {
  watch = filtereditems
  rendObj = ROBJ_WORLD_BLUR
  size = flex()
  children = filtereditems.get()?.len() != 0 ? makeVertScrollExt(buyPanelItemsListList(filtereditems, isInCart), {
    scrollHandler = tblScrollHandler
    size = flex()
  }) : notFoundStub
}

let otherItemsTextParams = {
  color = InfoTextValueColor
  halign = ALIGN_RIGHT
}.__update(sub_txt)

function mkBuyPanelItemDescriptionBody(item) {
  let mainItem = item.children.items[0]
  let otherItems = []
  for (local i = 1; i < item.children.items.len(); ++i){
    otherItems.append(mkTextArea(getItemLoc(item.children.items[i]), otherItemsTextParams))
  }
  let plusItems = otherItems.len() ? {
    flow = FLOW_HORIZONTAL
    size = [flex(), SIZE_TO_CONTENT]
    gap = hdpx(10)
    margin = [hdpx(10), 0, 0, 0]
    children = [
      mkText(loc("desc/plusItems"), {color = InfoTextDescColor}).__update(sub_txt)
      {
        size = [flex(), SIZE_TO_CONTENT]
        flow = FLOW_VERTICAL
        children = otherItems
      }
    ]
  } : null

  let textDesc = {
    halign = ALIGN_LEFT
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_VERTICAL
    gap = itemsGap
    children = item.offerName != "" ?
      item.children.items.map(@(v) getItemLoc(v)).reduce(function(acc, v) {
        if (v in acc)
          acc[v] += 1
        else
          acc[v] <- 1
        return acc
      }, {}).map(@(count, v) mkText($"{v} (x{count})").__update(sub_txt)).values() :
      itemDescriptionStrings(mainItem.templateName, sub_txt).append(plusItems)
  }
  let desc = {
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_HORIZONTAL
    gap = hdpx(20)
    children = textDesc
  }
  return {
    size = [ flex(), SIZE_TO_CONTENT ]
    halign = ALIGN_LEFT
    children = desc
  }
}

let waitingSpinner = spinner(hdpx(34), 0.3)

function mkAccentPurchaseButton(item, params = {}) {
  let haveEnoughMoney = Computed(@() playerProfileCreditsCount.get() >= item.reqMoney)
  let lotAvailable = Computed(@() isLotAvailable(item, playerStats.get()))
  let { buyable = false, isPurchaseAndEquip = false } = params
  let btnText = isPurchaseAndEquip
    ? $"{loc("market/purchaseToInventory")} {creditsTextIcon}{item.reqMoney}"
    : $"{loc("market/purchaseToStash")} {creditsTextIcon}{item.reqMoney}"
  return function() {
    return {
      watch = [haveEnoughMoney, lotAvailable, buyInProgress]
      size = [flex(), hdpx(50)]
      halign = ALIGN_CENTER
      children = buyInProgress.get() ? waitingSpinner
        : textButton(
            btnText,
            function(event) {
              let reqs = getRequirements(item, marketItems.get(), playerStats.get(), monolithLevelOffers.get())
              let showMonolithMsgbox = reqs.unlocksAtMonolithLevel != null && playerStats.get().unlocks.findindex(@(v) reqs.monolithUnlockName == v) == null

              if (showMonolithMsgbox)
                showRequireMonolithUnlock(reqs.strings, reqs.unlocksAtMonolithLevel, reqs.monolithUnlockName, playerStats.get())
              else if (!buyable)
                showNotAvailableMsgbox(reqs.strings)
              else if (!buyInProgress.get()) {
                if (isPurchaseAndEquip)
                  purchaseToInventory(item, customFilter.get().slotData, haveEnoughMoney.get(), event)
                else
                  shopButtonPress(item.id, item.children.items[0].templateName, haveEnoughMoney.get())
              }
              else
                addPlayerLog(progressPurchaseLog)
            },
            {
              size = [flex(), SIZE_TO_CONTENT]
              sound = buySound(buyInProgress.get())
              halign = ALIGN_CENTER
              textMargin = fsh(1)
              transform = {}
              animations = [
                { prop=AnimProp.opacity, from=1, to=1, duration=0.3, playFadeOut=true, easing=OutCubic }
              ]
            }.__update(haveEnoughMoney.get() && lotAvailable.get() ? accentButtonStyle : {}))
    }
  }
}

let mkAddToCartButton = @(item) function() {
  let isAvailable = isLotAvailable(item, playerStats.get())
  if (!isAvailable)
    return { watch = playerStats }
  return {
    watch = playerStats
    size = [flex(), SIZE_TO_CONTENT]
    children = textButton(loc("market/addToCart"),
      @() addToCart(item)
      {
        size = [flex(), SIZE_TO_CONTENT]
        sound = buySound(buyInProgress.get())
        halign = ALIGN_CENTER
      }
    )
  }
}

function checkStashVolume(allItems) {
  local neededVolume = 0
  foreach (data in allItems) {
    let count = data?.count ?? 1
    foreach (item in data.children.items) {
      let { templateName } = item
      let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(templateName)
      let volume = ceil_volume(
        (template?.getCompValNullable("item__countPerStack") ?? 0) > 0
          ? max(template?.getCompValNullable("item__volumePerStack") ?? 0, template?.getCompValNullable("item__volume") ?? 0)
          : (template?.getCompValNullable("item__volume") ?? 0)
      )
      neededVolume += volume * count
    }
  }
  if (!is_inventory_have_free_volume(stashEid.get(), neededVolume)) {
    let needMore = truncateToMultiple(neededVolume - (stashMaxVolume.get() - stashVolume.get()), 0.1)
    setPurchaseNotInProgress()
    showNoEnoughStashSpaceMsgbox(needMore)
    sound_play("ui_sounds/item_insufficient_funds")
    return false
  }
  return true
}

function purchaseAllCartButton() {
  let allCartItems = shoppingCartItems.get()
  let price = allCartItems.reduce(@(res, v) res += v.reqMoney * (v?.count ?? 1), 0)
  let haveEnoughMoney = playerProfileCreditsCount.get() >= price
  if (price == 0)
    return { watch = [shoppingCartItems, playerProfileCreditsCount] }
  return {
    watch = [shoppingCartItems, playerProfileCreditsCount]
    size = [flex(), SIZE_TO_CONTENT]
    children = textButton($"{loc("market/cartPurchase")} {creditsTextIcon}{price}",
      function() {
        if (!haveEnoughMoney) {
          showMsgbox({ text = loc("responseStatus/Not enough money") })
          return
        }
        else if (!buyInProgress.get()) {
          if (!checkStashVolume(allCartItems))
            return
          
          
          
          let itemsToPurchase = allCartItems.reduce(function(acc, v){
            for (local i = 0; i < v.count; i++){
              acc.append({id = v.id, count = 1})
            }
            return acc
          }, [])
          anim_start($"currency_panel_{creditsTextIcon}")
          eventbus_send("profile_server.buyLots", itemsToPurchase)
          sound_play("ui_sounds/button_buy")
          buyInProgress.set(true)
          needToCleanCart.set(true)
        }
        else
          addPlayerLog(progressPurchaseLog)
      },
      {
        size = [flex(), SIZE_TO_CONTENT]
        sound = buySound(buyInProgress.get())
        halign = ALIGN_CENTER
        onHover = @(on) setTooltip(on ? loc("btn/buy") : null)
        textParams = {
          transform = {}
        }
      }.__update(haveEnoughMoney ? accentButtonStyle : {}))
  }
}

function mkClearCartButton() {
  let isCartEmpty = Computed(@() shoppingCartItems.get().len() <= 0)
  let watch = isCartEmpty
  return function() {
    if (isCartEmpty.get())
      return { watch }
    return {
      watch
      size = [flex(), SIZE_TO_CONTENT]
      children = textButton(loc("market/clearCart"),
        @() shoppingCartItems.modify(@(_items) {}),
        {
          size = [flex(), SIZE_TO_CONTENT]
          halign = ALIGN_CENTER
        })
      }
    }
  }

function mkBuyPanelItemDescriptionDetails(item) {
  if (item == null)
    return null
  let { templateName } = item.children.items[0]
  let purchaseAnim = marketAnimChildren(marketGlareAnim($"purchase_{templateName}descPanel", 0.8))
  return @() {
    size = [flex(0.33), flex()]
    flow = FLOW_VERTICAL
    gap = itemsGap
    children = [
      {
        size = [flex(), itemRowHeight]
        clipChildren = true
        children = [
          purchaseAnim
          {
            size = flex()
            flow = FLOW_HORIZONTAL
            children = [
              mkSubTitle(item.offerName != "" ? loc($"marketOffer/{item.offerName}") : getItemLoc(item.children.items[0]))
            ]
          }
        ]
      }
      makeVertScroll(
        mkPanel(mkBuyPanelItemDescriptionBody(item),
        { size = [flex(), SIZE_TO_CONTENT] }
      ))
    ]
  }
}

function mkBuyPanelItemDescriptionRelated(itemOffers, item, related, isInCart) {
  let { templateName = null } = item?.children.items[0]
  if (templateName == null)
    return null

  let { id } = item
  local relatedItems = []
  let relatedIds = related.get()?[id] ?? []
  foreach (reldId in relatedIds) {
    let relatedItem = itemOffers?[reldId]

    if (!relatedItem?.buyable)
      continue

    relatedItems.append(relatedItem)
  }
  relatedItems = relatedItems.sort(marketSorting)

  let requirements = item?.requirements
  let buyable = (item?.buyable ?? false)
  return {
    size = [flex(0.66), flex()]
    flow = FLOW_VERTICAL
    gap = hdpx(8)
    children = [
      {
        size = flex()
        vplace = ALIGN_TOP
        hplace = ALIGN_RIGHT
        flow = FLOW_VERTICAL
        gap = itemsGap
        children = relatedItems.len() == 0 ? null : [
          mkSubTitle(loc("market/suitableItems"))
          makeVertScroll({
            size = [flex(), SIZE_TO_CONTENT]
            flow = FLOW_VERTICAL
            margin = [0, hdpx(5), 0, 0]
            
            rendObj = ROBJ_WORLD_BLUR_PANEL
            children = relatedItems.map(@(v) mkBuyItemRow(v))
          })
        ]
      }
      {
        flow = FLOW_HORIZONTAL
        size = [flex(), SIZE_TO_CONTENT]
        children = [
          {
            size = [flex(), SIZE_TO_CONTENT]
            flow = FLOW_HORIZONTAL
            gap = hdpx(8)
            children = [
              @() {
                watch = customFilter
                size = [flex(), SIZE_TO_CONTENT]
                children = isInCart ? mkClearCartButton()
                  : customFilter.get().filterToUse == null ? mkAddToCartButton(item)
                  : mkAccentPurchaseButton(item, { buyable, requirements, isPurchaseAndEquip = true })
              }
              isInCart ? purchaseAllCartButton : mkAccentPurchaseButton(item, { buyable, requirements })
            ]
          }
        ]
      }
    ]
  }
}

function buyPanelItemDescription(items, related, isInCart){
  return @(){
    watch = [selectedItem, items, related]
    size = [flex(), ph(45)]
    flow = FLOW_HORIZONTAL
    gap = hdpx(10)
    children = [
      mkBuyPanelItemDescriptionDetails(items.get()?[selectedItem.get()])
      mkBuyPanelItemDescriptionRelated(items.get(), items.get()?[selectedItem.get()], related, isInCart)
    ]
  }
}

function is_item_name_contain(template_name, substr){
  let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(template_name)
  let itemName = template?.getCompValNullable("item__name")
  if (itemName)
    return utf8ToLower(loc(itemName)).contains(utf8ToLower(substr))
  return false
}

let mkDeleteInputTextBtn = @(textWatch, filterData) function() {
  let watch = [filterData, textWatch]
  if (textWatch.get().len() <= 0 && filterData.get().filterToUse == null)
    return { watch }
  return {
    watch
    hplace = ALIGN_RIGHT
    vplace = ALIGN_CENTER
    margin = [0, hdpx(10),0,0]
    children = fontIconButton("icon_buttons/x_btn.svg", function() {
        textWatch.set("")
        if (customFilter.get().filterToUse != null) {
          customFilter.mutate(@(v) v.filterToUse <- null)
          itemToScroll.set(selectedItem.get())
        }
      },
      {padding = hdpx(2)}
    )
  }
}

function defaultFilter(item, selectedCategory, inputFilter) {
  let { buyable = true, itemType = "", children = {} } = item
  return buyable
    && (inputFilter.len() == 0 || children?.items.findindex(@(i) is_item_name_contain(i.templateName, inputFilter)) != null)
    && itemType == selectedCategory
}

let marketShowroomPreviewSize = { posX = 0, posY = 0, sizeX = 0, sizeY = 0 }
function mkBuyMarketPanel() {
  
  
  
  let patchedMarketItems = Computed(@() marketItems.get().map(patchItemType))

  let filtereditems = Computed(function() {
    if (selectedItemsCategory.get() == "cart")
      return mkCartList(shoppingCartItems.get()).values().sort(marketSorting)

    let typeFixedItems = patchedMarketItems.get()

    if (selectedItemsCategory.get() == "favoriteItems")
      return mkFavoriteList(typeFixedItems).values().sort(marketSorting)

    let listToUse = customFilter.get().filterToUse != null
      ? typeFixedItems.filter(@(_v, k) customFilter.get().filterToUse(k))
      : typeFixedItems.filter(@(v) defaultFilter(v, selectedItemsCategory.get(), textFilter.get()))

    return listToUse.values().sort(marketSorting)
  })

  selectedItem.subscribe(function(v){
    let data = ecs.CompObject()
    let items = marketItems.get()?[v]?.children?.items ?? []
    foreach(item in items)
      data[item.insertIntoSlot.len() == 0 ? "__weapon" : item.insertIntoSlot] <- item.templateName

    let item = marketItems.get()?[v]
    let { buyable = false, itemType = "", id = -1 } = item
    itemToScroll.set(v)
    if ((selectedItemsCategory.get() != "favoriteItems" || !favoriteItems.get().contains(id))
        && selectedItemsCategory.get() != "cart"
        && buyable)
      selectedItemsCategory.set(itemType)
    oldCategory = selectedItemsCategory.get()
    if (v != -1)
      ecs.g_entity_mgr.broadcastEvent(EventShowItemInShowroom({ showroomKey="itemShowroom", data}))
  })

  let inputBlock = {
    size = [hdpx(350), SIZE_TO_CONTENT]
    children = textInput(textFilter, {
      placeholder = loc("search by name")
      textmargin = hdpx(5)
      margin = 0
      onChange = @(value) textFilter.set(value)
      onEscape = @() textFilter.set("")
    }.__update(body_txt))
  }

  let mkSelectedFilterBlock = @(data) {
    rendObj = ROBJ_SOLID
    size = [SIZE_TO_CONTENT, hdpx(38)]
    minWidth = hdpx(350)
    valign = ALIGN_CENTER
    padding = [0, hdpx(10)]
    color = BtnBgSelected
    children = mkText(data.activeFilter, {
      color = TextNormal
    }.__update(body_txt))
  }

  function mkBuyPanelBody() {
    let isShoppingCartOpened = Computed(@() selectedItemsCategory.get() == "cart")
    let relatedItemIds = Computed(function() {
      if (customFilter.get()?.filterToUse != null)
        return {}
      local res = {}
      let items = marketItems.get()
      foreach (id, itm in items) {
        let { itemType="" } = itm
        if (itemType == "weapons")
          weaponRelated(itm, id, res, items)
        else if (itemType == "equipment") {
          equipmentRelated(itm, res)
        }
      }
      return res.map(@(v) v.filter(@(c, k) v.indexof(c) == k))
    })
    let onAttach = @() selectedItem.get() == -1 ? selectedItem.set(filtereditems.get()?[0].id) : null

    let showOnlyAvailableItemsCheckbox = checkBox(showOnlyAvailableOffers, {
      rendObj = ROBJ_TEXTAREA
      behavior = Behaviors.TextArea
      text = loc("market/showOnlyAvailable")
    }, { override = { size = SIZE_TO_CONTENT }})

    return {
      size = flex()
      flow = FLOW_VERTICAL
      gap = hdpx(15)
      onAttach
      children = [
        @() {
          watch = customFilter
          flow = FLOW_HORIZONTAL
          gap = hdpx(15)
          children = [
            {
              flow = FLOW_HORIZONTAL
              gap = hdpx(5)
              children = [
                customFilter.get().filterToUse != null ? mkSelectedFilterBlock(customFilter.get())
                  : inputBlock
                mkDeleteInputTextBtn(textFilter, customFilter)
              ]
            }
            showOnlyAvailableItemsCheckbox
          ]
        }
        @() {
          watch = isShoppingCartOpened
          size = flex()
          flow = FLOW_HORIZONTAL
          gap = hdpx(15)
          children = [
            {
              size = [flex(0.44), flex()]
              children = buyPanelItemsList(filtereditems, isShoppingCartOpened.get())
            }
            {
              flow = FLOW_VERTICAL
              size = [flex(0.6), flex()]
              children = [
                {
                  size = flex()
                  onAttach = function(elem) {
                    marketShowroomPreviewSize.posX = elem.getScreenPosX() + elem.getWidth() / 2
                    marketShowroomPreviewSize.posY = elem.getScreenPosY() + elem.getHeight() / 2
                    marketShowroomPreviewSize.sizeX = elem.getWidth()
                    marketShowroomPreviewSize.sizeY = elem.getHeight()
                  }
                }
                buyPanelItemDescription(marketItems, relatedItemIds, isShoppingCartOpened.get())
              ]
            }
          ]
        }
      ]
    }
  }

  let helpBtn = mkHelpButton(mkHelpConsoleScreen(Picture("ui/build_icons/market_console.avif:{0}:{0}:P".subst(hdpx(600))), help_data), marketScreenName)
  let windowButtons = @() {
    watch = sectionToReturn
    flow = FLOW_HORIZONTAL
    gap = hdpx(2)
    children = [
      helpBtn
      sectionToReturn.get() == null ? closeBtn : mkBackBtn(sectionToReturn.get())
    ]
  }
  return @() {
    watch = marketItems
    size = flex()
    flow = FLOW_VERTICAL
    gap = hdpx(15)
    halign = ALIGN_CENTER
    onDetach = function() {
      customFilter.modify(@(_v) { filterToUse = null })
      selectedItem.set(-1)
    }
    onAttach = function() {
      if (selectedItemsCategory.get() == null)
        selectedItemsCategory.set(getDefaultCategory())
    }
    children = [
      {
        size = [flex(), SIZE_TO_CONTENT]
        flow = FLOW_HORIZONTAL
        gap = hdpx(10)
        valign = ALIGN_CENTER
        children = [
          buyPanelHeader(filtereditems)
          windowButtons
        ]
      }
      mkBuyPanelBody()
    ]
  }
}

function mkMarketScreen() {

  let marketScreen = {
    size = flex()
    hplace = ALIGN_CENTER
    children = mkBuyMarketPanel()
  }

  let mouseCatchPanel = {
    size = flex()
    behavior = [Behaviors.MoveResize, Behaviors.WheelScroll]
    stopMouse = false
    onMoveResize = @(dx, dy, _dw, _dh) ecs.g_entity_mgr.broadcastEvent(EventUIMouseMoved({screenX = dx, screenY = dy}))
    onWheelScroll = @(value) ecs.g_entity_mgr.broadcastEvent(EventUIMouseWheelUsed({value}))
  }

  let content = {
    size = flex()
    children = [
      mouseCatchPanel
      @() {
        watch = safeAreaAmount
        size = flex()
        maxWidth = sw(97) * safeAreaAmount.get()
        maxHeight = sh(90) * safeAreaAmount.get()
        padding = [hdpx(50), hdpx(50), 0, hdpx(50)]
        hplace = ALIGN_CENTER
        vplace = ALIGN_CENTER
        flow = FLOW_VERTICAL
        children = marketScreen
      }
      priceAnimationBlock
    ]
    onDetach = function(){
      ecs.g_entity_mgr.broadcastEvent(EventCloseShowroom())
      sectionToReturn.set(null)
    }
    onAttach = function(){
      let data = ecs.CompObject()
      let items = marketItems.get()?[selectedItem.get()]?.children?.items ?? []
      foreach(item in items)
        data[item.insertIntoSlot.len() == 0 ? "__weapon" : item.insertIntoSlot] <- item.templateName
      ecs.g_entity_mgr.broadcastEvent(EventShowItemInShowroom({ showroomKey="itemShowroom", data }))
      ecs.g_entity_mgr.broadcastEvent(EventActivateShowroom({
        showroomKey="itemShowroom",
        placeScreenPosition=Point2(marketShowroomPreviewSize.posX, marketShowroomPreviewSize.posY),
        placeScreenSize=Point2(marketShowroomPreviewSize.sizeX, marketShowroomPreviewSize.sizeY)
      }))
    }
  }

  return {
    getContent = @() content
    name = marketScreenName
    id = Market_id
  }
}

return {
  mkMarketScreen
  Market_id
  marketScreenName
  marketIsAvailable = Computed(@() !isOnboarding.get())
  setSectionToReturn = function (v){
    sectionToReturn.set(v)
  }
}
