defmodule Kaffeine.StreamWorker do
  use GenServer

  require Logger

  import Kaffeine.Util, only: [log_message: 3]

  alias Kaffeine.{PartitionConsumer, Worker, Offset}

  @spec start_link(State.t) :: GenServer.on_start
  def start_link(consumer, _ \\ []) do
    GenServer.start_link(
      __MODULE__,
      consumer,
      [name: via_name(consumer.topic, consumer.partition)]
    )
  end

  def via_name(topic, partition) do
    {:via, Registry, {Registry.Kaffeine.Consumers, {topic, partition}}}
  end

  def init(state) do
    with {:ok, worker_pid} <- Worker.create_worker(brokers: state.brokers,
                                                   kafka_version: state.kafka_version,
                                                   kafka_impl: state.kafka_impl,
                                                   consumer_group: state.consumer_group),
         state = %{state | worker_pid: worker_pid},
         state = %{state | offset: Offset.fetch(state)},
         :ok   <- begin_streaming()
    do
      log_message(state, "Beginning streaming at offset", state.offset) |> Logger.debug
      {:ok, state}
    else
      {:error, error} ->
        log_message(state, "Consumer shutting down", error) |> Logger.error
        {:stop, error}
    end
  end

  def sync(server) do
    GenServer.call(server, :sync)
  end

  def handle_call(:sync, _from, state) do
    {:reply, :ok, state}
  end

  def handle_info(:fetch, state) do
    case PartitionConsumer.messages(state) do
      {:ok, state} ->
        Process.send_after(self(), :fetch, state.consumer_wait_ms)
        {:noreply, state}
      {:stop, _msg} = x -> x
    end
  end
  def handle_info(_, state), do: {:noreply, state}

  defp begin_streaming() do
    send self(), :fetch
    :ok
  end

end
