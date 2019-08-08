# frozen_string_literal: true

module DeletePrefixSuffix
  refine String do
    def delete_prefix!(str)
      slice!(str.length..-1) if start_with?(str)
      self
    end

    def delete_suffix!(str)
      slice!(0..(-str.length - 1)) if end_with?(str)
      self
    end

    def delete_prefix(str)
      dup.delete_prefix!(str)
    end

    def delete_suffix(str)
      dup.delete_suffix!(str)
    end
  end
end
