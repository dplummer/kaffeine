defmodule Kaffeine.Util do
  def opts_or_application(opts, otp_app, key) do
    opts_or_application(opts, otp_app, key, key)
  end
  def opts_or_application(opts, otp_app, app_key, opt_key) do
    case Keyword.fetch(opts, opt_key) do
      {:ok, _} = x -> x
      :error -> Application.fetch_env(otp_app, app_key)
    end
  end

  def log_message(%{} = consumer, offset, message, detail, duration) when is_float(duration) do
    log_message("[#{consumer.topic}##{consumer.partition} #{offset}] #{Float.round(duration, 2)}s", message, detail)
  end
  def log_message(%{} = consumer, offset, message, detail) do
    log_message("[#{consumer.topic}##{consumer.partition} #{offset}]", message, detail)
  end
  def log_message(%{} = consumer, message, detail) do
    log_message("[#{consumer.topic}##{consumer.partition}]", message, detail)
  end
  def log_message(tag, message, detail) do
    [
      tag,
      message,
      inspect detail
    ]
    |> Enum.join(" ")
  end
end
