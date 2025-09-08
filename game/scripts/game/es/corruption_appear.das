require ecs


[es(on_appear, REQUIRE_NOT=item__cantBeCorrupted)]
def try_appear_corruption_on_item(evt : Event;
                                  eid : EntityId;
                                  item__wantToBeCorrupted : bool)
  if item__wantToBeCorrupted
    eid |> addSubTemplate("item_enriched")


[es(on_appear, REQUIRE_NOT=item__cantBeReplica)]
def try_appear_replica_on_item(evt : Event;
                               eid : EntityId;
                               item__wantToBeReplica : bool)
  if item__wantToBeReplica
    eid |> addSubTemplate("item_replica")
