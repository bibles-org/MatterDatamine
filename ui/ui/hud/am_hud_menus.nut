from "%ui/mainMenu/audio_module.nut" import audioModuleUi

from "%ui/hud/menus/quickchat_ui.nut" import quickChatUI
from "%ui/hud/menus/emote_ui.nut" import emoteUI
from "%ui/hud/menus/grenade_selection_window.nut" import grenadeUi
from "%ui/hud/menus/big_map.nut" import bigMap
from "%ui/hud/menus/components/damageModel.nut" import healingDollPanel
from "%ui/hud/menus/encounter_workbench.nut" import workbenchMenu
from "%ui/hud/menus/interaction.nut" import interactionMenu
from "%ui/mainMenu/marketMenu.nut" import mkMarketScreen
from "%ui/mainMenu/clonesMenu/clonesMenu.nut" import mkClonesMenu
from "%ui/mainMenu/baseDebriefing.nut" import mkBaseDebriefingMenu
from "%ui/mainMenu/nexus_debriefing.nut" import mkNexusDebriefingMenu
from "%ui/mainMenu/researchAndCraft.nut" import mkCraftWnd
from "%ui/mainMenu/amProcessingDeviceMenu.nut" import mkAmProcessing
from "%ui/mainMenu/amProcessingSelectItem.nut" import refinerRecipeListWindowId, refinerRecipeListWindow, refinerRecipeListWindowIsAvailable
from "%ui/mainMenu/consoleRaidMenu.nut" import mkMissionsScreen
from "%ui/hud/menus/journal.nut" import journalMenuUi
from "%ui/mainMenu/monolith/monolithMenu.nut" import mkMonolithMenu
from "%ui/hud/menus/weaponShowroom/weaponShowroom.nut" import mkWeaponShowroomMenu, WEAPON_SHOWROOM_MENU_ID

from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { QuickChatID } = require("%ui/hud/menus/quickchat_ui.nut")
let { EmotesUiId } = require("%ui/hud/menus/emote_ui.nut")
let { GRENADE_SELECTION_ID } = require("%ui/hud/menus/grenade_selection_window.nut")
let { BigMapId } = require("%ui/hud/menus/big_map.nut")
let { InventoryMenuId, inventoryMenuDesc } = require("%ui/hud/menus/inventory.nut")
let { HealingDollId } = require("%ui/hud/menus/components/damageModel.nut")
let { WorkBenchMenuId } = require("%ui/hud/menus/encounter_workbench.nut")
let { InteractionMenuId } = require("%ui/hud/menus/interaction.nut")
let { Market_id, marketIsAvailable } = require("%ui/mainMenu/marketMenu.nut")
let { clonesMenuIsAvailable } = require("%ui/mainMenu/clonesMenu/clonesMenu.nut")
let { ClonesMenuId } = require("%ui/mainMenu/clonesMenu/clonesMenuCommon.nut")
let { mainChronogeneRewardScreenId, mainChronogeneRewardScreenMenu } = require("%ui/mainMenu/clonesMenu/mainChronogeneRewardSelection.nut")
let { BaseDebriefingMenuId } = require("%ui/mainMenu/baseDebriefing.nut")
let { NEXUS_DEBRIEFING_ID } = require("%ui/mainMenu/nexus_debriefing.nut")
let { CRAFT_WND_ID, craftIsAvailable } = require("%ui/mainMenu/researchAndCraft.nut")
let { AmCleanMenuId, amProcessingIsAvailable } = require("%ui/mainMenu/amProcessingDeviceMenu.nut")
let { Missions_id } = require("%ui/mainMenu/consoleRaidMenu.nut")
let { JournalMenuId, journalNotifications } = require("%ui/hud/menus/journal.nut")
let { AudioModuleId, audioNotifications, audioModuleIsAvailable, audioModuleName } = require("%ui/mainMenu/audio_module.nut")
let { CONTACTLIST_MODAL_UID, isContactsVisible } = require("%ui/mainMenu/contacts/contactsListWnd.nut")
let { isNexus } = require("%ui/hud/state/nexus_mode_state.nut")
let { isOnboarding, onboardingStateMachineCurrentStateEid, onboardingStateMachineMiniraidStateEid } = require("%ui/hud/state/onboarding_state.nut")
let { inShootingRange } = require("%ui/hud/state/shooting_range_state.nut")
let { isMonolithMenuAvailable } = require("%ui/mainMenu/monolith/monolithMenu.nut")
let { MonolithMenuId } = require("%ui/mainMenu/monolith/monolith_common.nut")
let { loadoutSelectionMenu, NexusLoadoutSelectionId } = require("%ui/hud/nexus_mode_loadout_selection_screen.nut")

let playerBaseHudMenus = freeze({
  [CONTACTLIST_MODAL_UID] = { onOpen = @() isContactsVisible.set(true) },
  [QuickChatID]           = { getContent = @() quickChatUI, event = "HUD.QuickChat", isInteractive = false },
  [EmotesUiId]            = { getContent = @() emoteUI, event = "Human.UseEmote", isInteractive = false },
  [GRENADE_SELECTION_ID]  = { getContent = @() grenadeUi, event = "Human.ChooseGrenade", isInteractive = false },
  [InventoryMenuId]       = inventoryMenuDesc,
  [Market_id]             = { getMenu = @() mkMarketScreen(), isAvailable = marketIsAvailable, onOpenTriggerHash = ecs.calc_hash("show_shelter_note_market") },
  [ClonesMenuId]          = { getMenu = @() mkClonesMenu(), isAvailable = clonesMenuIsAvailable, onOpen = @(_submenus=null) null },    
  [CRAFT_WND_ID]    = { getMenu = @() mkCraftWnd(), isAvailable = craftIsAvailable, onOpenTriggerHash = ecs.calc_hash("show_shelter_note_replicator") },
  [AmCleanMenuId]         = { getMenu = @() mkAmProcessing(), isAvailable = amProcessingIsAvailable, onOpenTriggerHash = ecs.calc_hash("show_shelter_note_refiner") },
  [Missions_id]               = { getMenu = @() mkMissionsScreen(), onOpen = @(_submenus=null) null},
  [BaseDebriefingMenuId]  = { getMenu = @() mkBaseDebriefingMenu() },
  [NEXUS_DEBRIEFING_ID]   = { getMenu = @() mkNexusDebriefingMenu() },
  [WorkBenchMenuId]       = { getContent = @() workbenchMenu },
  [InteractionMenuId]     = { getContent = @() interactionMenu },
  [HealingDollId]         = { getContent = @() healingDollPanel }, 
  [JournalMenuId]         = { getContent = @() journalMenuUi event = "HUD.Journal"
    name = loc("journalMenu") notifications = journalNotifications},
  [AudioModuleId]  = { getContent = @() audioModuleUi,
    name = audioModuleName, notifications = audioNotifications, isAvailable = audioModuleIsAvailable},
  [MonolithMenuId]          = { getMenu = mkMonolithMenu, isAvailable = isMonolithMenuAvailable},
  [mainChronogeneRewardScreenId] = { getMenu = @() mainChronogeneRewardScreenMenu },
  [WEAPON_SHOWROOM_MENU_ID] = { getContent = @() mkWeaponShowroomMenu }
}.map(@(v, k) v.__merge({id = k})))

let playerBaseHudMenuTabs = [
  Missions_id,
  Market_id,
  InventoryMenuId,
  MonolithMenuId,
  CRAFT_WND_ID,
  AmCleanMenuId,
  JournalMenuId,
  AudioModuleId,
]

let battleHudMenus = freeze({
  [NexusLoadoutSelectionId] = loadoutSelectionMenu,
  [QuickChatID]       = { getContent = @() quickChatUI, event = "HUD.QuickChat", isInteractive = false },
  [EmotesUiId]        = { getContent = @() emoteUI, event = "Human.UseEmote", isInteractive = false },
  [GRENADE_SELECTION_ID] = { getContent = @() grenadeUi, event = "Human.ChooseGrenade", isInteractive = false },
  [BigMapId]          = { getContent = @() bigMap, event = "HUD.BigMap", openSound = "ui_sounds/map_on",
    closeSound = "ui_sounds/map_off", name = loc("controls/HUD.BigMap"), isInteractive=false,
    isAvailable = Computed(@() !inShootingRange.get() && (!isOnboarding.get() || onboardingStateMachineCurrentStateEid.get() == onboardingStateMachineMiniraidStateEid.get())) },
  [InventoryMenuId]   = inventoryMenuDesc,
  [HealingDollId]     = { getContent = @() healingDollPanel }, 
  [WorkBenchMenuId]   = { getContent = @() workbenchMenu },
  [InteractionMenuId] = { getContent = @() interactionMenu },
  [JournalMenuId]     = { getContent = @() journalMenuUi event = "HUD.Journal" name = loc("journalMenu")
    isAvailable = Computed(@() !isNexus.get()) notifications = journalNotifications },
  [AudioModuleId]  =  { getContent = @() audioModuleUi, name = audioModuleName,
    notifications = audioNotifications, isAvailable = audioModuleIsAvailable},
  [refinerRecipeListWindowId] = { getMenu = @() refinerRecipeListWindow() isAvailable = refinerRecipeListWindowIsAvailable }
}.map(@(v, k) v.__merge({id = k})))

let battleHudMenuTabs = [
  NexusLoadoutSelectionId,
  InventoryMenuId,
  JournalMenuId,
  BigMapId,
  AudioModuleId,
  refinerRecipeListWindowId
]

return {playerBaseHudMenus, battleHudMenus, playerBaseHudMenuTabs, battleHudMenuTabs}
