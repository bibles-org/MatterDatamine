require ecs
require game.events.events
require DagorRandom


[es(tag=server, REQUIRE=vehicle)]
def paint_cars_on_create(evt : EventEntityCreated; eid : EntityId; car_painting__chance : float; car_painting__possibleColors : Array)
  if gfrnd() > car_painting__chance
    return

  let rndColorNum = grnd() % length(car_painting__possibleColors)
  let colorName = get_string(get_ecs_object(car_painting__possibleColors[rndColorNum]), "color", "")
  if colorName != ""
    addSubTemplate(eid, colorName)
