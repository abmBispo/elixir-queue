defmodule ElixirQueue.EventLoopTest do
  use ExUnit.Case

  alias ElixirQueue.{
    Queue,
    Fake
  }

  setup do
    :ok = Application.stop(:elixir_queue)
    :ok = Application.start(:elixir_queue)
  end

  test "ElixirQueue.EventLoop should resolve ElixirQueue.Queue jobs" do
    assert :ok = Queue.perform_later(Enum, :reverse, [[1,2,3,4,5]])
    assert :ok = Queue.perform_later(Fake, :task, [2])
    assert :ok = Queue.perform_later(Fake, :task, [3])
    :timer.sleep(3)
    assert {:error, :empty} = Queue.fetch()
  end
end
