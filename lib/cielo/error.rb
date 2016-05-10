module Cielo
  class Error < StandardError
    def initialize(response)
      code = response[:codigo]
      message = response[:mensagem]
      super "#{code} #{message}"
    end
  end
end
