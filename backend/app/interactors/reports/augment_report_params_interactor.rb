# frozen_string_literal: true

module Reports
  # Добавляет к params фильтры из «плоских» query-параметров (как в отчётах по ссылке).
  class AugmentReportParamsInteractor < BaseInteractor
    SYSTEM_PARAMS = %i[
      report_type report_format limit offset sorts format controller action filters
    ].freeze

    def call(params:)
      report_params = if params.respond_to?(:to_unsafe_h)
                        params.to_unsafe_h.deep_dup
                      else
                        params.deep_dup
                      end
      report_params = report_params.symbolize_keys
      extracted = extract_filters(report_params)
      report_params[:filters] = (report_params[:filters] || []) + extracted
      success(report_params)
    end

    private

    def extract_filters(params)
      params.each_with_object([]) do |(key, value), acc|
        key_sym = key.to_sym
        next if SYSTEM_PARAMS.include?(key_sym)
        next if key.to_s.end_with?('_operator')
        next if value.blank?

        operator = params[:"#{key}_operator"] || params["#{key}_operator"] || (value.is_a?(Array) ? 'in' : 'eq')

        acc << {
          field: key.to_s,
          operator: operator,
          value: value.is_a?(Array) ? value.join(',') : value.to_s
        }
      end
    end
  end
end
