module Inside
  class VendorsController < BaseController
    # POST /inside/vendors/merge
    def merge_vendors
      if invalid_vendor_id?(params.dig(:base_vendor_id))
        render(json: {message: "Requires only 1 base vendor id, got: #{params.dig(:base_vendor_id)}"}, status: 400) && return
      end

      base_vendor = Vendor.where(id: params.dig(:base_vendor_id)).first
      merging_vendors = Vendor.where(id: params.dig(:merging_vendor_ids))

      if base_vendor.nil?
        render(json: {message: "Could not find base vendor id: #{params.dig(:base_vendor_id)}"}, status: 400)
      elsif merging_vendors.empty?
        render(json: {message: "Could not find vendor ids: #{params.dig(:merging_vendor_ids)}"}, status: 400)
      else
        merging_vendors.each do |mv|
          base_vendor.merge!(mv)
        end

        Rails.logger.info(
          "Vendor #{base_vendor.name} - #{base_vendor.id} \
          merged with #{merging_vendors.pluck(:name)}"
        )
        render(json: {message: "#{base_vendor.name} - #{base_vendor.id} merged with #{merging_vendors.pluck(:name)}"}, status: 200)
      end
    end

    # PATCH /inside/vendors/update
    def update_vendor
      vendor_id = params.dig(:id)
      if invalid_vendor_id?(vendor_id)
        render(json: {message: "Invalid vendor id, got: #{vendor_id}"}, status: 400) && return
      end

      if (vendor = Vendor.find_by_id(vendor_id))
        begin
          vendor.update!(params.except(:id).permit(Vendor.column_names, {categories: []}))
          render(json: {message: "#{vendor.name} - #{vendor.id} updated"}, status: 200)
        rescue ActiveModel::ForbiddenAttributesError, ActiveRecord::RecordInvalid => e
          render(json: {message: e.message}, status: 400)
        end
      else
        render(json: {message: "Could not find vendor id: #{vendor_id}"}, status: 400) && return
      end
    end

    # POST /inside/vendors/create
    def create_vendor
      vendor = Vendor.create!(params.permit(Vendor.column_names, {categories: []}))
      render(json: {message: "#{vendor.name} - #{vendor.id} created"}, status: 200)
    rescue ActiveRecord::RecordInvalid, ActiveModel::ForbiddenAttributesError => e
      render(json: {message: e.message}, status: 400)
    end

    private def invalid_vendor_id?(vendor_id)
      vendor_id.nil? || [vendor_id].flatten.count != 1
    end
  end
end
