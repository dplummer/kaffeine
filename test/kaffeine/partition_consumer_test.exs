defmodule Kaffeine.PartitionConsumerTest do
  use ExUnit.Case, async: true

  alias KafkaImpl.KafkaMock

  test "fetch messages" do
    {:ok, _kafka} = KafkaMock.start_link
    topic = "test"
    partition = 0
    offset = 0
    message = "foo"
    test_pid = self()

    KafkaMock.TestHelper.send_message(test_pid, {topic, partition, %KafkaEx.Protocol.Fetch.Message{offset: offset, value: message}, offset})

    consumer = %Kaffeine.Consumer{
      topic: topic,
      partition: partition,
      offset: offset,
      handler: (fn event, consumer -> send test_pid, {:event, event, consumer} end),
      worker_pid: :no_worker,
    }

    assert {:ok, _} = Kaffeine.PartitionConsumer.messages(consumer)

    assert_received {:event, %Kaffeine.Event{message: "foo", topic: ^topic, partition: ^partition}, _}
  end
end
