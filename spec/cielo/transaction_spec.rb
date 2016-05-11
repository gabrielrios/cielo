require 'spec_helper'

describe Cielo::Transaction do
  let(:default_params) { { numero: '1', valor: '1000', bandeira: 'visa', :"url-retorno" => 'http://some.thing.com' } }
  let(:credit_card_params) { { cartao_numero: '4012001038443335', cartao_validade: '201805', cartao_portador: 'Cielo Visa Test Credit Card', cartao_seguranca: '123'} }
  let(:authentication_credit_card_params) { { cartao_numero: '4012001037141112', cartao_validade: '201805', cartao_portador: 'Authentication Cielo Visa Test Credit Card', cartao_seguranca: '123'} }

  describe 'Buy Page Store' do
    before do
      allow(Cielo).to receive(:numero_afiliacao).and_return('1006993069')
      allow(Cielo).to receive(:chave_acesso).and_return('25fbb99741c739dd84d7b06ec78c9bac718838630f30b112d033ce2e621b34f3')

      token = VCR.use_cassette('create_credit_card_token', preserve_exact_body_bytes: true) do
        Cielo::Token.create credit_card_params, :store
      end

      @token_code = token.id
    end

    it 'delivers a successful message - Autorizar sem passar por autenticação' do
      params = default_params.merge(token: @token_code, autorizar: 3)

      response = VCR.use_cassette('buy_page_create_transaction', preserve_exact_body_bytes: true) do
        Cielo::Transaction.new(:store, params).create!
      end

      expect(response[:transacao][:tid]).to_not be_nil
      expect(response[:transacao][:autenticacao][:eci]).to eql('7') # 7 is when transactions was not autenticated
      expect(response[:transacao][:autenticacao][:mensagem]).to eql('Transacao sem autenticacao')
      expect(response[:transacao][:autorizacao][:mensagem]).to eql('Transação autorizada')
      expect(response[:transacao][:captura][:mensagem]).to eql('Transacao capturada com sucesso')
    end

    it 'delivers a successful message and request a card token' do
      params = default_params.merge(:"gerar-token" => true, autorizar: 3).merge(credit_card_params)

      response = VCR.use_cassette('buy_page_create_transaction_and_request_token', preserve_exact_body_bytes: true) do
        Cielo::Transaction.new(:store, params).create!
      end

      expect(response[:transacao][:tid]).to_not be_nil
      expect(response[:transacao][:token][:"dados-token"][:"codigo-token"]).to_not be_nil
    end

    it 'creates a recurring transaction with token' do
      params = default_params.merge(token: @token_code, autorizar: 4) # autorizar: 4 - recurring transaction

      response = VCR.use_cassette('buy_page_create_recurring_transaction_with_token', preserve_exact_body_bytes: true) do
        Cielo::Transaction.new(:store, params).create!
      end

      expect(response[:transacao][:autenticacao][:eci]).to eql('7') # 7 is when transactions was not autenticated
      expect(response[:transacao][:autorizacao][:mensagem]).to eql('Transação autorizada')
    end

    [:cartao_portador, :cartao_numero, :cartao_validade, :cartao_seguranca, :numero, :valor, :bandeira, :"url-retorno"].each do |parameter|
      it "raises an error when #{parameter} isn't informed" do
        params = default_params.merge(credit_card_params)
        expect { Cielo::Transaction.new(:store, params.except!(parameter)) }.to raise_error(Cielo::MissingArgumentError)
      end
    end

    it 'delivers a successful message and catch' do
      params = default_params.merge(authentication_credit_card_params).merge(autorizar: 2, capturar: 'false')
      response = VCR.use_cassette('buy_page_create_authorization_transaction', preserve_exact_body_bytes: true) do
        Cielo::Transaction.new(:store, params).create!
      end
      expect(response[:transacao][:tid]).to_not be_nil
      expect(response[:transacao][:"url-autenticacao"]).to_not be_nil

      response = VCR.use_cassette('buy_page_requisicao_captura', preserve_exact_body_bytes: true) do
        Cielo::Transaction.new(:store).catch!(response[:transacao][:tid])
      end
    end

    it 'verify transaction by number' do
      params = default_params.merge(credit_card_params).merge(autorizar: 3)

      response = VCR.use_cassette('buy_page_verify_by_number', preserve_exact_body_bytes: true) do
        _create_response = Cielo::Transaction.new(:store, params).create!
        Cielo::Transaction.new(:store).verify_by_number!('1')
      end

      expect(response[:transacao][:tid]).to_not be_nil
    end
  end

  describe 'Buy Page Cielo' do
    [:numero, :valor, :bandeira, :"url-retorno"].each do |parameter|
      it "raises an error when #{parameter} isn't informed" do
        expect { Cielo::Transaction.new(:cielo, default_params.except!(parameter)) }.to raise_error(Cielo::MissingArgumentError)
      end
    end

    it 'delivers a successful message' do
      response = VCR.use_cassette('cielo_buy_page_create_authorization_transaction', preserve_exact_body_bytes: true) do
        Cielo::Transaction.new(:cielo, default_params).create!
      end

      expect(response[:transacao][:tid]).to_not be_nil
      expect(response[:transacao][:"url-autenticacao"]).to_not be_nil
      response = VCR.use_cassette('cielo_buy_page_requisicao_captura', preserve_exact_body_bytes: true) do
        Cielo::Transaction.new(:cielo).catch!(response[:transacao][:tid])
      end
    end

    it 'verify the transaction' do
      response = VCR.use_cassette('cielo_buy_page_verify_transaction', preserve_exact_body_bytes: true) do
        Cielo::Transaction.new(:cielo).verify!('100173489800002FDF7A')
      end

      expect(response[:transacao][:tid]).to_not be_nil
      expect(response[:transacao][:status]).to_not be_nil
    end

    it 'returns null when no tid is informed' do
      expect(Cielo::Transaction.new(:cielo).cancel!(nil)).to be_nil
    end

    it 'cancels a transaction' do
      response = VCR.use_cassette('cielo_buy_page_cancel_transaction', preserve_exact_body_bytes: true) do
        create_response = Cielo::Transaction.new(:cielo, default_params).create!
        Cielo::Transaction.new(:cielo).cancel!(create_response[:transacao][:tid])
      end

      # Erro 42 - Cancelamento Não está funcionando em ambiente de teste.
      # expect(response[:transacao][:tid]).to_not be_nil
      # expect(response[:transacao][:status]).to_not be_nil
    end
  end

  describe 'Using a production environment' do
    before do
      Cielo.setup do |config|
        config.environment = :production
        config.numero_afiliacao = '1001734891'
        config.chave_acesso = 'e84827130b9837473681c2787007da5914d6359947015a5cdb2b8843db0fa832'
      end
    end

    it 'must use the production environment' do
      expect(Cielo.numero_afiliacao).to be_eql '1001734891'
    end

    it 'must use the production client number' do
      @connection = Cielo::Connection.new
      expect(@connection.numero_afiliacao).to be_eql '1001734891'
    end

    it 'must use the configuration informed' do
      @connection2 = Cielo::Connection.new '0100100100', 'e84827130b9837473681c2787007da5914d6359947015a5cdb2b8843db0fa800'
      expect(@connection2.numero_afiliacao).to be_eql '0100100100'
      expect(@connection2.chave_acesso).to be_eql 'e84827130b9837473681c2787007da5914d6359947015a5cdb2b8843db0fa800'
    end
  end

  context "XML Generation" do
    it 'does not include access information for non request xml' do
      transaction = Cielo::Transaction.new(:store, default_params.merge(credit_card_params))
      expect(transaction.xml).to_not match(/dados-ec/)
      expect(transaction.xml).to match(/dados-portador/)
    end

    it 'does include access information for request xml' do
      transaction = Cielo::Transaction.new(:store, default_params.merge(credit_card_params))
      expect(transaction.xml(:request)).to match(/xml/)
      expect(transaction.xml(:request)).to match(/dados-ec/)
      expect(transaction.xml).to match(/dados-portador/)
    end
  end
end
