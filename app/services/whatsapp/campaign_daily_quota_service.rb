# frozen_string_literal: true

# A last line of defence for WhatsApp campaigns. The scheduler spreads a
# campaign over several days, but this reservation is also checked at send
# time so concurrent campaigns using the same inbox can never exceed the
# operational daily cap.
class Whatsapp::CampaignDailyQuotaService
  MAX_DAILY_MESSAGES = 250
  TIME_ZONE = ActiveSupport::TimeZone['America/Sao_Paulo']

  pattr_initialize [:recipient!]

  def reserve_or_reschedule!
    CampaignRecipient.transaction do
      lock_inbox_day!
      return true if messages_reserved_today < MAX_DAILY_MESSAGES

      reschedule_for_next_slot!
      false
    end
  end

  private

  def campaign
    recipient.campaign
  end

  def inbox
    recipient.inbox
  end

  def day
    Time.current.in_time_zone(TIME_ZONE).to_date
  end

  def day_range(date = day)
    TIME_ZONE.local(date.year, date.month, date.day).utc..TIME_ZONE.local(date.year, date.month, date.day).end_of_day.utc
  end

  def lock_inbox_day!
    # PostgreSQL advisory locks serialize quota checks for one inbox/day
    # without locking unrelated campaigns or conversations.
    key = "whatsapp-campaign-quota:#{inbox.id}:#{day}"
    CampaignRecipient.connection.execute("SELECT pg_advisory_xact_lock(hashtext(#{CampaignRecipient.connection.quote(key)}))")
  end

  def messages_reserved_today
    CampaignRecipient.where(inbox_id: inbox.id, scheduled_at: day_range)
                     .where(status: %i[sending sent failed])
                     .count
  end

  def reschedule_for_next_slot!
    date = day + 1.day
    loop do
      range = day_range(date)
      count = CampaignRecipient.where(inbox_id: inbox.id, scheduled_at: range)
                              .where.not(status: :canceled).count
      break if count < MAX_DAILY_MESSAGES

      date += 1.day
    end

    start_at, end_at = delivery_window(date)
    position = CampaignRecipient.where(inbox_id: inbox.id, scheduled_at: day_range(date))
                                .where.not(status: :canceled).count
    scheduled_at = start_at + ((end_at - start_at) * position / MAX_DAILY_MESSAGES).floor.seconds
    recipient.update!(status: :scheduled, scheduled_at: scheduled_at, error_message: 'Adiado para respeitar a cota diária de 250 mensagens.')
    Campaigns::SendWhatsappCampaignRecipientJob.set(wait_until: scheduled_at).perform_later(recipient.id)
  end

  def delivery_window(date)
    settings = campaign.delivery_settings
    start_hour, start_minute = parse_time(settings['window_start'] || '08:00')
    end_hour, end_minute = parse_time(settings['window_end'] || '18:00')
    start_at = TIME_ZONE.local(date.year, date.month, date.day, start_hour, start_minute)
    end_at = TIME_ZONE.local(date.year, date.month, date.day, end_hour, end_minute)
    end_at += 1.day if end_at <= start_at
    [start_at, end_at]
  end

  def parse_time(value)
    value.to_s.split(':', 2).map(&:to_i)
  end
end
