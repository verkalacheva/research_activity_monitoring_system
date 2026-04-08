# frozen_string_literal: true

# Detects when the HTTP client closed the connection (browser closed tab, fetch aborted, etc.).
# Used with Integrations::Client to cancel downstream gRPC when sync_preview is aborted.
module ClientDisconnect
  module_function

  # @param request [ActionDispatch::Request]
  # @return [Boolean] whether the Rack server reports the client socket as closed
  def io_closed?(request)
    io = request.env['puma.socket'] || request.env['rack.hijack_io']
    return false if io.nil?

    io.closed?
  rescue StandardError
    false
  end
end
