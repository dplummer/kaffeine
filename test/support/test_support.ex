defmodule TestSupport do
  def with_env(app, key, v) do
    env = Application.fetch_env!(app, key)
    ExUnit.Callbacks.on_exit fn -> Application.put_env(app, key, env) end
    Application.put_env(app, key, v)
    v
  end
end
