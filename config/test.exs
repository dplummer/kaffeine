use Mix.Config

config :kafka_impl, :impl, KafkaImpl.KafkaMock

config :logger, :console, level: :error
