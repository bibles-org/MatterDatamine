require app
require ecs
require soundEvent
require game.events.events_active_matter


[es(tag=sound, track=encounter_corrupted_workbench__cleaned)]
def encounter_corrupted_workbench_track_cleaned_sound(evt : Event;
                                                      encounter_corrupted_workbench_sound__cleaned : string;
                                                      encounter_corrupted_workbench__cleaned : bool;
                                                      transform : float3x4)
  if encounter_corrupted_workbench__cleaned
    oneshot(encounter_corrupted_workbench_sound__cleaned, transform[3])


[es(tag=sound)]
def encounter_workbench_item_created_sound(evt : EventWorkbenchItemsCreated;
                                           encounter_workbench_sound__itemCreated : string;
                                           transform : float3x4)
  oneshot(encounter_workbench_sound__itemCreated, transform[3])


[es(tag=sound)]
def encounter_workbench_result_event_sound(evt : EventWorkbenchResultEvent;
                                           encounter_workbench_sound__batteryInserted : string;
                                           transform : float3x4)
  if evt.name == "battery"
    oneshot(encounter_workbench_sound__batteryInserted, transform[3])


[es(tag=sound)]
def encounter_corrupted_workbench_corruption_block_removed_sound(evt : EventWorkbenchCorruptionBlockRemoved;
                                                                 encounter_corrupted_workbench_sound__corruptionBlockRemoved : string;
                                                                 transform : float3x4)
  oneshot(encounter_corrupted_workbench_sound__corruptionBlockRemoved, transform[3])


[es(tag=sound)]
def encounter_workbench_item_repaired_sound(evt : EventWorkbenchItemRepaired;
                                            encounter_workbench_sound__itemRepaired : string;
                                            transform : float3x4)
  oneshot(encounter_workbench_sound__itemRepaired, transform[3])