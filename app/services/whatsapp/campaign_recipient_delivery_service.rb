# frozen_string_literal: true

class Whatsapp::CampaignRecipientDeliveryService
  pattr_initialize [:recipient!]

  def perform
    campaign = recipient.campaign
    return cancel_recipient if campaign.canceled?

    destination, destination_error = destination_for
    return skip!(destination_error) if destination.blank?
    return skip!('Template parameters are missing') if campaign.template_params.blank?

    params = Whatsapp::LiquidTemplateProcessorService.new(campaign: campaign, contact: recipient.contact)
                                                      .process_template_params(campaign.template_params)
    return skip!('A dynamic template value is empty') if params.nil?
    return skip!('Authentication template is unavailable for this contact') if authentication_template_blocked?(destination, params)

    name, namespace, lang_code, parameters = Whatsapp::TemplateProcessorService.new(
      channel: campaign.inbox.channel, template_params: params
    ).call
    return fail!('Template not found or not approved') if name.blank?

    source_id = campaign.inbox.channel.send_template(destination, {
      name: name, namespace: namespace, lang_code: lang_code, parameters: parameters
    }, nil)
    return fail!('WhatsApp provider rejected the send') if source_id.blank?

    recipient.update!(status: :sent, source_id: source_id, sent_at: Time.current)
  rescue StandardError => e
    Rails.logger.error "Campaign recipient #{recipient.id} failed: #{e.class}: #{e.message}"
    fail!(e.message)
  ensure
    recipient.campaign.complete_delivery_if_finished!
  end

  private

  def destination_for
    contact = recipient.contact
    return [contact.phone_number, nil] if contact.phone_number.present?

    identities = contact.contact_inboxes.where(inbox_id: recipient.inbox_id).select do |contact_inbox|
      contact_inbox.source_id.to_s.delete_prefix('whatsapp:').match?(RegexHelper::WHATSAPP_BSUID_REGEX)
    end
    return [nil, 'Phone number and WhatsApp identity are missing'] if identities.empty?
    return [identities.first.source_id, nil] if identities.one?

    [nil, 'Multiple WhatsApp identities found']
  end

  def authentication_template_blocked?(destination, params)
    Whatsapp::AuthenticationTemplateGuard.new(channel: recipient.inbox.channel, recipient: destination, template_params: params).error.present?
  end

  def skip!(message)
    recipient.update!(status: :skipped, error_message: message)
  end

  def fail!(message)
    recipient.update!(status: :failed, error_message: message, failed_at: Time.current)
  end

  def cancel_recipient
    recipient.update!(status: :canceled, canceled_at: Time.current)
  end
end
