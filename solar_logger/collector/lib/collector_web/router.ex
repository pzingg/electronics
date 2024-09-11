defmodule CollectorWeb.Router do
  use CollectorWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {CollectorWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", CollectorWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/samples", PageController, :samples

    live "/graph", GraphLive.Show, :show
    live "/graph/edit", GraphLive.Show, :edit
  end

  scope "/", CollectorWeb do
    pipe_through :api

    put "/", PageController, :import
  end
end
