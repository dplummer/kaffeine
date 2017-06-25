# Kaffeine

A framework for consuming events from Kafka.

The docs can be found at [https://hexdocs.pm/kaffeine](https://hexdocs.pm/kaffeine).

## Installation

1. Add Kaffeine to your deps.
  ```
  def deps do
    [
      {:kaffeine, "~> 0.1.0"},
    ]
  end
  ```
2. Configure KafkaEx, KafkaImpl, and Kaffeine in your `config/config.exs`:
  ```
  config :kafka_ex,
    # Set to your app name to configure the consumer_group
    consumer_group: "SET ME",

    # Configured at runtime by Kaffeine
    brokers: [],

    # Allow Kaffeine to setup workers at runtime
    disable_default_worker: true,

    # Timeout value, in msec, for synchronous operations (e.g., network calls)
    sync_timeout: 4000,

    # Configure to your version of kafka
    kafka_version: "0.8.2"

  config :kafka_impl, :impl, KafkaImpl.KafkaEx

  config :kaffeine,
    consumer_wait_ms: {:system, "KAFFEINE_CONSUMER_WAIT_MS", 500},
    catch_exceptions: {:system, "KAFFEINE_CATCH_EXCEPTIONS", true}
  ```
3. Create a KafkaConsumer in your app with what topics you want to consume: `lib/my_simple_app/kafka_consumer.ex`:
  ```
  defmodule MySimpleApp.KafkaConsumer do
    def start_link(_opts) do
      [
        Kaffeine.consume("MyTopic", {MySimpleApp.KafkaConsumer, :my_topic, []}, []),
      ]
      |> Kaffeine.start_consumer()
    end

    @spec my_topic(Kaffeine.Event.t, Kaffeine.Consumer.t) :: :ok, {:error, String.t}
    def my_topic(event, _consumer) do
      IO.inspect event
      :ok
    end
  end
  ```
4. Add the KafkaConsumer to your supervision tree:
  ```
  supervisor(MySimpleApp.KafkaConsumer, [])
  ```

## Contributing

Contributions are welcome! In particular, remember to:

* Do not use the issues tracker for help or support requests (try Stack
  Overflow, slack #kaffeine or mailing lists, etc).
* For proposing a new feature, please start a discussion as an issue in the
  issue tracker
* For bugs, do a quick search in the issues tracker and make sure the bug has not yet been reported.
* Finally, be nice and have fun! Remember all interactions in this project follow the same Code of Conduct as Elixir.

## Running tests

```
$ git clone https://github.com/dplummer/kaffeine.git
$ cd kaffeine
$ mix deps.get
$ mix test
```

Besides the unit tests above, it is recommended to run the kafka integration tests too:

```
# Run only Kafka integration tests
mix test.kafka

# Run all tests (unit and kafka integration)
mix test.all
```

## License

[MIT License](https://tldrlegal.com/license/mit-license)
