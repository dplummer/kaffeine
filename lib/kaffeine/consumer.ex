defmodule Kaffeine.Consumer do
  @moduledoc """
  Convenience functions for defining Kaffeine consumers.
  """

  require Logger

  @type mfa_t :: {module, atom, [any]}
  @type handler_fun_t :: (Kaffeine.Event.t, t -> :ok | {:error, String.t})
  @type brokers_t :: [{binary|charlist, number}]
  @type consumer_group_t :: binary | :no_consumer_group
  @type decoder_fun_t :: (Kaffeine.Event.message_t -> {:ok, any} | {:error, String.t})
  @type stats_fun_t :: (atom, String.t -> any) | (atom, String.t, integer -> any)

  @type t :: %__MODULE__{
    brokers: brokers_t,
    consumer_group: consumer_group_t,
    consumer_wait_ms: integer,
    decoder: decoder_fun_t,
    handler: mfa_t | handler_fun_t,
    kafka_impl: module,
    kafka_version: String.t,
    offset: integer | nil,
    partition: integer,
    stats_mfa: stats_fun_t,
    topic: String.t,
    worker_pid: pid | nil,
  }

  defstruct [
    brokers: nil,
    consumer_group: :no_consumer_group,
    consumer_wait_ms: 2000,
    decoder: &__MODULE__.ok_fun/1,
    handler: &__MODULE__.logger_fun/2,
    kafka_impl: Application.fetch_env!(:kafka_impl, :impl),
    kafka_version: "0.8.2",
    offset: nil,
    partition: nil,
    stats_mfa: {__MODULE__, :stats_fun, []},
    topic: nil,
    worker_pid: nil,
  ]

  @spec ok_fun(Kaffeine.Event.message_t) :: {:ok, Kaffeine.Event.message_t}
  def ok_fun(record), do: {:ok, record}

  @spec logger_fun(Kaffeine.Event.t, Kaffeine.Consumer.t) :: :ok
  def logger_fun(event, _consumer) do
    Logger.debug "Define your handler. Got event: #{inspect(event)}"
  end

  @spec stats_fun(atom, String.t, integer) :: :ok
  def stats_fun(_, _, _ \\ nil), do: :ok

end
