defmodule Kaffeine.Event do
  @type message_t :: binary()

  @type t :: %__MODULE__{
    topic: String.t,
    partition: integer(),
    offset: integer(),
    message: message_t,
  }

  defstruct [:topic, :partition, :offset, :message]
end
