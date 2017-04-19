defmodule Kaffeine.TopicSupervisor do
  def start_link(partition_count, consumer, opts \\ []) do
    import Supervisor.Spec

    supervisor_args(consumer, partition_count)
    |> Enum.map(fn {mod, args, id} -> supervisor(mod, args, id: id) end)
    |> Supervisor.start_link(strategy: :one_for_one, id: opts[:id])
  end

  def supervisor_args(consumer, partition_count) do
    Enum.map(0..partition_count-1, fn partition ->
      {
        Kaffeine.StreamWorker,
        [%{consumer | partition: partition}],
        "Kaffeine.PartitionSupervisor-#{consumer.topic}-#{partition}"
      }
    end)
  end
end
