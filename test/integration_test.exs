defmodule Kaffeine.IntegrationTest do
  use ExUnit.Case

  alias KafkaEx.Protocol.Produce.{Request, Message}

  test "consume messages" do
    {:ok, brokers} = KafkaImpl.Util.kafka_brokers()
    test_pid = self()
    topic = "test"
    partition = 0

    fun = fn event, _consumer ->
      send test_pid, {:event, event}
      :ok
    end

    {:ok, worker} = Kaffeine.Worker.create_worker(brokers: brokers,
                                                  consumer_group: :no_consumer_group,
                                                  kafka_impl: KafkaImpl.KafkaEx)

    messages = Enum.map(1..10, fn _ ->
      message = "hey #{:rand.uniform(10000)}"
      msg = %Request{topic: topic, partition: partition, messages: [%Message{value: message}]}
      assert :ok = KafkaImpl.KafkaEx.produce(msg, worker_name: worker)
      message
    end)

    {:ok, _pid} = Kaffeine.start_consumers(
      [Kaffeine.consume("test", fun)],
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
end
