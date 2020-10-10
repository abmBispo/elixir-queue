defmodule ElixirQueue.Job do
  defstruct [:mod, :func, :args, :retry_attempts]
end
