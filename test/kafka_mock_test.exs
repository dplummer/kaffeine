defmodule Kaffeine.KafkaMockTest do
  use ExUnit.Case

  alias KafkaImpl.KafkaMock
  alias KafkaEx.Protocol.Produce.{Request, Message}

  @kafka_impl KafkaImpl.KafkaMock
  @topic "test"
  @partition 0

  setup do
    {:ok, _} = KafkaMock.start_link

    KafkaMock.TestHelper.set_topics([{"test", 1}])

    :ok
  end

  @tag :wip
  test "consume messages" do
    producer = fn n ->
      message = "hey #{n}"
      msg = %Request{topic: @topic, partition: @partition, messages: [%Message{value: message}]}
      assert :ok = @kafka_impl.produce(msg)
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
      assert_receive {:event, %Kaffeine.Event{topic: @topic, partition: @partition, message: ^message}}
    end)
  end

  test "produce messages" do
    {:ok, _pid} = Kaffeine.start(
      [ Kaffeine.producer(@topic, encoder: &{:ok, String.reverse(&1)}), ],
      [ kafka_impl: @kafka_impl, ]
    )

    assert :ok = Kaffeine.produce("hello world", @topic)
    assert ["dlrow olleh"] == KafkaMock.TestHelper.read_messages @topic, @partition
  end

  #  test "produce and comsume together" do
        #Kaffeine.consumer(@topic, fun),
  
  #    IO.inspect 
  #
  #    assert_receive {:event, %Kaffeine.Event{message: "dlrow olleh"}}
  #    
  #  end
end
