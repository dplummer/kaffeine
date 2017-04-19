defmodule Kaffeine do
  require Logger

  import Kaffeine.Util, only: [opts_or_application: 3, opts_or_application: 4]

  @moduledoc """
  Documentation for Kaffeine.
  """

  @doc """
  """
  @spec start_consumers(list(Consumer.t), Keyword.t) :: Supervisor.supervisor
  def start_consumers(consumers, opts \\ []) do
    import Supervisor.Spec

    with {:ok, brokers} <- opts_or_application(opts, :kafka_ex, :brokers),
         {:ok, kafka_version} <- opts_or_application(opts, :kafka_ex, :kafka_version),
         {:ok, kafka_impl} <- opts_or_application(opts, :kafka_impl, :impl, :kafka_impl),
         {:ok, partitions} <- partition_counts(brokers, kafka_version, kafka_impl)
    do
      Enum.reduce(consumers, [], fn consumer, acc ->
        case Map.get(partitions, consumer.topic, 0) do
          0 ->
            Logger.warn "No partitions found for `#{consumer.topic}`"
            acc

          partition_count ->
            Logger.info "Found #{partition_count} partitions for '#{consumer.topic}'"
            child = supervisor(
              Kaffeine.TopicSupervisor,
              [
                partition_count,
                %{consumer | brokers: brokers, kafka_impl: kafka_impl, kafka_version: kafka_version},
              ],
              [
                id: :"Kaffeine.TopicPartitionSupervisor-#{consumer.topic}"
              ]
            )

            [child | acc]
        end
      end)
      |> Supervisor.start_link(strategy: :one_for_one)
    end

  end

  def partition_counts(brokers, kafka_version, kafka_impl) do
    with {:ok, worker} <- Kaffeine.Worker.create_worker(kafka_version: kafka_version, brokers: brokers, consumer_group: :no_consumer_group, kafka_impl: kafka_impl),
         %{topic_metadatas: topic_metadatas} <- kafka_impl.metadata(worker_name: worker),
         :ok <- cleanup(worker)
    do
      counts = topic_metadatas
        |> Enum.reject(&(String.starts_with?(&1.topic, "_")))
        |> Enum.sort_by(&(&1.topic))
        |> Enum.into(%{}, fn topic_metadata ->
          {topic_metadata.topic, topic_metadata.partition_metadatas |> length}
        end)

      {:ok, counts}
    end
  end

  defp cleanup(worker) when is_atom(worker), do: :ok
  defp cleanup(worker) when is_pid(worker), do: GenServer.stop(worker)
end
