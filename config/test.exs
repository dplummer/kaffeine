use Mix.Config

config :kafka_impl, :impl, KafkaImpl.KafkaMock

config :logger, :console, level: :error

config :kaffeine, consumer_wait_ms: 5
