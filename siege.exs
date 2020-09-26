alias ElixirQueue.{
  Queue,
  Fake
}

IO.puts("The queue is now under the siege...")
:observer.start()

for i <- 0..999 do
  IO.puts("Hit on queue!")

  case rem(i, 3) do
    0 -> Queue.perform_later(Fake, :fake_raise, ["No reason"])
    1 -> Queue.perform_later(Fake, :task, [2])
    2 -> Queue.perform_later(Fake, :task, [3])
  end
end
