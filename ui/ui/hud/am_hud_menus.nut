from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { QuickChatID, quickChatUI } = require("%ui/hud/menus/quickchat_ui.nut")
let { EmotesUiId, emoteUI } = require("%ui/hud/menus/emote_ui.nut")
let { BigMapId, bigMap } = require("%ui/hud/menus/big_map.nut")
let { InventoryMenuId, inventoryMenuDesc } = require("%ui/hud/menus/inventory.nut")
let { HealingDollId, healingDollPanel } = require("%ui/hud/menus/components/damageModel.nut")
let { WorkBenchMenuId, workbenchMenu } = require("%ui/hud/menus/encounter_workbench.nut")
let { InteractionMenuId, interactionMenu } = require("%ui/hud/menus/interaction.nut")
let { Market_id, mkMarketScreen, marketIsAvailable } = require("%ui/mainMenu/marketMenu.nut")
let { ClonesMenuId, mkClonesMenu, clonesMenuIsAvailable } = require("%ui/mainMenu/clonesMenu/clonesMenu.nut")
let { BaseDebriefingMenuId, mkBaseDebriefingMenu } = require("%ui/mainMenu/baseDebriefing.nut")
let { NEXUS_DEBRIEFING_ID, mkNexusDebriefingMenu } = require("%ui/mainMenu/nexus_debriefing.nut")
let { CRAFT_WND_ID, mkCraftWnd, craftIsAvailable } = require("%ui/mainMenu/researchAndCraft.nut")
let { AmCleanMenuId, mkAmProcessing, amProcessingIsAvailable } = require("%ui/mainMenu/amProcessingDeviceMenu.nut")
let { Raid_id, mkRaidScreen } = require("%ui/mainMenu/consoleRaidMenu.nut")
let { JournalMenuId, journalMenuUi, journalNotifications } = require("%ui/hud/menus/journal.nut")
let { PLAYER_PROFILE_ID, profileMenuUi } = require("%ui/hud/menus/player_profile.nut")
let { AudioModuleId, audioModuleUi, audioNotifications, audioModuleIsAvailable, audioModuleName
} = require("%ui/mainMenu/audio_module.nut")
let { CONTACTLIST_MODAL_UID, isContactsVisible } = require("%ui/mainMenu/contacts/contactsListWnd.nut")
let { isNexus } = require("%ui/hud/state/nexus_mode_state.nut")
let { isOnboarding } = require("%ui/hud/state/onboarding_state.nut")
let { inShootingRange } = require("%ui/hud/state/shooting_range_state.nut")
let { mkMonolithMenu, isMonolithMenuAvailable } = require("%ui/mainMenu/monolith/monolithMenu.nut")
let { MonolithMenuId } = require("%ui/mainMenu/monolith/monolith_common.nut")
let { NEXUS_STATS_ID, nexusStatsUi, nexusTabHeader } = require("%ui/hud/menus/nexus_stats.nut")
let { loadoutSelectionMenu, NexusLoadoutSelectionId } = require("%ui/hud/nexus_mode_loadout_selection_screen.nut")

let playerBaseHudMenus = freeze({
  [CONTACTLIST_MODAL_UID] = { onOpen = @() isContactsVisible.set(true) },
  [QuickChatID]           = { getContent = @() quickChatUI, event = "HUD.QuickChat", isInteractive = false },
  [EmotesUiId]            = { getContent = @() emoteUI, event = "Human.UseEmote", isInteractive = false },
  [InventoryMenuId]       = inventoryMenuDesc,
  [Market_id]             = { getMenu = @() mkMarketScreen(), isAvailable = marketIsAvailable, onOpenTriggerHash = ecs.calc_hash("show_shelter_note_market") },
  [ClonesMenuId]          = { getMenu = @() mkClonesMenu(), isAvailable = clonesMenuIsAvailable, onOpenTriggerHash = ecs.calc_hash("show_shelter_note_alters") },
  [CRAFT_WND_ID]    = { getMenu = @() mkCraftWnd(), isAvailable = craftIsAvailable, onOpenTriggerHash = ecs.calc_hash("show_shelter_note_replicator") },
  [AmCleanMenuId]         = { getMenu = @() mkAmProcessing(), isAvailable = amProcessingIsAvailable, onOpenTriggerHash = ecs.calc_hash("show_shelter_note_refiner") },
  [Raid_id]               = { getMenu = @() mkRaidScreen(), onOpen = @(_submenus=null) null},
  [BaseDebriefingMenuId]  = { getMenu = @() mkBaseDebriefingMenu() },
  [NEXUS_DEBRIEFING_ID]   = { getMenu = @() mkNexusDebriefingMenu() },
  [WorkBenchMenuId]       = { getContent = @() workbenchMenu },
  [InteractionMenuId]     = { getContent = @() interactionMenu },
  [HealingDollId]         = { getContent = @() healingDollPanel }, 
  [JournalMenuId]         = { getContent = @() journalMenuUi event = "HUD.Journal"
    name = loc("controls/HUD.Journal") notifications = journalNotifications},
  [PLAYER_PROFILE_ID]     = { getContent = @() profileMenuUi },
  [AudioModuleId]  = { getContent = @() audioModuleUi,
    name = audioModuleName, notifications = audioNotifications, isAvailable = audioModuleIsAvailable},
  [MonolithMenuId]          = { getMenu = mkMonolithMenu, isAvailable = isMonolithMenuAvailable},
}.map(@(v, k) v.__merge({id = k})))

let playerBaseHudMenuTabs = [
  Raid_id,
  Market_id,
  InventoryMenuId,
  MonolithMenuId,
  CRAFT_WND_ID,
  AmCleanMenuId,
  PLAYER_PROFILE_ID,
  JournalMenuId,
  AudioModuleId,
]

let battleHudMenus = freeze({
  [NexusLoadoutSelectionId] = loadoutSelectionMenu,
  [QuickChatID]       = { getContent = @() quickChatUI, event = "HUD.QuickChat", isInteractive = false },
  [EmotesUiId]        = { getContent = @() emoteUI, event = "Human.UseEmote", isInteractive = false },
  [BigMapId]          = { getContent = @() bigMap           event = "HUD.BigMap"      openSound = "ui_sounds/map_on" closeSound = "ui_sounds/map_off"
    name = loc("controls/HUD.BigMap") isAvailable = Computed(@() !isOnboarding.get() && !inShootingRange.get()), isInteractive=false },
  [InventoryMenuId]   = inventoryMenuDesc,
  [HealingDollId]     = { getContent = @() healingDollPanel }, 
  [WorkBenchMenuId]   = { getContent = @() workbenchMenu },
  [InteractionMenuId] = { getContent = @() interactionMenu },
  [JournalMenuId]     = { getContent = @() journalMenuUi event = "HUD.Journal" name = loc("controls/HUD.Journal")
    isAvailable = Computed(@() !isNexus.get()) notifications = journalNotifications },
  [NEXUS_STATS_ID] = { getContent = @() nexusStatsUi, isAvailable = isNexus, name = nexusTabHeader },
  [AudioModuleId]  =  { getContent = @() audioModuleUi, name = audioModuleName,
    notifications = audioNotifications, isAvailable = audioModuleIsAvailable},
}.map(@(v, k) v.__merge({id = k})))

let battleHudMenuTabs = [
  NexusLoadoutSelectionId,
  InventoryMenuId,
  NEXUS_STATS_ID,
  JournalMenuId,
  BigMapId,
  AudioModuleId
]

return {playerBaseHudMenus, battleHudMenus, playerBaseHudMenuTabs, battleHudMenuTabs}
