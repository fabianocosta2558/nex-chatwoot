# frozen_string_literal: true

class Whatsapp::CampaignDeliveryScheduleService
  pattr_initialize [:campaign!, :recipients!]

  def at(index)
    day_offset = index / daily_limit
    position = index % daily_limit
    day = first_day + day_offset.days
    start_at, end_at = window_for(day, first: day_offset.zero?)
    start_at, end_at = window_for(day + 1.day, first: false) if start_at >= end_at
    start_at + ((end_at - start_at) * position / daily_limit).floor.seconds
  end

  private

  def settings
    @settings ||= campaign.delivery_settings
  end

  def daily_limit
    value = settings['daily_limit'].to_i
    [100, 200, 250].include?(value) ? value : 100
  end

  def time_zone
    @time_zone ||= ActiveSupport::TimeZone['America/Sao_Paulo']
  end

  def first_day
    campaign.started_at.in_time_zone(time_zone).to_date
  end

  def window_for(date, first:)
    start_hour, start_minute = parse_time(settings['window_start'].presence || '08:00')
    end_hour, end_minute = parse_time(settings['window_end'].presence || '18:00')
    start_at = time_zone.local(date.year, date.month, date.day, start_hour, start_minute)
    end_at = time_zone.local(date.year, date.month, date.day, end_hour, end_minute)
    end_at += 1.day if end_at <= start_at
    start_at = [start_at, campaign.started_at.in_time_zone(time_zone)].max if first
    [start_at, end_at]
  end

  def parse_time(value)
    value.to_s.split(':', 2).map(&:to_i)
  end
end
