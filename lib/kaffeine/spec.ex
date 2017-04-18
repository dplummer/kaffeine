defmodule Kaffeine.Spec do
  @moduledoc """
  Convenience functions for defining Kaffeine consumers.
  """

  @type mfa_t :: {module, atom, [term]}

  @doc """
  Receives a topic name to consume, and the module, function, and additional arguments of the
  handler.

  Returns a Kaffeine.Consumer struct of the consumer defintion.
  """
  @spec consume(String.t, mfa_t, Keyword.t) :: Kaffeine.Consumer.t
  def consume(topic_name, {_, _, _} = mfa, _opts \\ []) do
    %Kaffeine.Consumer{
      topic_name: topic_name,
      handling_mfa: mfa,
    }
  end
end
