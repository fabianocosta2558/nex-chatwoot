class Api::V1::Accounts::NexTechnicalQueueController < Api::V1::Accounts::BaseController
  before_action -> { check_authorization(Account) }

  def show
    phone = params[:phone].to_s.gsub(/\D/, '')
    return render json: { error: 'Telefone invalido' }, status: :unprocessable_entity if phone.length < 10

    response = HTTParty.get(
      "#{technical_portal_url}/chatwoot/client",
      headers: technical_headers,
      query: { phone_number: phone },
      timeout: 15
    )
    return render_queue_error(response) unless response.success?

    payload = response.parsed_response
    return render json: { found: false } unless payload['found']

    item = payload.fetch('item')
    item['operational_url'] = "#{ENV.fetch('NEX_OPERATIONAL_URL', 'https://operacional.nexfintech.net/').delete_suffix('/')}?cpf=#{item['cpf'].to_s.gsub(/\D/, '')}"

    render json: { found: true, item: item }
  rescue SocketError, Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED
    render json: { error: 'Fila tecnica indisponivel' }, status: :bad_gateway
  end

  private

  def technical_portal_url
    ENV.fetch('NEX_TECHNICAL_PORTAL_URL').delete_suffix('/')
  end

  def technical_headers
    { 'X-NEX-Portable-Key' => ENV.fetch('NEX_TECHNICAL_PORTAL_KEY') }
  end

  def render_queue_error(response)
    render json: { error: 'Fila tecnica indisponivel' }, status: response.code >= 500 ? :bad_gateway : :unprocessable_entity
  end
end
