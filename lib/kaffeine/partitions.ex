defmodule Kaffeine.Partitions do
  def partition_counts(brokers, kafka_version, kafka_impl) do
    with {:ok, worker} <- Kaffeine.Worker.create_worker(kafka_version: kafka_version,
                                                        brokers: brokers,
                                                        consumer_group: :no_consumer_group,
                                                        kafka_impl: kafka_impl),
         {:ok, counts} <- partition_counts(kafka_impl, worker),
         :ok <- cleanup(worker)
    do
      {:ok, counts}
    end
  end
  def partition_counts(kafka_impl, worker) when is_pid(worker) do
    %{topic_metadatas: topic_metadatas} = kafka_impl.metadata(worker_name: worker)

    topic_metadatas
    |> Enum.reject(&(String.starts_with?(&1.topic, "_")))
    |> Enum.sort_by(&(&1.topic))
    |> Enum.into(%{}, fn topic_metadata ->
      {topic_metadata.topic, topic_metadata.partition_metadatas |> length}
    end)
    |> (&{:ok, &1}).()
  end

  defp cleanup(worker) when is_atom(worker), do: :ok
  defp cleanup(worker) when is_pid(worker), do: GenServer.stop(worker)
end
