class Campaigns::SendWhatsappCampaignRecipientJob < ApplicationJob
  queue_as :low

  def perform(recipient_id)
    recipient = CampaignRecipient.find_by(id: recipient_id)
    return unless recipient

    recipient.with_lock do
      return unless recipient.scheduled?
      if recipient.campaign.canceled?
        recipient.update!(status: :canceled, canceled_at: Time.current)
        return
      end
      recipient.update!(status: :sending)
    end
    Whatsapp::CampaignRecipientDeliveryService.new(recipient: recipient).perform
  end
end
