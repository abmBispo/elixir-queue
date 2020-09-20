defmodule ElixirQueueTest do
  use ExUnit.Case
  doctest ElixirQueue.Queue
  alias ElixirQueue.Queue

  setup do
    Application.stop(:elixir_queue)
    :ok = Application.start(:elixir_queue)
  end

  test "Queue.dequeue/0 with no job should get {:error, :nojob}" do
    assert {:error, :nojob} = Queue.dequeue()
  end

  test "Queue.enqueue/1 should work" do
    assert :ok = Queue.enqueue(%{foo: "test", baz: "test"})
  end
end
