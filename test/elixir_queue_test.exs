defmodule ElixirQueueTest do
  use ExUnit.Case
  doctest ElixirQueue.Queue
  alias ElixirQueue.{
    Queue,
    Job
  }

  setup do
    Application.stop(:elixir_queue)
    :ok = Application.start(:elixir_queue)
  end

  test "Queue.fetch/0 with no job should get {:error, :empty}" do
    assert {:error, :empty} = Queue.fetch()
  end

  test "Queue.perform_later/3 should work" do
    assert :ok = Queue.perform_later(Enum, :reverse, [[1,2,3,4,5]])
    assert {:ok, %Job{mod: Enum, func: :reverse, args: [[1,2,3,4,5]]}} = Queue.fetch()
  end
end
