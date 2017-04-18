defmodule Kaffeine.SpecTest do
  use ExUnit.Case, async: true

  test "consume a simple setup" do
    assert %Kaffeine.Consumer{topic_name: "foo", handling_mfa: {Foo, :bar, [baz: 1]}} ==
      Kaffeine.Spec.consume("foo", {Foo, :bar, [baz: 1]})
  end
end
