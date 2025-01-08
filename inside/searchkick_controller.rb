# frozen_string_literal: true

module Inside
  class SearchkickController < BaseController
    class BadRequestException < StandardError
    end

    rescue_from BadRequestException, with: :render_bad_request_error

    def render_bad_request_error(exception)
      render(
        json: {success: false, error_message: exception.message},
        status: 500
      )
    end

    # /inside/searchkick/reindex/model
    def reindex_model
      model_name = params[:model]

      begin
        model = model_name.constantize
      rescue NameError
        raise BadRequestException, "Invalid model name: #{model_name}"
      end

      begin
        Searchkick::FullReindexJob.perform_async(model.name)
      rescue Searchkick::FullReindexJob::InvalidSearchkickModelName
        raise BadRequestException, "Invalid model name: #{model_name}"
      end
      render(json: {success: true, error_message: nil})
    end

    # /inside/searchkick/records/cloudquery/reindex
    def reindex_cloudquery_records
      records = params[:records]

      if !records.is_a?(Array)
        raise BadRequestException, 'Expected "records" to be an array'
      end

      records.each do |record|
        model_name = record[:model]
        cq_id = record[:cq_id]

        if model_name.nil?
          raise BadRequestException, "Received a record that is missing a 'model' field"
        end

        if cq_id.nil?
          raise BadRequestException, "Received a record that is missing a 'cq_id' field"
        end

        begin
          model = model_name.constantize
        rescue NameError
          raise BadRequestException, "Invalid model name: #{model_name}"
        end

        if model.superclass != Cloudquery::Base
          raise BadRequestException, "Invalid model name: #{model_name} is not a Cloudquery model"
        end
      end

      records.each do |record|
        model_name = record[:model]
        cq_id = record[:cq_id]

        model_name.constantize.search_index.reindex_queue.push(cq_id)
      end

      render(json: {success: true, error_message: nil})
    end
  end
end
