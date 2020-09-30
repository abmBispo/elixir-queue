defmodule ElixirQueue.FakeTest do
  use ExUnit.Case
  alias ElixirQueue.Fake

  setup do
    :ok = Application.stop(:elixir_queue)
    :ok = Application.start(:elixir_queue)
  end

  test "Fake.fake_raise/0 should raise a RuntimeError" do
    assert_raise(RuntimeError, fn -> Fake.fake_raise("oh noes") end)
  end

  test "Fake.task/1 should work" do
    assert 2 == Fake.task(2)
    assert 3 == Fake.task(3)
  end

  test "Fake.populate/0 should populate queue and returns :ok atom" do
    assert :ok = Fake.populate()
    spec = Fake.spec()
    assert Map.has_key?(spec, "Successful jobs count")
    assert Map.has_key?(spec, "Failed jobs count")
    assert Map.has_key?(spec, "Successful jobs count by Worker PID")
    assert Map.has_key?(spec, "Failed jobs count by Worker PID")
  end
end
