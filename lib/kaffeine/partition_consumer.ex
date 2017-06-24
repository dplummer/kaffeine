defmodule Kaffeine.PartitionConsumer do
  require Logger

  import Kaffeine.Util, only: [log_message: 3, log_message: 4, log_message: 5]

  alias Kaffeine.{Benchmark, Offset}

  def messages(consumer) do
    case do_fetch(consumer) do
      [response] ->
        consumer = process_fetch_response(response, consumer)
        {:ok, consumer}
      :topic_not_found = e ->
        log_message(consumer, "Consumer shutting down", e) |> Logger.error
        {:stop, "Topic '#{consumer.topic}' not found"}
      unhandled ->
        log_message(consumer, "Consumer shutting down", unhandled) |> Logger.error
        {:stop, "Unhandled fetch response"}
    end
  end

  defp process_fetch_response(
    %{partitions: [%{message_set: [_|_] = messages}]},
    consumer
  ) do
    stats(consumer, :increment, "messages.fetched", Enum.count(messages))
    Enum.reduce(messages, consumer, fn (%{offset: offset} = message, consumer) ->
      try_process_fetched_message(message, consumer)

      Offset.commit(offset + 1, consumer)
    end)
  end
  defp process_fetch_response(%{partitions: [%{error_code: :no_error}]}, consumer) do
    # not actually an error
    consumer
  end
  defp process_fetch_response(%{partitions: [%{error_code: error_code}]}, consumer) do
    log_message(consumer, "Error fetching messages", error_code) |> Logger.error
    consumer
  end
  defp process_fetch_response(_, consumer), do: consumer # no messages

  if Application.fetch_env!(:kaffeine, :catch_exceptions) do
    defp try_process_fetched_message(message, consumer) do
      try do
        _ = process_fetched_message(message, consumer)
      rescue
        e ->
          log_message(consumer, message.offset, "Encountered unrecoverable processing error:", e) |> Logger.error
          Logger.error(Exception.format_stacktrace)
      end
    end
  else
    defp try_process_fetched_message(message, consumer) do
      process_fetched_message(message, consumer)
    end
  end

  defp call_processor(message, consumer) do
    case consumer.handler do
      {module, name, args} -> apply(module, name, [message | [ consumer | args]])
      fun -> fun.(message, consumer)
    end
  end

  defp process_fetched_message(%{value: value, offset: offset}, consumer) do
    case consumer.decoder.(value) do
      {:ok, decoded} ->
        log_message(consumer, offset, "Fetched message", decoded) |> Logger.debug

        event = %Kaffeine.Event{
          topic: consumer.topic,
          partition: consumer.partition,
          offset: offset,
          message: decoded,
        }

        (fn -> call_processor(event, consumer) end)
        |> Benchmark.measure
        |> case do
          {t, x} when x in [:ok, :ignore] ->
            stats(consumer, :increment, "messages.processed")

            log_message(consumer, offset, "Processed message", decoded, t) |> Logger.debug
          _ -> nil
        end
      _ ->
        log_message(consumer, offset, "Unexpected decoder response:", value) |> Logger.error
    end
  end

  defp do_fetch(%{
    topic: topic,
    partition: partition,
    worker_pid: worker_pid,
    offset: offset,
    kafka_impl: kafka_impl,
  }) do
    kafka_impl.fetch(
      topic,
      partition,
      [
        worker_name: worker_pid,
        auto_commit: false,
        offset: offset,
      ]
    )
  end

  def stats(consumer, action, key) do
    {module, fun_name, additional_args} = consumer.stats_mfa
    apply(module, fun_name, [action, key | additional_args])
  end

  def stats(consumer, action, key, value) do
    {module, fun_name, additional_args} = consumer.stats_mfa
    apply(module, fun_name, [action, key, value | additional_args])
  end
end
