defmodule EventStore.Dashboard.Components.EventsTable do
  use Phoenix.Component

  alias EventStore.Streams.StreamInfo
  alias Phoenix.LiveDashboard.PageBuilder

  import EventStore.Dashboard.Helpers
  import Phoenix.LiveDashboard.PageBuilder

  def render(assigns) do
    %{page: %{params: params}} = assigns

    stream_uuid = parse_stream_uuid(params)

    assigns =
      assigns
      |> assign(:stream_uuid, stream_uuid)

    if event_number = parse_event_number(params) do
      render_event_modal(assigns, event_number)
    else
      render_events(assigns)
    end
  end

  defp parse_stream_uuid(params) do
    case Map.get(params, "stream") do
      "" -> "$all"
      stream when is_binary(stream) -> stream
      nil -> "$all"
    end
  end

  defp parse_event_number(params) do
    case Map.get(params, "event") do
      "" -> nil
      event when is_binary(event) -> String.to_integer(event)
      nil -> nil
    end
  end

  defp render_event_modal(assigns, event_number) do
    assigns =
      assigns
      |> assign(:event_number, event_number)

    ~H"""
    <PageBuilder.live_modal id="modal" title="Event" return_to={modal_return_to(@socket, @page).(@page.node, [])}>
      <.live_component
        id="event"
        module={EventStore.Dashboard.Components.EventModal}
        path={modal_return_to(@socket, @page)}
        return_to={modal_return_to(@socket, @page).(@page.node, [])}
        page={@page}
        node={@page.node}
        event_store={@event_store}
        event_number={@event_number}
        stream_uuid={@stream_uuid}
    />
    </PageBuilder.live_modal>
    """
  end

  defp modal_return_to(socket, %{route: route, params: params}) do
    params = Map.delete(params, "event")
    &PageBuilder.live_dashboard_path(socket, route, &1, params, Enum.into(&2, params))
  end

  defp render_events(%{stream_uuid: "$all"} = assigns) do
    ~H"""
    <.live_table
      id="event-store-events-table"
      dom_id="event-store-events-table"
      page={@page}
      default_sort_by={:event_number}
      title="All stream events:"
      row_fetcher={&read_stream(@event_store, @stream_uuid, &1, &2)}
      row_attrs={&row_attrs(&1, @stream_uuid)}
      rows_name="events"
      search={false}
    >
      <:col field={:event_number} header="Event #" sortable={:asc} />
      <:col field={:event_id} header="Event id" />
      <:col field={:event_type} header="Event type" />
      <:col field={:stream_uuid} header="Source stream" />
      <:col field={:stream_version} header="Source version" />
      <:col field={:created_at} header="Created at" />
    </.live_table>
    """
  end

  defp render_events(assigns) do
    assigns = assigns |> assign(:title, "Stream #{assigns[:stream_uuid]} events")

    ~H"""
    <.live_table
      id="event-store-events-table"
      dom_id="event-store-events-table"
      page={@page}
      default_sort_by={:event_number}
      title={@title}
      row_fetcher={&read_stream(@event_store, @stream_uuid, &1, &2)}
      row_attrs={&row_attrs(&1, @stream_uuid)}
      rows_name="events"
      search={false}
    >
      <:col field={:event_number} header="Event #" sortable={:asc} />
      <:col field={:event_id} header="Event id" />
      <:col field={:event_type} header="Event type" />
      <:col field={:created_at} header="Created at" />
    </.live_table>
    """
  end

  defp read_stream(event_store, stream_uuid, params, node) do
    with {:ok, %StreamInfo{} = stream} <- stream_info(node, event_store, stream_uuid),
         {:ok, recorded_events} <- recorded_events(node, event_store, stream_uuid, params) do
      %StreamInfo{stream_version: stream_version} = stream

      entries = Enum.map(recorded_events, &Map.from_struct/1)

      {entries, stream_version}
    else
      {:error, _error} -> {[], 0}
    end
  end

  defp stream_info(node, event_store, stream_uuid) do
    rpc_event_store(node, event_store, :stream_info, [stream_uuid])
  end

  defp recorded_events(node, event_store, stream_uuid, params) do
    %{sort_by: _sort_by, sort_dir: sort_dir, limit: limit} = params

    {read_stream_function, start_version} =
      case sort_dir do
        :asc -> {:read_stream_forward, 0}
        :desc -> {:read_stream_backward, -1}
      end

    rpc_event_store(node, event_store, read_stream_function, [stream_uuid, start_version, limit])
  end

  defp row_attrs(table, stream_uuid) do
    [
      {"phx-click", "show_event"},
      {"phx-value-stream", stream_uuid},
      {"phx-value-event", table[:event_number]},
      {"phx-page-loading", true}
    ]
  end
end
