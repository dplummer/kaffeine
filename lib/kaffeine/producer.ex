defmodule Kaffeine.Producer do
  use GenServer

  alias KafkaEx.Protocol.Produce.Request, as: ProduceRequest
  alias KafkaEx.Protocol.Produce.Message

  @moduledoc """
  Kafka message producer handler. See Kaffeine for usage.
  """

  require Logger

  @type brokers_t :: [{binary|charlist, number}]
  @type encoder_fun_t :: (any -> {:ok, any} | {:error, String.t})
  @type partitioner_fun_t :: (any, integer -> {:ok, integer} | {:error, String.t})

  @type t :: %__MODULE__{
    brokers: brokers_t,
    encoder: encoder_fun_t,
    kafka_impl: module,
    kafka_version: String.t,
    max_partitions: integer,
    name: atom,
    partitioner: partitioner_fun_t,
    required_acks: integer,
    timeout: integer,
    topic: String.t,
    worker_pid: pid | nil,
  }

  defstruct [
    brokers: nil,
    encoder: &__MODULE__.ok_fun/1,
    kafka_impl: Application.fetch_env!(:kafka_impl, :impl),
    kafka_version: "0.8.2",
    max_partitions: nil,
    name: nil,
    partitioner: &__MODULE__.zero_fun/2,
    required_acks: 0,
    timeout: 200,
    topic: nil,
    worker_pid: nil,
  ]

  @doc false
  @spec ok_fun(any) :: {:ok, any}
  def ok_fun(record), do: {:ok, record}

  @doc false
  @spec zero_fun(any, integer) :: {:ok, 0}
  def zero_fun(_message, _max_partitions), do: {:ok, 0}

  @doc false
  def child_spec(producer) do
    %{
      id: :"Kaffeine.Producer-#{producer.name}",
      start: { __MODULE__, :start_link, [producer]},
      restart: :permanent,
      shutdown: 5000,
      type: :worker
    }
  end

  @doc false
  def start_link(producer) do
    GenServer.start_link(__MODULE__, producer, [name: get_worker_name(producer.topic)])
  end

  @doc false
  def init(producer) do
    {:ok, pid} = Kaffeine.Worker.create_worker(brokers: producer.brokers,
                                               consumer_group: :no_consumer_group,
                                               kafka_version: producer.kafka_version,
                                               kafka_impl: producer.kafka_impl)

    partitioner = fn message -> producer.partitioner.(message, producer.max_partitions) end

    {:ok, %{producer | worker_pid: pid, partitioner: partitioner}}
  end

  @doc false
  @spec produce(any, String.t, String.t | nil) :: :ok
  def produce(message, topic, key) do
    worker_name = get_worker_name(topic)
    {:ok, encoder, partitioner} = GenServer.call(worker_name, :get_funs)
    {:ok, value} = encoder.(message)
    {:ok, partition} = partitioner.(message)
    GenServer.call(worker_name, {:produce, value, partition, key})
  end

  @doc false
  def handle_call(:get_funs, _from, producer) do
    {:reply, {:ok, producer.encoder, producer.partitioner}, producer}
  end

  @doc false
  def handle_call({:produce, value, partition, key}, _from, producer) do
    produce_request = %ProduceRequest{
      topic: producer.topic,
      partition: partition,
      required_acks: producer.required_acks,
      timeout: producer.timeout,
      compression: :none,
      messages: [%Message{key: key, value: value}]
    }

    producer.kafka_impl.produce(produce_request,
                                worker_name: producer.worker_pid)

    {:reply, :ok, producer}
  end

  def get_worker_name(topic), do: :"kaffeine_producer_#{topic}"
end
