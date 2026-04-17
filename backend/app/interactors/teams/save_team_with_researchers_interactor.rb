# frozen_string_literal: true

module Teams
  # Создание/обновление команды с участниками после валидации контрактом.
  class SaveTeamWithResearchersInteractor < BaseInteractor
    def call(team:, validated_params:)
      params = validated_params.respond_to?(:to_h) ? validated_params.to_h.deep_dup : validated_params.deep_dup
      params = params.symbolize_keys
      researcher_ids = params.delete(:researcher_ids) || params.delete('researcher_ids')

      if team.persisted?
        return failure(:database_error, team.errors.full_messages) unless team.update(params)
      else
        team.assign_attributes(params)
        return failure(:database_error, team.errors.full_messages) unless team.save
      end

      team.researcher_ids = researcher_ids if researcher_ids
      success(team.reload)
    end
  end
end
