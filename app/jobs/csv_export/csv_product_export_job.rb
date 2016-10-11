module CSVExport
  class CSVProductExportJob < Struct.new(:user, :products) # pass in the datafile like is done right now in uploadcontroller, i.e.

    def enqueue(job)
    end

    def success(job)
    end

    def error(job, exception)
      puts exception
    end

    def failure(job)
    end

    def perform
      csv = CSV.generate do |f|
        f << ["Supplier", "Market", "Name", "Pricing", "Available", "Code"]

        products.decorate.each do |product|
          f << [
              product.organization_name,
              product.market_name,
              product.name_and_unit,
              product.prices.view_sorted.decorate.map(&:quick_info).join(", "),
              product.available_inventory,
              product.code
          ]
        end
      end

      # Send via email
      puts "Before Send"
      ExportMailer.export_success(user.email, csv)
      puts "After Send"
    end

  end
end