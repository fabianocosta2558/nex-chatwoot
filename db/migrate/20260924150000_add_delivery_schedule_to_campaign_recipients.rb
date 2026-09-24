class AddDeliveryScheduleToCampaignRecipients < ActiveRecord::Migration[7.1]
  def change
    add_column :campaign_recipients, :scheduled_at, :datetime unless column_exists?(:campaign_recipients, :scheduled_at)
    add_column :campaign_recipients, :canceled_at, :datetime unless column_exists?(:campaign_recipients, :canceled_at)
    add_index :campaign_recipients, [:campaign_id, :scheduled_at] unless index_exists?(:campaign_recipients, [:campaign_id, :scheduled_at])
  end
end
