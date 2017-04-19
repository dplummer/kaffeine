defmodule Kaffeine.Benchmark do
  @type seconds_t :: float

  @spec measure(fun()) :: {seconds_t, any}
  def measure(func) do
    {microseconds, value} = :timer.tc(func)
    {microseconds / 1_000_000, value}
  end
end
