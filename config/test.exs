use Mix.Config

config :kafka_impl, :impl, KafkaImpl.KafkaMock

config :logger, :console, level: String.to_atom(System.get_env("LOGGER_LEVEL") || "error")

config :kaffeine, consumer_wait_ms: 5
