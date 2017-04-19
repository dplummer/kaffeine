defmodule Kaffeine.IntegrationTest do
  use ExUnit.Case

  alias KafkaEx.Protocol.Produce.{Request, Message}

  test "consume a message" do
    {:ok, brokers} = KafkaImpl.Util.kafka_brokers()
    test_pid = self()
    topic = "test"
    partition = 0
    message = "hey #{:rand.uniform(10000)}"

    fun = fn event, _consumer ->
      send test_pid, {:event, event}
      :ok
    end

    {:ok, worker} = Kaffeine.Worker.create_worker(brokers: brokers,
                                                  consumer_group: :no_consumer_group,
                                                  kafka_impl: KafkaImpl.KafkaEx)

    msg = %Request{topic: topic, partition: partition, messages: [%Message{value: message}]}
    assert :ok = KafkaImpl.KafkaEx.produce(msg, worker_name: worker)

    {:ok, _pid} = Kaffeine.start_consumers(
      [Kaffeine.Spec.consume("test", fun)],
      brokers: brokers,
      kafka_impl: KafkaImpl.KafkaEx
    )

    Kaffeine.StreamWorker.via_name(topic, partition)
    |> Kaffeine.StreamWorker.sync()

    assert_receive {:event, %Kaffeine.Event{topic: ^topic, partition: ^partition, message: ^message}}
  end
end
