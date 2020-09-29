defmodule ElixirQueue.QueueTest do
  use ExUnit.Case
  doctest ElixirQueue.Queue
  alias ElixirQueue.{
    EventLoop,
    Queue,
    Job
  }

  setup do
    :ok = Queue.clear()
    Supervisor.terminate_child(ElixirQueue.Supervisor, EventLoop)
  end

  test "Queue.fetch/0 with no job should get {:error, :empty}" do
    assert {:error, :empty} = Queue.fetch()
  end

  test "Queue.perform_later/3 should work" do
    assert :ok = Queue.perform_later(Enum, :reverse, [[1,2,3,4,5]])
    assert {:ok, %Job{mod: Enum, func: :reverse, args: [[1,2,3,4,5]]}} = Queue.fetch()
  end

  test "Queue.clear/0 should work" do
    assert :ok = Queue.perform_later(Enum, :reverse, [[1,2,3,4,5]])
    assert :ok = Queue.clear()
    assert {:error, :empty} = Queue.fetch()
  end
end
