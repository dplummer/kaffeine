defmodule Kaffeine.Worker do
  import Kaffeine.Util, only: [opts_or_application: 3, opts_or_application: 4]

  @doc """
  Create a kafka worker. Will fetch options from Application config if not passed in.
  """
  def create_worker(opts \\ []) do
    brokers = case Keyword.fetch(opts, :brokers) do
      {:ok, [_|_] = brokers} -> brokers
      _ ->
        {:ok, brokers} = KafkaImpl.Util.kafka_brokers()
        brokers
    end

    with {:ok, consumer_group} <- opts_or_application(opts, :kafka_ex, :consumer_group),
         {:ok, kafka_version} <- opts_or_application(opts, :kafka_ex, :kafka_version),
         {:ok, kafka_impl} <- opts_or_application(opts, :kafka_impl, :impl, :kafka_impl),
         {:ok, pid} <- kafka_impl.create_no_name_worker(kafka_version, brokers, consumer_group) do
      {:ok, pid}
    else
      error ->
        {:error, "Could not start kafka worker: #{inspect error}"}
    end
  end
end
