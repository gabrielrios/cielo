module Cielo
  class Connection
    attr_reader :environment
    attr_reader :numero_afiliacao
    attr_reader :chave_acesso
    attr_reader :versao
    attr_accessor :path

    def initialize(numero_afiliacao = Cielo.numero_afiliacao,
                   chave_acesso = Cielo.chave_acesso,
                   versao = '1.2.1')
      @environment = eval(Cielo.environment.to_s.capitalize)
      @numero_afiliacao = numero_afiliacao
      @chave_acesso = chave_acesso
      @path = @environment::WS_PATH
      @versao = versao
      port = 443
      @http = Net::HTTP.new(@environment::BASE_URL, port)
      @http.ssl_version = :TLSv1 if @http.respond_to? :ssl_version
      @http.use_ssl = true
      @http.open_timeout = 10 * 1000
      @http.read_timeout = 40 * 1000
    end

    def request!(params = {})
      str_params = params.map { |key, value| "#{key}=#{value}" }.join('&')
      @http.request_post(path, str_params)
    end

    def xml_builder(group_name,
                    params = { id: Time.now.to_i.to_s, versao: @versao },
                    &block)
      xml = Builder::XmlMarkup.new(:indent=>2)
      xml.instruct! :xml, version: '1.0', encoding: 'UTF-8'
      xml.tag!(group_name, { xmlns: "http://ecommerce.cbmp.com.br"}.merge(params)) do
        yield xml, :before
        xml.tag!('dados-ec') do
          xml.numero @numero_afiliacao # Cielo.numero_afiliacao
          xml.chave @chave_acesso # Cielo.chave_acesso
        end
        yield xml, :after
      end
      xml
    end

    def make_request!(message)
      params = { mensagem: message.target! }
      result = request! params
      parse_response(result)
    end

    def parse_response(response)
      case response
      when Net::HTTPSuccess
        hash = Hash.from_xml(response.body)
        ActiveSupport::HashWithIndifferentAccess.new(hash)
      else
        { erro: { codigo: '000', mensagem: "Impossível contactar o servidor" } }
      end
    end
  end
end
