module Cielo
  class Token
    attr_accessor :response

    def initialize(id = nil, masked_card = "", status = "")
      @id             = id
      @masked_card    = masked_card
      @status         = status
    end
    attr_reader :id, :masked_card, :status

    def self.create(parameters = {}, _buy_page = :cielo, connection = Connection.new)
      message = connection.xml_builder('requisicao-token') do |xml, target|
        if target == :after
          xml.tag!('dados-portador') do
            xml.tag!('numero', parameters[:cartao_numero])
            xml.tag!('validade', parameters[:cartao_validade])
            xml.tag!('nome-portador', parameters[:cartao_portador])
          end
        end
      end

      response = connection.make_request!(message)
      if response.has_key?("error")
        Erro.new(response)
      else
        args = response[:"retorno-token"][:token][:"dados-token"]
        new(args[:"codigo-token"], args[:"numero-cartao-truncado"], args[:status])
      end
    end
  end
end
