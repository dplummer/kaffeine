defmodule Kaffeine do
  require Logger

  import Kaffeine.Util, only: [opts_or_application: 3, opts_or_application: 4]

  alias Kaffeine.{
    Consumer,
    Partitions,
    Producer,
    TopicSupervisor,
  }

  @moduledoc """
  Documentation for Kaffeine.
  """

  @doc """
  """
  @spec start(list(Consumer.t), Keyword.t) :: Supervisor.supervisor
  def start(consumers, opts \\ []) do
    import Supervisor.Spec
    super_opts = [{:strategy, :one_for_one} | Keyword.take(opts, [:name])]

    with {:ok, brokers} <- opts_or_application(opts, :kafka_ex, :brokers),
         {:ok, kafka_version} <- opts_or_application(opts, :kafka_ex, :kafka_version),
         {:ok, kafka_impl} <- opts_or_application(opts, :kafka_impl, :impl, :kafka_impl),
         {:ok, partitions} <- Partitions.partition_counts(brokers, kafka_version, kafka_impl)
    do
      consumers
      |> Enum.reduce([],
      fn
        %Consumer{} = consumer, acc ->
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
        %Producer{} = producer, acc ->
          child = worker(Producer, [
            %{ producer |
              brokers: brokers,
              kafka_impl: kafka_impl,
              kafka_version: kafka_version,
              max_partitions: Map.get(partitions, producer.topic, 1),
            }
          ],
          [
            id: :"Kaffeine.Producer.#{producer.topic}",
          ])
          [child | acc]
      end
      )
      |> Supervisor.start_link(super_opts)
    end

  end

  @doc """
  Receives a topic name to consume, and the module, function, and additional arguments of the
  handler.

  Returns a Kaffeine.Consumer struct of the consumer defintion.
  """
  @spec consumer(String.t, Consumer.mfa_t | Consumer.handler_fun_t, Keyword.t) :: Consumer.t | :error
  def consumer(topic, mfa, opts \\ []) do
    with {:ok, consumer_group} <- opts_or_application(opts, :kafka_ex, :consumer_group),
         {:ok, consumer_wait_ms} <- opts_or_application(opts, :kaffeine, :consumer_wait_ms, fn app, key -> EnvConfig.get_integer(app, key) end)
    do
      %Consumer{
        topic: topic,
        handler: mfa,
        consumer_group: consumer_group,
        consumer_wait_ms: consumer_wait_ms,
      }
    end
  end

  @doc """
  Build the configuration for a produce worker for a specific topic.

  ex: `producer("NewMessage",
    encoder: &Poison.encode/1,
    partitioner: fn message, max_partitions -> {:ok, rem(message.user_id, max_partitions)} end)`

  opts:

  * `encoder`
    `(any -> {:ok, any} | {:error, String.t})`

    An anonymous function that is used when producing messages to encode for Kafka.

    ex: `fn message -> {:ok, Poison.encode(message)} end`

  * `partitioner`
    `(any -> {:ok, integer} | {:error, String.t})`

    An anonymous function that is used to determine which partition to put the message in. Is
    passed the message and the max number of partitions for the topic.

    ex: `fn message, max_partitions -> {:ok, rem(message.user_id, max_partitions)} end`

  * `required_acks`

    Required acknowledgements by kafka brokers before considered successful.

  * `timeout`

    Request timeout in milliseconds.

  """
  def producer(topic, opts \\ []) do
    struct(%Producer{topic: topic}, opts)
  end

  @doc """
  Produce a message to a given topic. A Producer must already be setup for the topic you wish to
  write to.

  ## Examples

      iex> Kaffeine.produce("hello world", "test")
      :ok

      iex> Kaffeine.produce(%{id: 501, name: "Bob"}, "Users")
      :ok
  """
  @spec produce(any, String.t, String.t | nil) :: :ok
  def produce(message, topic, key \\ nil) do
    Producer.produce(message, topic, key)
  end
end
