defmodule KaffeineTest do
  use ExUnit.Case, async: true

  test "consume a simple setup" do
    assert %Kaffeine.Consumer{topic: "foo", handler: {Foo, :bar, [baz: 1]}} =
      Kaffeine.consume("foo", {Foo, :bar, [baz: 1]})
  end

  test "consume with a func for handler" do
    fun = fn _event -> :ok end

    assert %Kaffeine.Consumer{topic: "foo", handler: ^fun} =
      Kaffeine.consume("foo", fun)
  end
end
