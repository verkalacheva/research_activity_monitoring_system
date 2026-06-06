class ReportsChannel < ApplicationCable::Channel
  def subscribed
    admin_id = current_user.admin_owner_id
    stream_from "reports_channel:#{admin_id}"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end







