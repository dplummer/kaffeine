defmodule Kaffeine.IntegrationTest do
  use ExUnit.Case

  alias KafkaEx.Protocol.Produce.{Request, Message}

  @kafka_impl KafkaImpl.KafkaEx
  @topic "test"
  @partition 0

  setup do
    {:ok, brokers} = KafkaImpl.Util.kafka_brokers()

    # ensure the test topic is created before trying to consume from it
    {:ok, worker} = Kaffeine.Worker.create_worker(brokers: brokers,
                                                  consumer_group: :no_consumer_group,
                                                  kafka_impl: @kafka_impl)
    msg = %Request{topic: @topic, partition: @partition, messages: [%Message{value: "setup"}]}

    assert :ok = @kafka_impl.produce(msg, worker_name: worker)

    {:ok, worker: worker, brokers: brokers}
  end

  test "consume messages", %{worker: worker, brokers: brokers} do
    producer = fn n ->
      message = "hey #{n}"
      msg = %Request{topic: @topic, partition: @partition, messages: [%Message{value: message}]}
      assert :ok = @kafka_impl.produce(msg, worker_name: worker)
      message
    end

    messages = Enum.map(1..10, producer)

    test_pid = self()

    fun = fn event, _consumer ->
      send test_pid, {:event, event}
      :ok
    end

    {:ok, _pid} = Kaffeine.start(
      [Kaffeine.consumer(@topic, fun)],
      brokers: brokers,
      kafka_impl: @kafka_impl
    )

    Kaffeine.StreamWorker.via_name(@topic, @partition)
    |> Kaffeine.StreamWorker.sync()

    messages |> Enum.each(fn message ->
      assert_receive {:event, %Kaffeine.Event{topic: @topic, partition: @partition, message: ^message}}
    end)

    more_messages = Enum.map(11..20, producer)

    Kaffeine.StreamWorker.via_name(@topic, @partition)
    |> Kaffeine.StreamWorker.sync()

    more_messages |> Enum.each(fn message ->
      assert_receive {:event, %Kaffeine.Event{topic: @topic, partition: @partition, message: ^message}},
        Application.fetch_env!(:kaffeine, :consumer_wait_ms) + 50
    end)
  end

  test "produce messages", %{brokers: brokers} do
    test_pid = self()

    fun = fn event, _consumer ->
      send test_pid, {:event, event}
      :ok
    end

    {:ok, _pid} = Kaffeine.start(
      [
        Kaffeine.producer(@topic, encoder: &{:ok, String.reverse(&1)}),
        Kaffeine.consumer(@topic, fun),
      ],
      [
        brokers: brokers,
        kafka_impl: @kafka_impl,
      ]
    )

    assert :ok = Kaffeine.produce("hello world", @topic)

    assert_receive {:event, %Kaffeine.Event{message: "dlrow olleh"}}
  end
end
