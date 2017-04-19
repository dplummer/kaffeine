defmodule Kaffeine.TopicSupervisorTest do
  use ExUnit.Case

  describe ".supervisor_args()" do
    test "builds n initialization tuples for partition supervisors" do
      brokers = [{"localhost", 9092}]
      partition_count = 4
      consumer = %Kaffeine.Spec.Consumer{topic: "legolas", brokers: brokers}

      result = Kaffeine.TopicSupervisor.supervisor_args(
        consumer, partition_count
      )

      expected = [
        {Kaffeine.StreamWorker, [%{consumer | partition: 0}],
          "Kaffeine.PartitionSupervisor-legolas-0"},
        {Kaffeine.StreamWorker, [%{consumer | partition: 1}],
          "Kaffeine.PartitionSupervisor-legolas-1"},
        {Kaffeine.StreamWorker, [%{consumer | partition: 2}],
          "Kaffeine.PartitionSupervisor-legolas-2"},
        {Kaffeine.StreamWorker, [%{consumer | partition: 3}],
          "Kaffeine.PartitionSupervisor-legolas-3"},
      ]

      assert result == expected
    end
  end
end
