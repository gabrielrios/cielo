require 'bigdecimal'
module Cielo
  class Transaction
    attr_reader :numero_afiliacao
    attr_reader :chave_acesso
    attr_reader :versao

    def initialize(buy_page = :cielo, parameters = {})
      @buy_page = buy_page
      @parameters = parameters
      analysis_parameters
      @connection = Cielo::Connection.new
    end

    attr_reader :parameters, :buy_page

    def xml(type = :raw)
      build_xml_for(type).target!
    end

    def create!
      @connection.make_request!(build_xml_for(:request))
    end

    def verify!(cielo_tid)
      return nil unless cielo_tid
      message = @connection.xml_builder('requisicao-consulta') do |xml, target|
        xml.tid cielo_tid.to_s if target == :before
      end

      @connection.make_request! message
    end

    def verify_by_number!(order_number)
      return nil unless order_number
      message = @connection.xml_builder('requisicao-consulta-chsec') do |xml, target|
        xml.tag! 'numero-pedido', order_number if target == :before
      end

      @connection.make_request! message
    end

    def catch!(cielo_tid)
      return nil unless cielo_tid
      message = @connection.xml_builder('requisicao-captura') do |xml, target|
        xml.tid cielo_tid.to_s if target == :before
      end
      @connection.make_request! message
    end

    def authorize!(cielo_tid)
      return nil unless cielo_tid
      message = @connection.xml_builder('requisicao-autorizacao-tid') do |xml, target|
        xml.tid cielo_tid.to_s if target == :before
      end
      @connection.make_request! message
    end

    def cancel!(cielo_tid, valor = 0)
      return nil unless cielo_tid
      message = @connection.xml_builder('requisicao-cancelamento') do |xml, target|
        xml.tid cielo_tid.to_s if target == :before
        xml.valor valor.to_s if target == :after && BigDecimal.new(valor) > 0
      end
      @connection.make_request! message
    end

    private
    def build_xml_for(type)
      _proc = method("build_#{buy_page}_xml")
      if type == :request
        @connection.xml_builder('requisicao-transacao', &_proc)
      else
        builder = Builder::XmlMarkup.new(:indent => 2)
        builder.tag!('requisicao-transacao') { _proc.call(builder, :after) }
        builder
      end
    end

    def build_store_xml(xml, target)
      if target == :after
        xml.tag!('dados-portador') do
          if parameters[:token].present?
            xml.tag!('token', parameters[:token])
          else
            xml.tag!('numero', parameters[:cartao_numero])
            xml.tag!('validade', parameters[:cartao_validade])
            xml.tag!('indicador', parameters[:cartao_indicador])
            xml.tag!('codigo-seguranca', parameters[:cartao_seguranca])
            xml.tag!('nome-portador', parameters[:cartao_portador])
            xml.tag!('token', '')
          end
        end
        default_transaction_xml(xml)
      end
    end

    def build_cielo_xml(xml, target)
      if target == :after
        default_transaction_xml(xml)
      end
    end

    def default_transaction_xml(xml)
      xml.tag!('dados-pedido') do
        [:numero, :valor, :moeda, :"data-hora", :idioma, :"soft-descriptor"].each do |key|
          xml.tag!(key.to_s, parameters[key].to_s)
        end
      end
      xml.tag!('forma-pagamento') do
        [:bandeira, :produto, :parcelas].each do |key|
          xml.tag!(key.to_s, parameters[key].to_s)
        end
      end
      xml.tag!('url-retorno', parameters[:"url-retorno"])
      xml.autorizar parameters[:autorizar].to_s
      xml.capturar parameters[:capturar].to_s
      xml.tag!('gerar-token', parameters[:"gerar-token"])
    end

    def analysis_parameters
      return if parameters.empty?
      to_analyze = [:numero, :valor, :bandeira, :"url-retorno"]

      if buy_page == :store
        if parameters[:token].present?
          to_analyze.concat([:token])
        else
          to_analyze.concat([:cartao_numero, :cartao_validade, :cartao_portador])
          to_analyze.concat([:cartao_seguranca]) unless ['1.0.0', '1.1.0', '1.1.1'].include?(@versao)
        end
      end

      to_analyze.each do |parameter|
        fail Cielo::MissingArgumentError, "Required parameter #{parameter} not found" unless parameters[parameter]
      end

      parameters[:moeda] = '986' unless parameters[:moeda]
      parameters[:"data-hora"] = Time.now.strftime('%Y-%m-%dT%H:%M:%S') unless parameters[:"data-hora"]
      parameters[:idioma] = 'PT' unless parameters[:idioma]
      parameters[:produto] = '1' unless parameters[:produto]
      parameters[:parcelas] = '1' unless parameters[:parcelas]
      parameters[:autorizar] = '2' unless parameters[:autorizar]
      parameters[:capturar] = 'true' unless parameters[:capturar]
      parameters[:"url-retorno"] = Cielo.return_path unless parameters[:"url-retorno"]
      parameters[:cartao_indicador] = '1' unless parameters[:cartao_indicador] && buy_page == :buy_page_store
      parameters[:"gerar-token"] = false unless parameters[:"gerar-token"]

      parameters
    end
  end
end
