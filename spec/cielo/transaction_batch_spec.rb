require 'spec_helper'

RSpec.describe Cielo::TransactionBatch do
  let(:default_params) { { numero: '1', valor: '1000', bandeira: 'visa', :"url-retorno" => 'http://some.thing.com' } }
  let(:credit_card_params) { { cartao_numero: '4012001038443335', cartao_validade: '201805', cartao_portador: 'Cielo Visa Test Credit Card', cartao_seguranca: '123'} }

  let(:transaction_params) { default_params.merge(credit_card_params) }

  it 'generates xml for all transactions' do
    transactions = 2.times.map{|t| Cielo::Transaction.new(:store, transaction_params) }
    batch = Cielo::TransactionBatch.new('9999', '2', transactions)
    xml = batch.xml

    xml_transactions = xml.scan('<requisicao-transacao>')
    expect(xml_transactions.size).to eq(2)
  end

  it 'includes connection data' do
    transactions = 2.times.map{|t| Cielo::Transaction.new(:store, transaction_params) }
    batch = Cielo::TransactionBatch.new('9999', '2', transactions)
    xml = batch.xml
    expect(xml).to match(/dados-ec/)
  end

  it 'delivers a successful file' do
    transactions = 2.times.map{|t| Cielo::Transaction.new(:store, transaction_params) }
    batch = Cielo::TransactionBatch.new('999', '2', transactions)

    response = VCR.use_cassette('upload_batch_file') do
      batch.create!
    end

    expect(response[:'retorno-upload-lote'][:'mensagem']).to match(/Seu lote está válido/)
  end

  it 'returns proper error' do
    transactions = 2.times.map{|t| Cielo::Transaction.new(:store, transaction_params) }
    batch = Cielo::TransactionBatch.new('999', '2', transactions)

    response = VCR.use_cassette('duplicate_upload_batch_file') do
      batch.create!
      batch.create!
    end

    expect(response[:'erro']).to be_present
    expect(response[:'erro'][:'mensagem']).to match(/Número de lote já existente/)
  end

  it 'receives the batch response' do
    transactions = 2.times.map{|t| Cielo::Transaction.new(:store, transaction_params) }
    batch = Cielo::TransactionBatch.new('999', '2', transactions)

    response = VCR.use_cassette('receive_batch_file') do
      batch.receive!
    end

    expect(response[:'retorno-download-lote']).to be_present
  end
end
