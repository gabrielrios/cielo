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
end
