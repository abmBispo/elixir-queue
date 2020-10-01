linked_list = Enum.to_list(1..300_000)
{_, tuple} = Enum.map_reduce(1..300_000, {}, fn (x, acc) -> {x, Tuple.append(acc, x)} end)

Benchee.run(%{
  "Insert element at end of linked list"  => fn -> List.insert_at(linked_list, -1, 0) end,
  "Insert element at end of tuple"        => fn -> Tuple.append(tuple, 0) end,
})
