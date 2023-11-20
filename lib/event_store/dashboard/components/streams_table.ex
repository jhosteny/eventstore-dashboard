defmodule EventStore.Dashboard.Components.StreamsTable do
  use Phoenix.Component

  alias EventStore.Page

  import Phoenix.LiveDashboard.PageBuilder
  import EventStore.Dashboard.Helpers

  # See: https://hexdocs.pm/phoenix_live_dashboard/Phoenix.LiveDashboard.PageBuilder.html

  def render(assigns) do
    ~H"""
    <.live_table
      id="event-store-streams-table"
      dom_id="event-store-streams-table"
      page={@page}
      default_sort_by={:stream_id}
      title="Streams"
      row_attrs={&row_attrs/1}
      row_fetcher={&paginate_streams(@event_store, &1, &2)}
    >
      <:col field={:stream_id} header="Id" sortable={:asc} />
      <:col field={:stream_uuid} header="Stream identity" sortable={:asc} />
      <:col field={:stream_version} header="Version" sortable={:asc} />
      <:col field={:created_at} header="Created at" sortable={:asc} />
      <:col field={:deleted_at} header="Deleted at" sortable={:asc} />
    </.live_table>
    """
  end

  defp paginate_streams(event_store, params, node) do
    %{search: search, sort_by: sort_by, sort_dir: sort_dir, limit: limit} = params

    {:ok, %Page{entries: entries, total_entries: total_entries}} =
      rpc_event_store(node, event_store, :paginate_streams, [
        [page_size: limit, search: search, sort_by: sort_by, sort_dir: sort_dir]
      ])

    entries = Enum.map(entries, &Map.from_struct/1)

    {entries, total_entries}
  end

  defp row_attrs(table) do
    [
      {"phx-click", "show_stream"},
      {"phx-value-stream", table[:stream_uuid]},
      {"phx-page-loading", true}
    ]
  end
end
