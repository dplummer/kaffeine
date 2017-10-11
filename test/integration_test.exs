defmodule Kaffeine.IntegrationTest do
  use ExUnit.Case

  alias KafkaEx.Protocol.Produce.{Request, Message}

  setup do
    {:ok, brokers} = KafkaImpl.Util.kafka_brokers()
    topic = "test"
    partition = 0

    # ensure the test topic is created before trying to consume from it
    {:ok, worker} = Kaffeine.Worker.create_worker(brokers: brokers,
                                                  consumer_group: :no_consumer_group,
                                                  kafka_impl: KafkaImpl.KafkaEx)
    msg = %Request{topic: topic, partition: partition, messages: [%Message{value: "setup"}]}

    assert :ok = KafkaImpl.KafkaEx.produce(msg, worker_name: worker)

    {:ok, worker: worker, brokers: brokers, topic: topic, partition: partition}
  end

  test "consume messages", %{worker: worker, brokers: brokers, topic: topic, partition: partition} do
    test_pid = self()

    fun = fn event, _consumer ->
      send test_pid, {:event, event}
      :ok
    end

    messages = Enum.map(1..10, fn _ ->
      message = "hey #{:rand.uniform(10000)}"
      msg = %Request{topic: topic, partition: partition, messages: [%Message{value: message}]}
      assert :ok = KafkaImpl.KafkaEx.produce(msg, worker_name: worker)
      message
    end)

    {:ok, _pid} = Kaffeine.start(
      [Kaffeine.consumer(topic, fun)],
      brokers: brokers,
      kafka_impl: KafkaImpl.KafkaEx
    )

    Kaffeine.StreamWorker.via_name(topic, partition)
    |> Kaffeine.StreamWorker.sync()

    messages |> Enum.each(fn message ->
      assert_receive {:event, %Kaffeine.Event{topic: ^topic, partition: ^partition, message: ^message}}
    end)

    Kaffeine.StreamWorker.via_name(topic, partition)
    |> Kaffeine.StreamWorker.sync()

    more_messages = Enum.map(1..10, fn _ ->
      message = "hey #{:rand.uniform(10000)}"
      msg = %Request{topic: topic, partition: partition, messages: [%Message{value: message}]}
      assert :ok = KafkaImpl.KafkaEx.produce(msg, worker_name: worker)
      message
    end)

    Kaffeine.StreamWorker.via_name(topic, partition)
    |> Kaffeine.StreamWorker.sync()

    more_messages |> Enum.each(fn message ->
      assert_receive {:event, %Kaffeine.Event{topic: ^topic, partition: ^partition, message: ^message}},
        Application.fetch_env!(:kaffeine, :consumer_wait_ms) + 50
    end)
  end

  test "produce messages", %{brokers: brokers, topic: topic} do
    test_pid = self()

    fun = fn event, _consumer ->
      send test_pid, {:event, event}
      :ok
    end

    {:ok, _pid} = Kaffeine.start(
      [
        Kaffeine.producer(topic,
                          partition_fun: fn _event -> 0 end,
                          encoder: &{:ok, String.reverse(&1)}),
        Kaffeine.consumer(topic, fun),
      ],
      [
        brokers: brokers,
        kafka_impl: KafkaImpl.KafkaEx,
      ]
    )

    assert :ok = Kaffeine.produce("hello world", topic)

    assert_receive {:event, %Kaffeine.Event{message: "dlrow olleh"}}
  end
end
