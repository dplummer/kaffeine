defmodule Kaffeine.Offset do
  require Logger

  def fetch(consumer) do
    earliest_offset = case earliest_offset(consumer) do
      {:ok, offset} when offset > 0 -> offset
      _ -> 0
    end

    consumer_group_offset = case consumer_group_offset(consumer) do
      offset when offset > 0 -> offset
      _ -> 0
    end

    max(earliest_offset, consumer_group_offset)
  end

  def commit(offset, consumer) do
    request = KafkaEx.Protocol.OffsetCommit.Request
      |> struct(Map.take(consumer, [:topic, :partition, :consumer_group, :offset]))

    Logger.debug "Committing offset #{offset} for #{consumer.topic}##{consumer.partition}"

    consumer.kafka_impl.offset_commit(consumer.worker_pid, request)

    %{consumer | offset: offset}
  end

  defp earliest_offset(consumer) do
    consumer.kafka_impl.earliest_offset(consumer.topic, consumer.partition, consumer.worker_pid)
    |> KafkaImpl.Util.extract_offset()
  end

  defp consumer_group_offset(consumer) do
    request = KafkaEx.Protocol.OffsetFetch.Request
      |> struct(Map.take(consumer, [:topic, :partition, :consumer_group]))

    case consumer.kafka_impl.offset_fetch(consumer.worker_pid, request) do
      [%{partitions: [%{last_offset: offset}]}] when is_integer(offset) -> offset
      [%{partitions: [%{offset: offset}]}] when is_integer(offset) -> offset
      _ -> 0
    end
  end
end
