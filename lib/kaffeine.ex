defmodule Kaffeine do
  require Logger

  import Kaffeine.Util, only: [opts_or_application: 3, opts_or_application: 4]

  alias Kaffeine.{Partitions, Consumer, TopicSupervisor}

  @moduledoc """
  Documentation for Kaffeine.
  """

  @doc """
  """
  @spec start_consumers(list(Consumer.t), Keyword.t) :: Supervisor.supervisor
  def start_consumers(consumers, opts \\ []) do
    import Supervisor.Spec

    with {:ok, brokers} <- opts_or_application(opts, :kafka_ex, :brokers),
         {:ok, kafka_version} <- opts_or_application(opts, :kafka_ex, :kafka_version),
         {:ok, kafka_impl} <- opts_or_application(opts, :kafka_impl, :impl, :kafka_impl),
         {:ok, partitions} <- Partitions.partition_counts(brokers, kafka_version, kafka_impl)
    do
      Enum.reduce(consumers, [], fn consumer, acc ->
        case Map.get(partitions, consumer.topic, 0) do
          0 ->
            Logger.warn "No partitions found for `#{consumer.topic}`"
            acc

          partition_count ->
            Logger.info "Found #{partition_count} partitions for '#{consumer.topic}'"
            child = supervisor(
              TopicSupervisor,
              [
                partition_count,
                %{consumer | brokers: brokers, kafka_impl: kafka_impl, kafka_version: kafka_version},
              ],
              [
                id: :"Kaffeine.TopicPartitionSupervisor-#{consumer.topic}"
              ]
            )

            [child | acc]
        end
      end)
      |> Supervisor.start_link(strategy: :one_for_one)
    end

  end

  @doc """
  Receives a topic name to consume, and the module, function, and additional arguments of the
  handler.

  Returns a Kaffeine.Consumer struct of the consumer defintion.
  """
  @spec consume(String.t, Consumer.mfa_t | Consumer.handler_fun_t, Keyword.t) :: Consumer.t | :error
  def consume(topic, mfa, opts \\ []) do
    with {:ok, consumer_group} <- opts_or_application(opts, :kafka_ex, :consumer_group),
         {:ok, kafka_version} <- opts_or_application(opts, :kafka_ex, :kafka_version),
         {:ok, consumer_wait_ms} <- opts_or_application(opts, :kaffeine, :consumer_wait_ms)
    do
      %Consumer{
        topic: topic,
        handler: mfa,
        consumer_group: consumer_group,
        kafka_version: kafka_version,
        consumer_wait_ms: consumer_wait_ms,
      }
    end
  end
end
