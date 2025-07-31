defmodule ThundertabWeb.ErrorJSONTest do
  use ThundertabWeb.ConnCase, async: true

  test "renders 404" do
    assert ThundertabWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert ThundertabWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
