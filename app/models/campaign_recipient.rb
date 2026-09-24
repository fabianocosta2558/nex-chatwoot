# frozen_string_literal: true

# A frozen, auditable recipient list for an individual WhatsApp campaign.
# It prevents a restart or retry from sending the same campaign to a contact twice.
class CampaignRecipient < ApplicationRecord
  belongs_to :account
  belongs_to :campaign
  belongs_to :contact
  belongs_to :inbox

  enum status: { pending: 0, scheduled: 1, sending: 2, sent: 3, skipped: 4, failed: 5, canceled: 6 }

  validates :contact_id, uniqueness: { scope: :campaign_id }
end
