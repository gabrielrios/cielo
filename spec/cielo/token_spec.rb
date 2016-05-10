require 'spec_helper'

describe Cielo::Token do
  let(:card_params) { { cartao_numero: '4012001038443335', cartao_validade: '201805', cartao_portador: 'Cielo Visa Test Credit Card' } }
  let(:connection) { Cielo::Connection.new(1006993069, '25fbb99741c739dd84d7b06ec78c9bac718838630f30b112d033ce2e621b34f3') }
  let(:token) { Cielo::Token.new(connection) }

  describe 'create a token for a card' do
    it 'delivers an successful message and have a card token' do
      response = VCR.use_cassette('create_credit_card_token', preserve_exact_body_bytes: true) do
        Cielo::Token.create(card_params, :store)
      end

      expect(response.id).to eq('l34tEKLz5inbugHGkpZx6I1kBZW8qoysmfxiyN8zhO8=')
      expect(response.masked_card).to eq('401200******3335')
      expect(response.status).to eq('1')
    end
  end
end
